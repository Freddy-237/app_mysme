import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Inline audio player displayed inside a chat bubble.
class AudioMessageBubble extends StatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.url,
    required this.isSelf,
  });

  final String url;
  final bool isSelf;

  @override
  State<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends State<AudioMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  late final AnimationController _waveController;
  Duration _total = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final dur = await _player.setUrl(widget.url);
      if (!mounted) return;
      setState(() => _total = dur ?? Duration.zero);

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        // When playback completes, reset to start.
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
        if (state.playing) {
          if (!_waveController.isAnimating) {
            _waveController.repeat();
          }
        } else {
          _waveController.stop();
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
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isSelf ? Colors.white : AppColors.primaryEnd;
    final secondaryColor =
        widget.isSelf ? Colors.white54 : AppColors.textSecondary;

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: secondaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Audio indisponible',
              style: TextStyle(color: primaryColor),
            ),
          ],
        ),
      );
    }

    final isPlaying = _player.playing;
    final totalMs = _total.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: () {
              if (isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.15),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mini sinusoid waveform
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (_total == Duration.zero || width <= 0) return;
                        final ratio =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        _player.seek(
                          Duration(
                            milliseconds:
                                (_total.inMilliseconds * ratio).round(),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 26,
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (_, __) {
                            return CustomPaint(
                              painter: _WaveformPainter(
                                progress: progress,
                                phase: _waveController.value,
                                activeColor: primaryColor,
                                inactiveColor: primaryColor.withOpacity(0.25),
                                isPlaying: isPlaying,
                              ),
                              size: Size(width, 26),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_total)}',
                    style: TextStyle(fontSize: 11, color: secondaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.progress,
    required this.phase,
    required this.activeColor,
    required this.inactiveColor,
    required this.isPlaying,
  });

  final double progress;
  final double phase;
  final Color activeColor;
  final Color inactiveColor;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 32;
    const barWidth = 2.4;
    const minHeight = 3.0;
    final gap = (size.width - bars * barWidth) / (bars - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < bars; i++) {
      final t = i / (bars - 1);
      final wave = math.sin((t * 3.8 * math.pi) + (phase * 2 * math.pi));
      final envelope = 0.45 + 0.55 * math.sin(t * math.pi);
      final pulse = isPlaying ? (0.84 + 0.16 * wave) : 0.84;
      final h = minHeight + (size.height * 0.72 * envelope * pulse);

      final left = i * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, centerY - h / 2, barWidth, h),
        const Radius.circular(2),
      );

      final color = t <= progress ? activeColor : inactiveColor;
      final paint = Paint()..color = color;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.isPlaying != isPlaying;
  }
}
