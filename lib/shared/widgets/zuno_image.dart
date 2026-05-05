import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_theme.dart';

/// A premium network image widget that handles:
/// 1. Supabase signed URLs (automatic generation and refresh).
/// 2. Smart caching using storage paths as cache keys.
/// 3. Shimmer loading effect.
/// 4. Error states.
/// 5. Tap to view full screen with download option.
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

class ZunoImageFullView extends StatefulWidget {
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
  State<ZunoImageFullView> createState() => _ZunoImageFullViewState();
}

class _ZunoImageFullViewState extends State<ZunoImageFullView> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    setState(() => _isDownloading = true);
    HapticFeedback.mediumImpact();

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/zuno_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Dio().download(widget.imageUrl, path);
      await Gal.putImage(path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved to gallery! ✨', 
              style: TextStyle(color: ZunoTheme.onTertiary)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ZunoTheme.tertiaryContainer,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ZunoImage] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save image. Please check permissions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Image
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: widget.heroTag != null
                    ? Hero(
                        tag: widget.heroTag!,
                        child: _buildImage(),
                      )
                    : _buildImage(),
              ),
            ),
          ),

          // Top Bar Actions
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Button
                _CircleAction(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),

                // Download Button
                _CircleAction(
                  icon: _isDownloading ? Icons.hourglass_bottom_rounded : Icons.download_for_offline_rounded,
                  isLoading: _isDownloading,
                  onPressed: _downloadImage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      cacheKey: widget.cacheKey,
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

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const _CircleAction({
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: isLoading 
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            )
          : Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}


