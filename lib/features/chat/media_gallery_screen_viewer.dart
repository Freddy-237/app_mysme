part of 'media_gallery_screen.dart';

extension _MediaGalleryViewer on _MediaGalleryScreenState {
  void _openMediaViewer(MessageDto msg) {
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty) return;
    final type = msg.mediaType ?? '';

    switch (type) {
      case 'image':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _FullImageViewer(
              url: url,
              onCopy: () => _copyMediaUrl(url),
              onShare: () => _shareMediaUrl(url),
            ),
          ),
        );
        return;
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _FullVideoViewer(
              url: url,
              title: _mediaDisplayName(url),
              onCopy: () => _copyMediaUrl(url),
              onShare: () => _shareMediaUrl(url),
            ),
          ),
        );
        return;
      case 'audio':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => _FullAudioViewer(
              url: url,
              title: _mediaDisplayName(url),
              onCopy: () => _copyMediaUrl(url),
              onShare: () => _shareMediaUrl(url),
            ),
          ),
        );
        return;
      default:
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          backgroundColor: Colors.white,
          builder: (_) => _MediaFileSheet(
            name: _mediaDisplayName(url),
            url: url,
            onCopy: () => _copyMediaUrl(url),
            onShare: () => _shareMediaUrl(url),
          ),
        );
    }
  }

  String _mediaDisplayName(String url) {
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments;
    if (segments != null && segments.isNotEmpty) {
      return Uri.decodeComponent(segments.last);
    }
    return url;
  }

  Future<void> _copyMediaUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lien du média copié'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareMediaUrl(String url) async {
    try {
      await Share.share(url);
    } catch (error) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        error,
        fallback: 'Partage impossible pour le moment.',
      );
    }
  }
}

/// Simple full-screen image viewer with pinch-to-zoom.
class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({
    required this.url,
    required this.onCopy,
    required this.onShare,
  });

  final String url;
  final Future<void> Function() onCopy;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: ThemedIconButton(
            icon: adaptiveBackIcon(context),
            iconSize: 18,
            dark: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        actions: [
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullVideoViewer extends StatefulWidget {
  const _FullVideoViewer({
    required this.url,
    required this.title,
    required this.onCopy,
    required this.onShare,
  });

  final String url;
  final String title;
  final Future<void> Function() onCopy;
  final Future<void> Function() onShare;

  @override
  State<_FullVideoViewer> createState() => _FullVideoViewerState();
}

class _FullVideoViewerState extends State<_FullVideoViewer> {
  late final VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      await _videoController.initialize();
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowMuting: true,
        allowFullScreen: true,
        aspectRatio: _videoController.value.aspectRatio == 0
            ? 16 / 9
            : _videoController.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primaryEnd,
          handleColor: AppColors.primaryEnd,
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white10,
        ),
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
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: widget.onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            onPressed: widget.onShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: _hasError
            ? const _MediaErrorState(
                icon: Icons.videocam_off_rounded,
                message: 'Vidéo indisponible',
              )
            : _chewieController == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Chewie(controller: _chewieController!),
      ),
    );
  }
}

class _FullAudioViewer extends StatefulWidget {
  const _FullAudioViewer({
    required this.url,
    required this.title,
    required this.onCopy,
    required this.onShare,
  });

  final String url;
  final String title;
  final Future<void> Function() onCopy;
  final Future<void> Function() onShare;

  @override
  State<_FullAudioViewer> createState() => _FullAudioViewerState();
}

class _FullAudioViewerState extends State<_FullAudioViewer> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final duration = await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() => _duration = duration ?? Duration.zero);
      _player.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });
      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
        setState(() {});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds;
    final positionMs =
        _position.inMilliseconds.clamp(0, totalMs <= 0 ? 0 : totalMs);
    final isPlaying = _player.playing;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: widget.onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            onPressed: widget.onShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _hasError
              ? const _MediaErrorState(
                  icon: Icons.audio_file_outlined,
                  message: 'Audio indisponible',
                )
              : Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryStart.withOpacity(0.18),
                        ),
                        child: const Icon(
                          Icons.graphic_eq_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primaryEnd,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: AppColors.primaryEnd,
                        ),
                        child: Slider(
                          value: positionMs.toDouble(),
                          max: (totalMs <= 0 ? 1 : totalMs).toDouble(),
                          onChanged: totalMs <= 0
                              ? null
                              : (value) => _player.seek(
                                    Duration(milliseconds: value.round()),
                                  ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _format(_position),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            _format(_duration),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () {
                          if (isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(isPlaying ? 'Pause' : 'Lecture'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryStart,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _MediaFileSheet extends StatelessWidget {
  const _MediaFileSheet({
    required this.name,
    required this.url,
    required this.onCopy,
    required this.onShare,
  });

  final String name;
  final String url;
  final Future<void> Function() onCopy;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryStart.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: AppColors.primaryStart,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await onCopy();
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier le lien'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await onShare();
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Partager'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStart,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaErrorState extends StatelessWidget {
  const _MediaErrorState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 52),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
