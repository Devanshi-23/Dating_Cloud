import '../entities/auth_session.dart';
import '../entities/otp_challenge.dart';

abstract interface class AuthRepository {
  /// Sends a one-time code to [phoneNumber] (E.164, e.g. `+919876543210`).
  Future<OtpChallenge> requestOtp(String phoneNumber);

  Future<AuthSession> verifyOtp({
    required String phoneNumber,
    required String code,
  });

  /// The restored session, or `null` when signed out. Throws on network
  /// failure rather than reporting "signed out".
  Future<AuthSession?> currentSession();

  Future<void> signOut();
}
