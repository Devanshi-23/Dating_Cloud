import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/json.dart';
import '../../../profile/data/models/profile_dto.dart';
import '../../../profile/domain/entities/user_profile.dart';
import '../../domain/entities/onboarding.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../models/onboarding_dto.dart';

typedef ReadFileBytes = Future<List<int>> Function(String path);

class ApiOnboardingRepository implements OnboardingRepository {
  ApiOnboardingRepository(this._client, {ReadFileBytes? readFile})
    : _readFile = readFile ?? ((path) => File(path).readAsBytes());

  final ApiClient _client;
  final ReadFileBytes _readFile;

  @override
  Future<List<Interest>> getInterests() async => InterestDto.listFromJson(
    asJson(await _client.get(ApiEndpoints.interests)),
  );

  /// `POST /media/upload-url`, then `PUT` the bytes, then `POST /media/complete`.
  @override
  Future<UploadedPhoto> uploadPhoto(
    LocalImage image, {
    String purpose = 'PROFILE_PHOTO',
  }) async {
    final List<int> bytes;
    try {
      bytes = await _readFile(image.path);
    } on FileSystemException {
      throw const Failure(
        ErrorCode.validationError,
        message: 'That photo could not be read. Choose another one.',
      );
    }
    final ticket = asJson(
      await _client.post(
        ApiEndpoints.mediaUploadUrl,
        body: {
          'purpose': purpose,
          'contentType': image.contentType,
          'sizeBytes': bytes.length,
        },
      ),
    );
    final mediaId = ticket.req<String>('mediaId');
    await _client.putBytes(
      ticket.req<String>('uploadUrl'),
      bytes: bytes,
      contentType: image.contentType,
    );
    await _client.post(ApiEndpoints.mediaComplete, body: {'mediaId': mediaId});
    return UploadedPhoto(mediaId: mediaId, previewPath: image.path);
  }

  @override
  Future<MyProfile> completeOnboarding(OnboardingSubmission submission) async =>
      MyProfileDto.fromJson(
        asJson(
          await _client.post(
            ApiEndpoints.onboarding,
            body: OnboardingRequestDto.toJson(submission),
          ),
        ),
      );
}
