import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:video_player/video_player.dart';

/// Inline video player displayed inside a chat bubble.
class VideoMessageBubble extends StatefulWidget {
  const VideoMessageBubble({
    super.key,
    required this.url,
    required this.isSelf,
  });

  final String url;
  final bool isSelf;

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  late VideoPlayerController _vpController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _vpController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _vpController.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _vpController,
        autoPlay: false,
        looping: false,
        showControls: true,
        aspectRatio: _vpController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryEnd,
          handleColor: AppColors.primaryEnd,
          bufferedColor: AppColors.primaryEnd.withOpacity(0.3),
          backgroundColor: Colors.grey.shade300,
        ),
        errorBuilder: (ctx, msg) => _buildError(),
      );
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _vpController.dispose();
    super.dispose();
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              color: widget.isSelf ? Colors.white70 : AppColors.textSecondary,
              size: 20),
          const SizedBox(width: 8),
          Text(
            'Vidéo indisponible',
            style: TextStyle(
              color: widget.isSelf ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildError();

    if (_chewieController == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primaryEnd,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 200,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
