import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileImageService {
  static const String bucketAvatars = 'avatars';
  static const String bucketUsPhotos = 'us-photos';

  /// Compress and upload an image to a specific bucket.
  static Future<String> compressAndUpload({
    required File image,
    required String bucketName,
    required String folderId, // userId for avatars, relationshipId for us-photos
  }) async {
    final uuid = _generateUuid();
    final storagePath = '$folderId/$uuid.jpg';

    // ── Compress ──────────────────────────────────────────────────────────────
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      image.absolute.path,
      minWidth: 512, // Avatars don't need to be huge
      minHeight: 512,
      quality: 80,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception('Image compression failed');
    }

    // ── Upload ─────────────────────────────────────────────────────────────────
    await Supabase.instance.client.storage.from(bucketName).uploadBinary(
          storagePath,
          compressedBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    debugPrint('[ProfileImageService] Uploaded to $bucketName. Path: $storagePath');
    return storagePath;
  }

  /// Generate a signed URL for an image.
  static Future<String> createSignedUrl(String bucketName, String pathOrUrl) async {
    final path = _extractPath(bucketName, pathOrUrl);
    return Supabase.instance.client.storage
        .from(bucketName)
        .createSignedUrl(path, 3600);
  }

  /// Delete an image from a bucket.
  static Future<void> deleteByUrl(String bucketName, String pathOrUrl) async {
    try {
      final path = _extractPath(bucketName, pathOrUrl);
      await Supabase.instance.client.storage.from(bucketName).remove([path]);
    } catch (e) {
      debugPrint('[ProfileImageService] deleteByUrl error: $e');
    }
  }

  static String _extractPath(String bucketName, String pathOrUrl) {
    if (!pathOrUrl.startsWith('http')) return pathOrUrl;
    final uri = Uri.parse(pathOrUrl);
    final segments = uri.pathSegments;
    final bucketIdx = segments.indexOf(bucketName);
    if (bucketIdx == -1 || bucketIdx + 1 >= segments.length) return pathOrUrl;
    return segments.sublist(bucketIdx + 1).join('/');
  }

  static String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${now}_${_rand()}';
  }

  static int _rand() => DateTime.now().microsecondsSinceEpoch % 100000;
}
