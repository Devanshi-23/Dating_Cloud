import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/pagination.dart';
import '../../../chat/presentation/viewmodels/conversations_view_model.dart';
import '../../../matches/domain/entities/match.dart';
import '../../../matches/presentation/viewmodels/matches_view_model.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../../swipes/domain/entities/swipe.dart';
import '../../domain/entities/discovery_filter.dart';

const _keep = Object();

class DiscoveryFilterController extends Notifier<DiscoveryFilter> {
  @override
  DiscoveryFilter build() => const DiscoveryFilter();

  void apply(DiscoveryFilter filter) => state = filter;
}

final discoveryFilterProvider =
    NotifierProvider<DiscoveryFilterController, DiscoveryFilter>(
      DiscoveryFilterController.new,
    );

class DiscoveryState {
  const DiscoveryState({
    required this.candidates,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreFailure,
    this.pendingSwipes = 0,
    this.isUndoing = false,
    this.newMatch,
    this.actionFailure,
    this.failedSwipe,
  });

  /// The deck, top card first. A swiped card leaves immediately; its request
  /// continues in the background.
  final List<UserProfile> candidates;
  final String? nextCursor;
  final bool isLoadingMore;
  final Failure? loadMoreFailure;

  /// Swipe requests still waiting for the server.
  final int pendingSwipes;
  final bool isUndoing;

  /// Set when a swipe created a mutual match; cleared by the UI.
  final Match? newMatch;
  final Failure? actionFailure;

  /// The profile put back on top because its swipe could not be saved.
  final UserProfile? failedSwipe;

  UserProfile? get current => candidates.isEmpty ? null : candidates.first;

  bool get canUndo => pendingSwipes == 0 && !isUndoing;

  /// No cards left and nothing more to fetch.
  bool get isExhausted =>
      candidates.isEmpty && nextCursor == null && !isLoadingMore;

  DiscoveryState copyWith({
    List<UserProfile>? candidates,
    Object? nextCursor = _keep,
    bool? isLoadingMore,
    Object? loadMoreFailure = _keep,
    int? pendingSwipes,
    bool? isUndoing,
    Object? newMatch = _keep,
    Object? actionFailure = _keep,
    Object? failedSwipe = _keep,
  }) => DiscoveryState(
    candidates: candidates ?? this.candidates,
    nextCursor: nextCursor == _keep ? this.nextCursor : nextCursor as String?,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure == _keep
        ? this.loadMoreFailure
        : loadMoreFailure as Failure?,
    pendingSwipes: pendingSwipes ?? this.pendingSwipes,
    isUndoing: isUndoing ?? this.isUndoing,
    newMatch: newMatch == _keep ? this.newMatch : newMatch as Match?,
    actionFailure: actionFailure == _keep
        ? this.actionFailure
        : actionFailure as Failure?,
    failedSwipe: failedSwipe == _keep
        ? this.failedSwipe
        : failedSwipe as UserProfile?,
  );
}

class DiscoveryViewModel extends AsyncNotifier<DiscoveryState> {
  static const _pageSize = 10;
  static const _prefetchThreshold = 3;
  static const _uuid = Uuid();

  DiscoveryFilter _filter = const DiscoveryFilter();

  /// Profiles whose swipe request is in flight; blocks duplicate requests.
  final _inFlight = <String>{};

  /// Every profile shown this session, so later pages never repeat a card.
  final _seen = <String>{};

  /// Idempotency key per profile + action, kept until the server confirms so
  /// a retry after a network failure cannot record the swipe twice.
  final _idempotencyKeys = <String, String>{};

  @override
  Future<DiscoveryState> build() async {
    _inFlight.clear();
    _seen.clear();
    _filter = ref.watch(discoveryFilterProvider);
    final page = await ref
        .watch(discoveryRepositoryProvider)
        .getCandidates(
          filter: _filter,
          page: const PageRequest(limit: _pageSize),
        );
    _seen.addAll(page.items.map((p) => p.id));
    return DiscoveryState(candidates: page.items, nextCursor: page.nextCursor);
  }

