import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles image compression and Supabase Storage upload for personal posts.
/// The bucket `personal-posts` is kept **private**.
class PersonalImageService {
  static const _bucketName = 'personal-posts';

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Compress [image] and upload to `personal-posts/{userId}/{uuid}.jpg`.
  /// Returns the **storage path** (e.g. `{userId}/{uuid}.jpg`), NOT a full URL.
  static Future<String> compressAndUpload({
    required File image,
    required String userId,
  }) async {
    final uuid = _generateUuid();
    final storagePath = '$userId/$uuid.jpg';

    // ── Compress ──────────────────────────────────────────────────────────────
    final compressedBytes = await FlutterImageCompress.compressWithFile(
      image.absolute.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: 75,
      keepExif: false,
      format: CompressFormat.jpeg,
    );

    if (compressedBytes == null) {
      throw Exception('Image compression failed');
    }

    debugPrint(
      '[PersonalImageService] Original: ${await image.length()} bytes, '
      'Compressed: ${compressedBytes.length} bytes',
    );

    // ── Upload ─────────────────────────────────────────────────────────────────
    await Supabase.instance.client.storage.from(_bucketName).uploadBinary(
          storagePath,
          compressedBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
        );

    debugPrint('[PersonalImageService] Uploaded. Storage path: $storagePath');
    return storagePath; // caller stores this path in the DB
  }

  // ── Signed URL (read) ─────────────────────────────────────────────────────

  /// Generate a 1-hour signed URL for [pathOrUrl].
  static Future<String> createSignedUrl(String pathOrUrl) async {
    final path = _extractPath(pathOrUrl);
    debugPrint('[PersonalImageService] Creating signed URL for path: $path');
    return Supabase.instance.client.storage
        .from(_bucketName)
        .createSignedUrl(path, 3600);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Delete an image by its storage path or legacy full URL.
  static Future<void> deleteByUrl(String pathOrUrl) async {
    try {
      final path = _extractPath(pathOrUrl);
      debugPrint('[PersonalImageService] Deleting storage object: $path');
      await Supabase.instance.client.storage.from(_bucketName).remove([path]);
    } catch (e) {
      debugPrint('[PersonalImageService] deleteByUrl error: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _extractPath(String pathOrUrl) {
    if (!pathOrUrl.startsWith('http')) return pathOrUrl;
    final uri = Uri.parse(pathOrUrl);
    final segments = uri.pathSegments;
    final bucketIdx = segments.indexOf(_bucketName);
    if (bucketIdx == -1 || bucketIdx + 1 >= segments.length) return pathOrUrl;
    return segments.sublist(bucketIdx + 1).join('/');
  }

  static String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${now}_${_rand()}_${_rand()}';
  }

  static int _rand() => DateTime.now().microsecondsSinceEpoch % 100000;
}
