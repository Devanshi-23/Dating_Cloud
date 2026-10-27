class OtpChallenge {
  const OtpChallenge({required this.expiresIn, required this.resendAfter});

  final Duration expiresIn;

  /// How long the UI must wait before offering "Resend code".
  final Duration resendAfter;
}
