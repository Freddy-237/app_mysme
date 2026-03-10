import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Composable input bar with reply preview, text field, media/audio buttons
/// and send action — extracted from [ChatScreen].
class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.bottomPadding,
    required this.controller,
    required this.focusNode,
    required this.expired,
    required this.isSending,
    required this.isRecordingAudio,
    required this.uploadProgress,
    required this.uploadLabel,
    this.replyTo,
    required this.onSend,
    required this.onMediaMenu,
    required this.onToggleAudio,
    required this.onInputChanged,
    required this.onClearReply,
    required this.replyPreviewText,
    this.onReplyTap,
    this.recorderController,
  });

  final double bottomPadding;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expired;
  final bool isSending;
  final bool isRecordingAudio;
  final double? uploadProgress;
  final String? uploadLabel;
  final MessageDto? replyTo;
  final VoidCallback onSend;
  final VoidCallback onMediaMenu;
  final VoidCallback onToggleAudio;
  final ValueChanged<String> onInputChanged;
  final VoidCallback onClearReply;
  final String replyPreviewText;
  final VoidCallback? onReplyTap;

  /// Optional [RecorderController] from [audio_waveforms]  used to display a
  /// live waveform while [isRecordingAudio] is true.
  final RecorderController? recorderController;

  @override
  Widget build(BuildContext context) {
    final canSend = controller.text.trim().isNotEmpty && !expired && !isSending;
    final isUploading = uploadProgress != null;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: bottomPadding + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.primaryEnd.withOpacity(0.15),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUploading) _buildUploadProgress(),
          Row(
            children: [
              IconButton(
                onPressed: expired || isUploading ? null : onMediaMenu,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.primaryEnd,
              ),

              // Text field + reply preview (or live waveform when recording)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (replyTo != null) _buildReplyBanner(),
                    isRecordingAudio && recorderController != null
                        ? _buildWaveformBar()
                        : _buildTextField(),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              IconButton(
                onPressed: expired || isUploading ? null : onToggleAudio,
                icon: Icon(
                  isRecordingAudio
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none_rounded,
                ),
                color:
                    isRecordingAudio ? Colors.redAccent : AppColors.primaryEnd,
              ),

              const SizedBox(width: 2),

              // Send button
              GestureDetector(
                onTap: canSend ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.deepPurple, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: canSend
                        ? [
                            BoxShadow(
                              color: AppColors.primaryEnd.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: isSending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: Colors.white.withOpacity(canSend ? 1 : 0.6),
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    // Socket transport provides no byte-level progress: use indeterminate bar
    final known = uploadProgress != null && uploadProgress! > 0;
    final displayValue = known ? uploadProgress : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            known
                ? '${uploadLabel ?? 'Upload'} ${((uploadProgress!) * 100).toStringAsFixed(0)}%'
                : uploadLabel ?? 'Envoi en cours…',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: displayValue,
              minHeight: 5,
              color: AppColors.primaryEnd,
              backgroundColor: AppColors.primaryEnd.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryEnd.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Réponse à: $replyPreviewText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          InkWell(
            onTap: onClearReply,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryEnd.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fiber_manual_record,
            color: Colors.redAccent,
            size: 10,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AudioWaveforms(
              recorderController: recorderController!,
              size: const Size(double.infinity, 28),
              waveStyle: const WaveStyle(
                waveColor: AppColors.primaryEnd,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: const BoxConstraints(minHeight: 46, maxHeight: 108),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2FB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryEnd.withOpacity(0.16),
        ),
      ),
      child: TextField(
        focusNode: focusNode,
        controller: controller,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          hintText: 'Message',
          hintStyle: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 15,
          ),
          filled: false,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
        onSubmitted: (_) => onSend(),
        onChanged: (value) {
          onInputChanged(value);
        },
      ),
    );
  }
}
