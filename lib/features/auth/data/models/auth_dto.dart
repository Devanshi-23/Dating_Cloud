import '../../../../core/network/json.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_challenge.dart';

/// Response of `POST /auth/otp/request`.
class OtpChallengeDto {
  static OtpChallenge fromJson(Json json) => OtpChallenge(
    expiresIn: Duration(seconds: json.reqInt('expiresInSeconds')),
    resendAfter: Duration(seconds: json.reqInt('resendAfterSeconds')),
  );
}

/// Response of `POST /auth/otp/verify`.
class VerifyOtpResponseDto {
  const VerifyOtpResponseDto({
    required this.userId,
    required this.needsOnboarding,
    required this.tokens,
  });

  factory VerifyOtpResponseDto.fromJson(Json json) {
    final tokens = asJson(json['tokens'], 'tokens');
    final user = asJson(json['user'], 'user');
    return VerifyOtpResponseDto(
      userId: user.req<String>('id'),
      needsOnboarding:
          (json.opt<bool>('isNewUser') ?? false) ||
          user.opt<bool>('onboardingComplete') == false,
      tokens: AuthTokens(
        accessToken: tokens.req<String>('accessToken'),
        refreshToken: tokens.req<String>('refreshToken'),
      ),
    );
  }

  final String userId;
  final bool needsOnboarding;
  final AuthTokens tokens;

  AuthSession toEntity() =>
      AuthSession(userId: userId, needsOnboarding: needsOnboarding);
}
