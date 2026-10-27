import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/phone_number.dart';
import 'session_view_model.dart';

enum SignInStep { phone, otp }

class SignInState {
  const SignInState({
    this.step = SignInStep.phone,
    this.phoneNumber = '',
    this.isSubmitting = false,
    this.failure,
    this.resendAfter = Duration.zero,
    this.codesSent = 0,
  });

  final SignInStep step;

  /// E.164, e.g. `+919876543210`.
  final String phoneNumber;
  final bool isSubmitting;
  final Failure? failure;

  /// How long after the latest code was sent before another may be requested.
  final Duration resendAfter;

  /// Increments on every successful send so the view can restart its timer.
  final int codesSent;

  SignInState copyWith({
    SignInStep? step,
    bool? isSubmitting,
    Failure? failure,
    Duration? resendAfter,
    int? codesSent,
  }) => SignInState(
    step: step ?? this.step,
    phoneNumber: phoneNumber,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: failure,
    resendAfter: resendAfter ?? this.resendAfter,
    codesSent: codesSent ?? this.codesSent,
  );
}

class SignInViewModel extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<void> requestOtp({
    required String dialCode,
    required String nationalNumber,
  }) async {
    final phone = PhoneNumberRules.combine(dialCode, nationalNumber);
    if (!PhoneNumberRules.isValid(phone)) {
      state = SignInState(
        phoneNumber: phone,
        failure: const Failure(
          ErrorCode.validationError,
          message: 'Enter a valid mobile number.',
          details: [FieldError(field: 'phoneNumber', reason: 'INVALID_FORMAT')],
        ),
      );
      return;
    }
    state = SignInState(phoneNumber: phone, isSubmitting: true);
    await _send(failureStep: SignInStep.phone);
  }

  Future<void> resendOtp() async {
    if (state.isSubmitting || state.phoneNumber.isEmpty) return;
    state = state.copyWith(isSubmitting: true);
    await _send(failureStep: SignInStep.otp);
  }

  Future<void> _send({required SignInStep failureStep}) async {
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(state.phoneNumber);
      if (!ref.mounted) return;
      state = state.copyWith(
        step: SignInStep.otp,
        isSubmitting: false,
        resendAfter: challenge.resendAfter,
        codesSent: state.codesSent + 1,
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(
        step: failureStep,
        isSubmitting: false,
        failure: failure,
      );
    }
  }

  Future<void> verifyOtp(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      state = state.copyWith(
        failure: const Failure(
          ErrorCode.validationError,
          message: 'Enter the 6-digit code.',
        ),
      );
      return;
    }
    state = state.copyWith(isSubmitting: true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phoneNumber: state.phoneNumber, code: code);
      if (!ref.mounted) return;
      ref.read(sessionViewModelProvider.notifier).signedIn(session);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isSubmitting: false, failure: failure);
    }
  }

  void changePhoneNumber() =>
      state = SignInState(phoneNumber: state.phoneNumber);
}

final signInViewModelProvider =
    NotifierProvider.autoDispose<SignInViewModel, SignInState>(
      SignInViewModel.new,
    );
