import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../swipes/domain/entities/swipe.dart';
import 'profile_card.dart';

/// Lets buttons outside the deck trigger the same fly-out animation as a
/// gesture.
class SwipeDeckController {
  _SwipeDeckState? _state;

  /// Returns `false` if there is no card to swipe.
  bool swipe(SwipeAction action) => _state?._swipeTop(action) ?? false;
}

/// Swipe right to like, left to pass. A swiped card flies off in an overlay
/// while the next card becomes interactive straight away, so rapid swipes
/// never wait for an animation or a network request.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.profiles,
    required this.onSwipe,
    required this.controller,
    this.cardBuilder,
  });

  /// Top card first.
  final List<UserProfile> profiles;

  /// Builds each card's face. Defaults to [ProfileCard].
  final Widget Function(UserProfile profile)? cardBuilder;

  /// Called once per committed swipe. Return `false` to reject it (the card
  /// springs back).
  final bool Function(UserProfile profile, SwipeAction action) onSwipe;
  final SwipeDeckController controller;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with TickerProviderStateMixin {
  static const _visibleCards = 3;
  static const _prefetchCount = 5;
  static const _commitFraction = 0.28;
  static const _commitVelocity = 900.0;
  static const _maxRotation = 0.30;
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 26,
  );

  final _drag = ValueNotifier<Offset>(Offset.zero);
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  );
  Offset _settleFrom = Offset.zero;
  bool _grabbedBelowCenter = false;
  Size _size = Size.zero;

  final _outgoing = <_Outgoing>[];
  final _prefetched = <String>{};

  List<UserProfile> get _visible {
    final leaving = {for (final o in _outgoing) o.profile.id};
    return widget.profiles.where((p) => !leaving.contains(p.id)).toList();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Widget _cardFor(UserProfile profile) =>
      widget.cardBuilder?.call(profile) ?? ProfileCard(profile: profile);

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    _settle.addListener(() {
      _drag.value = Offset.lerp(_settleFrom, Offset.zero, _settle.value)!;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetch();
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    final oldTop = oldWidget.profiles.isEmpty ? null : oldWidget.profiles.first;
    final newTop = widget.profiles.isEmpty ? null : widget.profiles.first;
    if (oldTop?.id != newTop?.id) _resetDrag();
    _prefetch();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _settle.dispose();
    _drag.dispose();
    for (final o in _outgoing) {
      o.dispose();
    }
    super.dispose();
  }

  void _prefetch() {
    for (final profile in widget.profiles.take(_prefetchCount)) {
      if (_prefetched.add(profile.id)) {
        prefetchProfilePhoto(context, profile.primaryPhotoUrl);
      }
    }
  }

  void _resetDrag() {
    _settle.stop();
    _drag.value = Offset.zero;
  }

  // ── Gestures ──

  void _onPanStart(DragStartDetails details) {
    _settle.stop();
    _grabbedBelowCenter = details.localPosition.dy > _size.height / 2;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _drag.value += details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    final top = _visible.firstOrNull;
    if (top == null) return;
    final offset = _drag.value;
    final velocity = details.velocity.pixelsPerSecond;
    final threshold = _size.width * _commitFraction;
    final double direction;
    if (offset.dx.abs() >= threshold) {
      direction = offset.dx.sign;
    } else if (velocity.dx.abs() >= _commitVelocity &&
        velocity.dx.sign == offset.dx.sign) {
      direction = velocity.dx.sign;
    } else {
      _springBack(velocity);
      return;
    }
    final action = direction > 0 ? SwipeAction.like : SwipeAction.pass;
    if (!_commit(top, action, from: offset, velocity: velocity)) {
      _springBack(velocity);
    }
  }

  void _springBack(Offset velocity) {
    _settleFrom = _drag.value;
    final distance = _settleFrom.distance;
    if (distance == 0) return;
    if (_reduceMotion) {
      _drag.value = Offset.zero;
      return;
    }
    // Velocity towards the centre, normalised to the 0→1 settle progress.
    final towardCentre =
        -(velocity.dx * _settleFrom.dx + velocity.dy * _settleFrom.dy) /
        (distance * distance);
    _settle.animateWith(SpringSimulation(_spring, 0, 1, towardCentre));
  }

  // ── Swipes ──

  bool _swipeTop(SwipeAction action) {
    final top = _visible.firstOrNull;
    if (top == null) return false;
    return _commit(top, action, from: _drag.value, velocity: Offset.zero);
  }

  bool _commit(
    UserProfile profile,
    SwipeAction action, {
    required Offset from,
    required Offset velocity,
  }) {
    if (!widget.onSwipe(profile, action)) return false;
    HapticFeedback.lightImpact();

    final width = _size.width;
    final reduceMotion = _reduceMotion;
    final Offset to;
    if (action == SwipeAction.superLike) {
      to = Offset(from.dx, -_size.height * 1.4);
    } else {
      final direction = action == SwipeAction.like ? 1.0 : -1.0;
      final drift = (velocity.dy * 0.15).clamp(-200.0, 200.0);
      to = Offset(direction * width * 1.6, from.dy + drift);
    }
    final speed = math.max(velocity.distance, 1600);
    final millis = reduceMotion
        ? 160
        : ((to - from).distance / speed * 1000).clamp(200, 360).round();
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: millis),
    );
    final outgoing = _Outgoing(
      profile: profile,
      action: action,
      controller: controller,
      from: from,
      to: reduceMotion ? from : to,
      grabbedBelowCenter: _grabbedBelowCenter,
    );
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _outgoing.remove(outgoing));
        outgoing.dispose();
      }
    });
    setState(() => _outgoing.add(outgoing));
    _resetDrag();
    controller.forward();
    return true;
  }

  // ── Layout ──

  double _rotationFor(Offset offset, {required bool grabbedBelowCenter}) {
    if (_reduceMotion || _size.width == 0) return 0;
    final turn = (offset.dx / _size.width * _maxRotation * 1.6).clamp(
      -_maxRotation,
      _maxRotation,
    );
    return grabbedBelowCenter ? -turn : turn;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final visible = _visible.take(_visibleCards).toList();
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (var depth = visible.length - 1; depth >= 1; depth--)
            _BackCard(
              key: ValueKey('back-${visible[depth].id}'),
              card: _cardFor(visible[depth]),
              depth: depth,
              drag: _drag,
              commitDistance: _size.width * _commitFraction,
            ),
          if (visible.isNotEmpty) _buildTopCard(visible.first),
          for (final o in _outgoing)
            _FlyingCard(
              key: ValueKey('out-${o.profile.id}'),
              outgoing: o,
              card: _cardFor(o.profile),
              rotationFor: _rotationFor,
              fade: _reduceMotion,
            ),
        ],
      );
    },
  );

  Widget _buildTopCard(UserProfile profile) {
    final card = RepaintBoundary(child: _cardFor(profile));
    final threshold = _size.width * _commitFraction;
    return Semantics(
      key: ValueKey('top-${profile.id}'),
      container: true,
      label: '${profile.displayName}. Swipe right to like, left to pass.',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Like'): () =>
            _swipeTop(SwipeAction.like),
        const CustomSemanticsAction(label: 'Pass'): () =>
            _swipeTop(SwipeAction.pass),
      },
      child: GestureDetector(
        key: const Key('discover.topCard'),
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: () => _springBack(Offset.zero),
        child: ValueListenableBuilder<Offset>(
          valueListenable: _drag,
          child: card,
          builder: (context, offset, child) {
            final progress = threshold == 0 ? 0.0 : offset.dx / threshold;
            return Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: _rotationFor(
                  offset,
                  grabbedBelowCenter: _grabbedBelowCenter,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    child!,
                    _Stamp(
                      label: 'LIKE',
                      color: AppColors.like,
                      opacity: progress.clamp(0.0, 1.0),
                      alignment: Alignment.topLeft,
                      angle: -0.25,
                    ),
                    _Stamp(
                      label: 'PASS',
                      color: AppColors.pass,
                      opacity: (-progress).clamp(0.0, 1.0),
                      alignment: Alignment.topRight,
                      angle: 0.25,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Outgoing {
  _Outgoing({
    required this.profile,
    required this.action,
    required this.controller,
    required this.from,
    required this.to,
    required this.grabbedBelowCenter,
  });

  final UserProfile profile;
  final SwipeAction action;
  final AnimationController controller;
  late final curve = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  final Offset from;
  final Offset to;
  final bool grabbedBelowCenter;

  void dispose() {
    curve.dispose();
    controller.dispose();
  }
}

class _BackCard extends StatelessWidget {
  const _BackCard({
    super.key,
    required this.card,
    required this.depth,
    required this.drag,
    required this.commitDistance,
  });

  static const _scaleStep = 0.05;
  static const _offsetStep = 14.0;

  final Widget card;
  final int depth;
  final ValueListenable<Offset> drag;
  final double commitDistance;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ValueListenableBuilder<Offset>(
        valueListenable: drag,
        child: RepaintBoundary(child: card),
        builder: (context, offset, child) {
          final progress = commitDistance == 0
              ? 0.0
              : (offset.distance / commitDistance).clamp(0.0, 1.0);
          final level = depth - progress;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translateByDouble(0, level * _offsetStep, 0, 1)
              ..scaleByDouble(
                1 - level * _scaleStep,
                1 - level * _scaleStep,
                1,
                1,
              ),
            child: child,
          );
        },
      ),
    ),
  );
}

class _FlyingCard extends StatelessWidget {
  const _FlyingCard({
    super.key,
    required this.outgoing,
    required this.card,
    required this.rotationFor,
    required this.fade,
  });

  final _Outgoing outgoing;
  final Widget card;
  final double Function(Offset, {required bool grabbedBelowCenter}) rotationFor;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final curve = outgoing.curve;
    final isLike = outgoing.action.isPositive;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: curve,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                card,
                _Stamp(
                  label: switch (outgoing.action) {
                    SwipeAction.like => 'LIKE',
                    SwipeAction.pass => 'PASS',
                    SwipeAction.superLike => 'SUPER',
                  },
                  color: switch (outgoing.action) {
                    SwipeAction.like => AppColors.like,
                    SwipeAction.pass => AppColors.pass,
                    SwipeAction.superLike => AppColors.superLike,
                  },
                  opacity: 1,
                  alignment: isLike ? Alignment.topLeft : Alignment.topRight,
                  angle: isLike ? -0.25 : 0.25,
                ),
              ],
            ),
          ),
          builder: (context, child) {
            final offset = Offset.lerp(
              outgoing.from,
              outgoing.to,
              curve.value,
            )!;
            return Opacity(
              opacity: fade ? 1 - curve.value : 1,
              child: Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: rotationFor(
                    offset,
                    grabbedBelowCenter: outgoing.grabbedBelowCenter,
                  ),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.opacity,
    required this.alignment,
    required this.angle,
  });

  final String label;
  final Color color;
  final double opacity;
  final Alignment alignment;
  final double angle;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.85),
                border: Border.all(color: color, width: 4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
