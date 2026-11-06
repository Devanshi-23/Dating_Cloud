import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

/// Saves a chat photo into the device gallery.
Future<void> saveChatPhoto(String url) async {
  final granted = await Gal.hasAccess() || await Gal.requestAccess();
  if (!granted) {
    throw StateError('Photo library access was denied.');
  }
  if (url.startsWith('file://')) {
    await Gal.putImage(Uri.parse(url).toFilePath());
    return;
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Could not download this photo.');
    }
    await Gal.putImageBytes(
      Uint8List.fromList(bytes),
      name: 'datingcloud_${DateTime.now().millisecondsSinceEpoch}',
    );
    return;
  }
  throw StateError('This photo cannot be saved.');
}
