import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

const _mockAvatarScheme = 'mock://avatar/';

/// Resolves a profile photo URL to an image provider:
/// `http(s)` -> network (kept in Flutter's in-memory image cache),
/// `file://` -> a photo on this device (just picked, or a mock upload), and
/// `mock://avatar/<id>` -> the bundled fixture portrait. Returns `null` for
/// anything else so callers fall back to initials.
///
/// Prefetching and display must use this same function so the cache key
/// matches and a prefetched photo appears without a loading frame.
ImageProvider? profileImageProvider(String? url) {
  if (url == null) return null;
  if (url.startsWith('https://') || url.startsWith('http://')) {
    return NetworkImage(url);
  }
  if (url.startsWith('file://')) {
    return FileImage(File(Uri.parse(url).toFilePath()));
  }
  if (url.startsWith(_mockAvatarScheme)) {
    final id = url.substring(_mockAvatarScheme.length);
    if (RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
      return AssetImage('assets/mock/profiles/$id.jpg');
    }
  }
  return null;
}

/// Decodes [url] ahead of time so the next card shows instantly. Failures
/// are ignored; the card itself shows the fallback.
Future<void> prefetchProfilePhoto(BuildContext context, String? url) async {
  final provider = profileImageProvider(url);
  if (provider == null) return;
  await precacheImage(provider, context, onError: (_, _) {});
}

/// Profile photo with a loading state and an initials fallback when the URL
/// is missing or fails to load.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.name,
    required this.url,
    this.borderRadius = BorderRadius.zero,
    this.initialsSize = 48,
  });

  final String name;
  final String? url;
  final BorderRadius borderRadius;
  final double initialsSize;

  @override
  Widget build(BuildContext context) {
    final provider = profileImageProvider(url);
    final placeholder = _Placeholder(name: name, initialsSize: initialsSize);
    return ClipRRect(
      borderRadius: borderRadius,
      child: provider == null
          ? placeholder
          : Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'Photo of $name',
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return _LoadingPhoto(showSpinner: provider is NetworkImage);
              },
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 48,
  });

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ProfilePhoto(
      name: name,
      url: url,
      borderRadius: BorderRadius.circular(size),
      initialsSize: size * 0.4,
    ),
  );
}

/// Bundled assets decode in a frame or two, so they get a static backdrop
/// instead of a spinner that would only flash.
class _LoadingPhoto extends StatelessWidget {
  const _LoadingPhoto({required this.showSpinner});

  final bool showSpinner;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: showSpinner
        ? const Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : const SizedBox.expand(),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.initialsSize});

  final String name;
  final double initialsSize;

  @override
  Widget build(BuildContext context) {
    final gradient =
        AppColors.avatarGradients[name.codeUnits.fold<int>(0, (a, b) => a + b) %
            AppColors.avatarGradients.length];
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.white,
            fontSize: initialsSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
