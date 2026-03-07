import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// DiceBear avatar style used across the app.
/// Change this value to switch all avatars at once.
/// Popular options: bottts-neutral, avataaars-neutral, shapes,
/// thumbs, fun-emoji, glass, identicon, notionists-neutral.
const _diceBearStyle = 'bottts-neutral';

/// Dedicated cache manager for DiceBear SVG avatars.
/// Uses a separate cache store so avatar files don't compete with other data.
final _avatarCacheManager = CacheManager(Config(
  'dicebear_avatar_cache',
  stalePeriod: const Duration(days: 30),
  maxNrOfCacheObjects: 200,
));

/// A deterministic avatar powered by the DiceBear API.
///
/// Fetches an SVG from `https://api.dicebear.com/9.x/` using the
/// user's [seed] (typically a UUID or pseudo). The result is cached
/// on disk via [flutter_cache_manager] so avatars survive app restarts.
class SeedAvatar extends StatefulWidget {
  const SeedAvatar({
    super.key,
    required this.seed,
    this.size = 80,
  });

  final String seed;
  final double size;

  @override
  State<SeedAvatar> createState() => _SeedAvatarState();
}

class _SeedAvatarState extends State<SeedAvatar> {
  Uint8List? _svgBytes;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant SeedAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final url =
          'https://api.dicebear.com/9.x/$_diceBearStyle/svg?seed=${Uri.encodeComponent(widget.seed)}';
      final file = await _avatarCacheManager.getSingleFile(url);
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _svgBytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.primaryStart,
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return _Shimmer(size: widget.size);
    }

    if (_hasError || _svgBytes == null) {
      return _FallbackAvatar(seed: widget.seed, size: widget.size);
    }

    return SvgPicture.memory(
      _svgBytes!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
    );
  }
}

/// Animated shimmer shown while the SVG is loading.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.size});
  final double size;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [
                AppColors.surface,
                AppColors.primaryStart.withAlpha(30),
                AppColors.surface,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fallback initial-based avatar when DiceBear is unreachable.
class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.seed, required this.size});
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = seed.isNotEmpty ? seed[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: AppColors.primaryStart.withAlpha(25),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.primaryStart,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