  /// Swipes the top card. Returns `false` (and does nothing) if there is no
  /// card, [profileId] is no longer on top, or it is already being sent.
  bool swipe(SwipeAction action, {String? profileId}) {
    final current = state.value;
    final target = current?.current;
    if (current == null || target == null) return false;
    if (profileId != null && profileId != target.id) return false;
    if (!_inFlight.add(target.id)) return false;

    state = AsyncData(
      current.copyWith(
        candidates: current.candidates.sublist(1),
        pendingSwipes: current.pendingSwipes + 1,
        actionFailure: null,
        failedSwipe: null,
      ),
    );
    unawaited(_send(target, action));
    _loadMoreIfNeeded();
    return true;
  }

  Future<void> _send(UserProfile target, SwipeAction action) async {
    final keyId = '${target.id}:${action.wire}';
    final key = _idempotencyKeys.putIfAbsent(keyId, _uuid.v4);
    try {
      final result = await ref
          .read(swipeRepositoryProvider)
          .swipe(targetUserId: target.id, action: action, idempotencyKey: key);
      if (!ref.mounted) return;
      _idempotencyKeys.remove(keyId);
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          pendingSwipes: latest.pendingSwipes - 1,
          newMatch: result.match ?? latest.newMatch,
        ),
      );
      if (result.isMatch) {
        ref
          ..invalidate(matchesViewModelProvider)
          ..invalidate(conversationsViewModelProvider);
      }
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      final latest = state.requireValue;
      if (failure.code == ErrorCode.conflict) {
        // The server already has a response to this profile; keep it gone.
        _idempotencyKeys.remove(keyId);
        state = AsyncData(
          latest.copyWith(pendingSwipes: latest.pendingSwipes - 1),
        );
        return;
      }
      state = AsyncData(
        latest.copyWith(
          candidates: [
            target,
            ...latest.candidates.where((p) => p.id != target.id),
          ],
          pendingSwipes: latest.pendingSwipes - 1,
          actionFailure: failure,
          failedSwipe: target,
        ),
      );
    } finally {
      _inFlight.remove(target.id);
    }
  }

  Future<void> undo() async {
    final current = state.value;
    if (current == null || !current.canUndo) return;
    state = AsyncData(current.copyWith(isUndoing: true, actionFailure: null));
    try {
      final result = await ref.read(swipeRepositoryProvider).undoLastSwipe();
      if (!ref.mounted) return;
      final restored = result.restoredProfile;
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          candidates: [
            restored,
            ...latest.candidates.where((p) => p.id != restored.id),
          ],
          isUndoing: false,
        ),
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData(
        state.requireValue.copyWith(isUndoing: false, actionFailure: failure),
      );
    }
  }

  void clearTransientState() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(newMatch: null, actionFailure: null, failedSwipe: null),
    );
  }

  /// Retries pagination after it failed with an empty deck.
  Future<void> retryLoadMore() => _loadMore();

  void _loadMoreIfNeeded() {
    final current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore ||
        current.candidates.length > _prefetchThreshold) {
      return;
    }
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    final current = state.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailure: null),
    );
    try {
      final page = await ref
          .read(discoveryRepositoryProvider)
          .getCandidates(
            filter: _filter,
            page: PageRequest(cursor: current.nextCursor, limit: _pageSize),
          );
      if (!ref.mounted) return;
      final fresh = page.items.where((p) => _seen.add(p.id)).toList();
      final latest = state.requireValue;
      state = AsyncData(
        latest.copyWith(
          candidates: [...latest.candidates, ...fresh],
          nextCursor: page.nextCursor,
          isLoadingMore: false,
        ),
      );
      _loadMoreIfNeeded();
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = AsyncData(
        state.requireValue.copyWith(
          isLoadingMore: false,
          loadMoreFailure: failure,
        ),
      );
    }
  }

  void applyFilter(DiscoveryFilter filter) {
    _filter = filter;
    ref.invalidateSelf();
  }
}

final discoveryViewModelProvider =
    AsyncNotifierProvider.autoDispose<DiscoveryViewModel, DiscoveryState>(
      DiscoveryViewModel.new,
    );
