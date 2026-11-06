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

  /// `POST /media/upload` as multipart: `file` plus `purpose`.
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
    final media = asJson(
      await _client.upload(
        ApiEndpoints.mediaUpload,
        bytes: bytes,
        filename: _fileName(image.path),
        contentType: image.contentType,
        fields: {'purpose': purpose},
      ),
    );
    return UploadedPhoto(
      mediaId: media.req<String>('mediaId'),
      previewPath: image.path,
    );
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

  static String _fileName(String path) {
    final name = path.replaceAll('\\', '/').split('/').last.trim();
    return name.isEmpty ? 'photo.jpg' : name;
  }
}
