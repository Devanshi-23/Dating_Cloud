import '../../../../core/errors/failure.dart';
import '../../../../dev/mock/mock_backend.dart';
import '../../../../dev/mock/mock_fixtures.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';
import '../../domain/phone_number.dart';
import '../../domain/repositories/auth_repository.dart';

/// OTP `123456` succeeds, `000000` is expired, anything else is invalid.
/// [MockFixtures.phoneNumber] signs in to the onboarded demo account, the
/// number of the saved account (see `MockAccountStore`) restores it, and any
/// other valid number starts a fresh account that must complete onboarding.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<OtpChallenge> requestOtp(String phoneNumber) => _backend.run(
    'requestOtp',
    requiresSession: false,
    () {
      if (!PhoneNumberRules.isValid(phoneNumber)) {
        throw const Failure(
          ErrorCode.validationError,
          message: 'Enter a valid phone number.',
          details: [FieldError(field: 'phoneNumber', reason: 'INVALID_FORMAT')],
        );
      }
      _backend.otpRequestedFor = PhoneNumberRules.normalize(phoneNumber);
      return const OtpChallenge(
        expiresIn: MockFixtures.otpExpiresIn,
        resendAfter: MockFixtures.otpResendAfter,
      );
    },
  );

  @override
  Future<AuthSession> verifyOtp({
    required String phoneNumber,
    required String code,
  }) => _backend.run('verifyOtp', requiresSession: false, () {
    final phone = PhoneNumberRules.normalize(phoneNumber);
    if (_backend.otpRequestedFor != phone ||
        code == MockFixtures.expiredOtpCode) {
      throw const Failure(ErrorCode.otpExpired);
    }
    if (code != MockFixtures.otpCode) {
      throw const Failure(ErrorCode.otpInvalid);
    }
    final saved = _backend.accountStore.saved;
    if (phone == MockFixtures.phoneNumber) {
      if (_backend.phoneNumber != phone) _backend.reset();
    } else if (phone != _backend.phoneNumber) {
      if (saved != null && saved.phoneNumber == phone) {
        _backend.restoreAccount(saved);
      } else {
        _backend.startNewAccount(phone);
      }
    }
    _backend
      ..otpRequestedFor = null
      ..sessionUserId = MockFixtures.currentUserId;
    return _session();
  });

  @override
  Future<AuthSession?> currentSession() =>
      _backend.run('currentSession', requiresSession: false, () {
        return _backend.sessionUserId == null ? null : _session();
      });

  @override
  Future<void> signOut() => _backend.run(
    'signOut',
    requiresSession: false,
    () => _backend.sessionUserId = null,
  );

  AuthSession _session() => AuthSession(
    userId: MockFixtures.currentUserId,
    needsOnboarding: !_backend.onboardingComplete,
  );
}
