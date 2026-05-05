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
  final bool enableTapToView;
  final String? heroTag;

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
    this.enableTapToView = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl.isEmpty) return _buildErrorWidget();

    final cacheKey = _getCacheKey();

    Widget imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder<String>(
        future: _getImageUrl(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget();
          }

          if (!snapshot.hasData) {
            return _buildPlaceholder();
          }

          final imageUrl = snapshot.data!;

          Widget current = CachedNetworkImage(
            imageUrl: imageUrl,
            cacheKey: cacheKey,
            width: width,
            height: height,
            fit: fit,
            color: color,
            colorBlendMode: colorBlendMode,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildErrorWidget(),
          );

          if (heroTag != null) {
            current = Hero(
              tag: heroTag!,
              child: current,
            );
          }

          if (enableTapToView) {
            return GestureDetector(
              onTap: () => _showFullView(context, imageUrl, cacheKey),
              child: current,
            );
          }

          return current;
        },
      ),
    );

    return imageWidget;
  }

  void _showFullView(BuildContext context, String imageUrl, String cacheKey) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => ZunoImageFullView(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          heroTag: heroTag,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Derives a stable cache key from the storage path.
// ... existing _getCacheKey, _getImageUrl, _buildPlaceholder, _buildErrorWidget ...
  String _getCacheKey() {
    if (!pathOrUrl.startsWith('http')) {
      return bucket != null ? '$bucket/$pathOrUrl' : pathOrUrl;
    }

    try {
      final uri = Uri.parse(pathOrUrl);
      final segments = uri.pathSegments;
      
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
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    if (bucket == null) return pathOrUrl;

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

class ZunoImageFullView extends StatelessWidget {
  final String imageUrl;
  final String cacheKey;
  final String? heroTag;

  const ZunoImageFullView({
    super.key,
    required this.imageUrl,
    required this.cacheKey,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: _buildImage(),
                      )
                    : _buildImage(),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: cacheKey,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.white24),
      ),
      errorWidget: (context, url, error) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white24,
        size: 40,
      ),
    );
  }
}

