import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/onboarding.dart';

abstract interface class PhotoPicker {
  /// Returns `null` when the member cancels.
  Future<LocalImage?> pickFromGallery();
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<LocalImage?> pickFromGallery() async {
    final XFile? file;
    try {
      // Downscaled and re-encoded on device to keep uploads small.
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } on PlatformException catch (error) {
      throw Failure(
        ErrorCode.forbidden,
        message: error.code.contains('access_denied')
            ? 'Allow photo access in Settings to add photos.'
            : 'Your photos could not be opened. Try again.',
      );
    }
    if (file == null) return null;
    return LocalImage(
      path: file.path,
      contentType: file.mimeType ?? _contentTypeFor(file.path),
      sizeBytes: await file.length(),
    );
  }

  static String _contentTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
