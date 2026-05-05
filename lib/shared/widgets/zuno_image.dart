import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';

/// A premium network image widget that handles:
/// 1. Supabase signed URLs (automatic generation and refresh).
/// 2. Smart caching using storage paths as cache keys.
/// 3. Shimmer loading effect.
/// 4. Error states.
class ZunoImage extends StatelessWidget {
  final String pathOrUrl;
  final String? bucket;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final bool isAvatar;
  final Widget? errorWidget;
  final Color? color;
  final BlendMode? colorBlendMode;

  const ZunoImage({
    super.key,
    required this.pathOrUrl,
    this.bucket,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.isAvatar = false,
    this.errorWidget,
    this.color,
    this.colorBlendMode,
  });

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl.isEmpty) return _buildErrorWidget();

    final cacheKey = _getCacheKey();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder<String>(
        // We only generate a signed URL if we don't have a public one.
        // The FutureBuilder ensures we get a fresh URL if needed.
        future: _getImageUrl(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget();
          }

          // While we are waiting for the signed URL, we show the shimmer.
          if (!snapshot.hasData) {
            return _buildPlaceholder();
          }

          return CachedNetworkImage(
            imageUrl: snapshot.data!,
            cacheKey: cacheKey,
            width: width,
            height: height,
            fit: fit,
            color: color,
            colorBlendMode: colorBlendMode,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildErrorWidget(),
          );
        },
      ),
    );
  }

  /// Derives a stable cache key from the storage path.
  String _getCacheKey() {
    if (!pathOrUrl.startsWith('http')) {
      return bucket != null ? '$bucket/$pathOrUrl' : pathOrUrl;
    }

    // If it's a URL, try to extract the storage path to keep the cache stable
    // even if the signed URL query parameters change.
    try {
      final uri = Uri.parse(pathOrUrl);
      final segments = uri.pathSegments;
      
      // Supabase storage URLs usually contain the bucket name.
      if (bucket != null) {
        final bucketIdx = segments.indexOf(bucket!);
        if (bucketIdx != -1 && bucketIdx + 1 < segments.length) {
          return '$bucket/${segments.sublist(bucketIdx + 1).join('/')}';
        }
      }
    } catch (_) {}

    return pathOrUrl;
  }

  Future<String> _getImageUrl() async {
    // If it's already a full URL, return it.
    if (pathOrUrl.startsWith('http')) return pathOrUrl;

    // If we have a path but no bucket, we can't do much.
    if (bucket == null) return pathOrUrl;

    // Generate a signed URL that lasts 1 hour.
    // Note: Since we use cacheKey, the expiration only matters if the image
    // is NOT already in the local cache.
    return Supabase.instance.client.storage
        .from(bucket!)
        .createSignedUrl(pathOrUrl, 3600);
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: ZunoTheme.surfaceContainerHigh,
      highlightColor: ZunoTheme.surfaceContainerHighest,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? (isAvatar ? width : 200),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width ?? double.infinity,
      height: height ?? (isAvatar ? width : 200),
      decoration: BoxDecoration(
        color: ZunoTheme.surfaceContainerHigh,
        shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20),
    );
  }
}
