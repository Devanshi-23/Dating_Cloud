import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_controls.dart';
import '../../../../dev/mock/mock_auth_defaults.dart';
import '../../domain/phone_number.dart';
import '../viewmodels/sign_in_view_model.dart';

class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  late final MockAuthDefaults? _defaults = ref.read(mockAuthDefaultsProvider);
  late final _phone = TextEditingController(text: _defaults?.nationalNumber);
  late final _code = TextEditingController(text: _defaults?.otpCode);
  late String _dialCode =
      _defaults?.dialCode ?? PhoneNumberRules.dialCodes.first.code;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInViewModelProvider);
    final viewModel = ref.read(signInViewModelProvider.notifier);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isOtp = state.step == SignInStep.otp;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg - 4,
            AppSpacing.sm,
            AppSpacing.lg - 4,
            AppSpacing.lg,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: RoundIconButton(
                key: const Key('signIn.back'),
                icon: Icons.chevron_left_rounded,
                tooltip: isOtp ? 'Use a different number' : 'Back',
                onPressed: state.isSubmitting
                    ? null
                    : isOtp
                    ? viewModel.changePhoneNumber
                    : () => context.canPop()
                          ? context.pop()
                          : context.go(RoutePaths.welcome),
              ),
            ),
            const SizedBox(height: AppSpacing.lg - 4),
            Text(
              isOtp ? 'Enter your code' : 'Can we get your number?',
              style: theme.textTheme.headlineLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isOtp) ...[
              Text(
                'We sent a 6-digit code to ${state.phoneNumber}.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xl),
              _CodeInput(
                controller: _code,
                enabled: !state.isSubmitting,
                onSubmitted: () => viewModel.verifyOtp(_code.text.trim()),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Didn’t get anything? No worries, let’s try again.',
                style: muted,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _ResendButton(
                  key: ValueKey(state.codesSent),
                  wait: state.resendAfter,
                  enabled: !state.isSubmitting,
                  onResend: viewModel.resendOtp,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 112,
                    child: DropdownButtonFormField<String>(
                      key: const Key('signIn.dialCode'),
                      initialValue: _dialCode,
                      isExpanded: true,
                      style: theme.textTheme.titleMedium,
                      decoration: const InputDecoration(),
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      items: [
                        for (final d in PhoneNumberRules.dialCodes)
                          DropdownMenuItem(
                            value: d.code,
                            child: Text('${d.countryCode} ${d.code}'),
                          ),
                      ],
                      onChanged: state.isSubmitting
                          ? null
                          : (value) => setState(() => _dialCode = value!),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md - 4),
                  Expanded(
                    child: TextField(
                      key: const Key('signIn.phone'),
                      controller: _phone,
                      enabled: !state.isSubmitting,
                      keyboardType: TextInputType.phone,
                      style: theme.textTheme.titleMedium,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Mobile number',
                      ),
                      onSubmitted: (_) => _sendCode(viewModel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'We’ll text you a code to sign in or create your account. '
                'Message and data rates may apply. We never show your number '
                'on your profile.',
                style: muted,
              ),
            ],
            if (state.failure != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                state.failure!.message,
                key: const Key('signIn.error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const Key('signIn.submit'),
              onPressed: state.isSubmitting
                  ? null
                  : () => isOtp
                        ? viewModel.verifyOtp(_code.text.trim())
                        : _sendCode(viewModel),
              child: state.isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Next'),
            ),
            if (_defaults != null) ...[
              const SizedBox(height: AppSpacing.lg),
              // DecoratedBox(
              //   key: const Key('signIn.mockHint'),
              //   decoration: BoxDecoration(
              //     color: theme.colorScheme.surfaceContainerHighest,
              //     borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              //   ),
              //   child: Padding(
              //     padding: const EdgeInsets.all(AppSpacing.md),
              //     child: Text(
              //       'Mock mode — fields are pre-filled. '
              //       '${_defaults.dialCode} ${_defaults.nationalNumber} opens '
              //       'the demo account; any other number creates a new account '
              //       'and goes through onboarding. Code ${_defaults.otpCode} '
              //       'signs in, 000000 is expired.',
              //       style: theme.textTheme.bodySmall?.copyWith(
              //         color: theme.colorScheme.onSurfaceVariant,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ],
        ),
      ),
    );
  }

  void _sendCode(SignInViewModel viewModel) =>
      viewModel.requestOtp(dialCode: _dialCode, nationalNumber: _phone.text);
}

/// Six underlined digit slots backed by one invisible text field, so paste,
/// SMS autofill and screen readers behave like a normal input.
class _CodeInput extends StatefulWidget {
  const _CodeInput({
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  static const length = 6;

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  State<_CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<_CodeInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([widget.controller, _focus]),
          builder: (context, _) {
            final code = widget.controller.text;
            final active = code.length.clamp(0, _CodeInput.length - 1);
            return Row(
              children: [
                for (var i = 0; i < _CodeInput.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _focus.hasFocus && i == active
                              ? AppColors.primary
                              : i < code.length
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.outline,
                          width: _focus.hasFocus && i == active ? 2 : 1.5,
                        ),
                      ),
                      child: Text(
                        i < code.length ? code[i] : '',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        Positioned.fill(
          child: TextField(
            key: const Key('signIn.code'),
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_CodeInput.length),
            ],
            showCursor: false,
            enableInteractiveSelection: false,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(color: Colors.transparent),
            // Every border state must be cleared: the app theme draws a
            // focused underline that would otherwise cut through the boxes.
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              counterText: '',
              semanticCounterText: '6-digit code',
            ),
            onSubmitted: (_) => widget.onSubmitted(),
          ),
        ),
      ],
    );
  }
}

class _ResendButton extends StatefulWidget {
  const _ResendButton({
    super.key,
    required this.wait,
    required this.enabled,
    required this.onResend,
  });

  final Duration wait;
  final bool enabled;
  final VoidCallback onResend;

  @override
  State<_ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<_ResendButton> {
  late int _secondsLeft = widget.wait.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_secondsLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft > 0;
    return TextButton(
      key: const Key('signIn.resend'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: waiting || !widget.enabled ? null : widget.onResend,
      child: Text(waiting ? 'Resend code in ${_secondsLeft}s' : 'Resend code'),
    );
  }
}
