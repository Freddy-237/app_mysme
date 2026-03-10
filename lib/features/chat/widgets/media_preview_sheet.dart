import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mysme/core/theme/app_colors.dart';

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
  final _pageController = PageController();
  final _stripController = ScrollController();
  int _selected = 0;
  final _picker = ImagePicker();

  // Width of each thumbnail tile (image + margin) used for auto-scroll.
  static const double _tileW = 62.0; // 56px + 6px margin
  static const double _stripPadding = 10.0;

  @override
  void initState() {
    super.initState();
    _files = List<XFile>.from(widget.initialFiles);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    _stripController.dispose();
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
      if (_selected >= _files.length) _selected = _files.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_selected);
        }
      });
    });
  }

  void _send() {
    Navigator.of(context).pop();
    widget.onSend(List<XFile>.from(_files), _captionController.text.trim());
  }

  void _selectPage(int i) {
    setState(() => _selected = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
    );
    // Scroll thumbnail strip so selected item stays in view.
    if (_stripController.hasClients) {
      final maxScroll = _stripController.position.maxScrollExtent;
      final offset = (_stripPadding + i * _tileW).clamp(0.0, maxScroll);
      _stripController.animateTo(
        offset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: _kBg,
      child: Column(
        children: [
          //  Top bar
          _TopBar(
            count: _files.length,
            current: _selected,
            onClose: () => Navigator.pop(context),
            onDelete: () => _removeAt(_selected),
          ),

          //  Image viewer
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _files.length,
              onPageChanged: (i) {
                setState(() => _selected = i);
                // Sync strip scroll on manual swipe.
                if (_stripController.hasClients) {
                  final maxScroll = _stripController.position.maxScrollExtent;
                  final offset =
                      (_stripPadding + i * _tileW).clamp(0.0, maxScroll);
                  _stripController.animateTo(
                    offset,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                  );
                }
              },
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(_files[i].path),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          //  Thumbnail strip
          _ThumbnailStrip(
            files: _files,
            selected: _selected,
            scrollController: _stripController,
            onTap: _selectPage,
            onDelete: _removeAt,
            onAdd: _addMore,
          ),

          //  Caption + send
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            padding: EdgeInsets.only(bottom: bottom),
            child: _CaptionBar(
              controller: _captionController,
              onSend: _send,
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
    required this.current,
    required this.onClose,
    required this.onDelete,
  });

  final int count;
  final int current;
  final VoidCallback onClose;
  final VoidCallback onDelete;

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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onClose,
            ),
            const Spacer(),
            if (count > 1)
              Text(
                '${current + 1} / $count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

//  Thumbnail strip

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.files,
    required this.selected,
    required this.scrollController,
    required this.onTap,
    required this.onDelete,
    required this.onAdd,
  });

  final List<XFile> files;
  final int selected;
  final ScrollController scrollController;
  final void Function(int index) onTap;
  final void Function(int index) onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: _kSurface,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: files.length + 1, // last tile = "add more"
        itemBuilder: (_, i) {
          //  "Add more" tile
          if (i == files.length) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 56,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white38, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white60,
                  size: 26,
                ),
              ),
            );
          }

          final isSelected = i == selected;

          return GestureDetector(
            onTap: () => onTap(i),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Thumbnail image
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.25),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5.5),
                    child: Image.file(
                      File(files[i].path),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // x delete badge
                Positioned(
                  top: -4,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onDelete(i),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _kBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          //  Input pill
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
                          contentPadding: EdgeInsets.fromLTRB(8, 10, 14, 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          //  Send button
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
    );
  }
}
