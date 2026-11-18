import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/shared/widgets/themed_icon_button.dart';

//  Colours inspired by WhatsApp dark UI
const _kBg = Color(0xFF111B21);
const _kSurface = Color(0xFF1F2C34);
const _kInput = Color(0xFF2A3942);

/// Full-screen modal that previews selected images before sending.
/// Layout inspired by WhatsApp.
class MediaPreviewSheet extends StatefulWidget {
  const MediaPreviewSheet({
    super.key,
    required this.initialFiles,
    required this.onSend,
  });

  final List<XFile> initialFiles;

  /// Called synchronously when user confirms. Parent handles the upload.
  final void Function(List<XFile> files, String caption) onSend;

  @override
  State<MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<MediaPreviewSheet> {
  late final List<XFile> _files;
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.initialFiles);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _addMore() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    setState(() => _files.addAll(picked));
  }

  void _removeAt(int index) {
    if (_files.length == 1) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _files.removeAt(index);
    });
  }

  void _send() {
    Navigator.of(context).pop();
    widget.onSend(List<XFile>.from(_files), _captionController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isMultiSelection = _files.length > 1;

    return Material(
      color: _kBg,
      child: Column(
        children: [
          //  Top bar
          _TopBar(
            count: _files.length,
            isMultiSelection: isMultiSelection,
            onClose: () => Navigator.pop(context),
            onDelete: isMultiSelection ? null : () => _removeAt(0),
          ),

          //  Preview area
          Expanded(
            child: isMultiSelection
                ? _SelectedMediaGrid(
                    files: _files,
                    onDelete: _removeAt,
                    onAdd: _addMore,
                  )
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        File(_files.first.path),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),

          //  Caption + send
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(bottom: bottom),
            child: _CaptionBar(
              controller: _captionController,
              onSend: _send,
              mediaCount: _files.length,
            ),
          ),
        ],
      ),
    );
  }
}

//  Top bar

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.count,
    required this.isMultiSelection,
    required this.onClose,
    required this.onDelete,
  });

  final int count;
  final bool isMultiSelection;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        color: _kSurface,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(adaptiveBackIcon(context), color: Colors.white),
              onPressed: onClose,
            ),
            const Spacer(),
            Text(
              isMultiSelection
                  ? '$count éléments sélectionnés'
                  : 'Prévisualisation',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: onDelete,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _SelectedMediaGrid extends StatelessWidget {
  const _SelectedMediaGrid({
    required this.files,
    required this.onDelete,
    required this.onAdd,
  });

  final List<XFile> files;
  final void Function(int index) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        itemCount: files.length + 1,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (_, i) {
          if (i == files.length) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                decoration: BoxDecoration(
                  color: _kInput,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white70,
                      size: 30,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ajouter',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(files[i].path),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Image ${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => onDelete(i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.58),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

//  Caption bar

class _CaptionBar extends StatelessWidget {
  const _CaptionBar({
    required this.controller,
    required this.onSend,
    required this.mediaCount,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final int mediaCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mediaCount > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.collections_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$mediaCount images seront envoyées',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 130),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kInput,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 14, bottom: 11),
                          child: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.white54,
                            size: 22,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              hintText: 'Ajouter une legende...',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 15,
                              ),
                              filled: false,
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.fromLTRB(8, 10, 14, 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
