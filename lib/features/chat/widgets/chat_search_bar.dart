import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mysme/shared/widgets/themed_icon_button.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Inline search bar overlay for the chat screen.
///
/// Shows a text field at the top. As the user types, results appear in a list.
/// Tapping a result calls [onResultTap] with the matching [MessageDto].
class ChatSearchBar extends StatefulWidget {
  const ChatSearchBar({
    super.key,
    required this.conversationId,
    required this.messageRepository,
    required this.onResultTap,
    required this.onClose,
  });

  final String conversationId;
  final MessageRepository messageRepository;
  final void Function(MessageDto message) onResultTap;
  final VoidCallback onClose;

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MessageDto> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await widget.messageRepository.searchMessages(
          widget.conversationId,
          value.trim(),
        );
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
          _error = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Recherche impossible pour le moment';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(adaptiveBackIcon(context)),
                    onPressed: widget.onClose,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onChanged,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un message…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  _onChanged('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // Results
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade400),
                ),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final msg = _results[index];
                    return ListTile(
                      dense: true,
                      onTap: () => widget.onResultTap(msg),
                      title: Text(
                        msg.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _formatDate(msg.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      leading: Icon(
                        msg.mediaType != null
                            ? _mediaIcon(msg.mediaType!)
                            : Icons.chat_bubble_outline,
                        color: AppColors.deepPurple,
                        size: 20,
                      ),
                    );
                  },
                ),
              )
            else if (_controller.text.trim().isNotEmpty && !_loading)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Aucun résultat',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Aujourd\'hui ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hier ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData _mediaIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.videocam;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.mic;
      case 'file':
        return Icons.attach_file;
      default:
        return Icons.chat_bubble_outline;
    }
  }
}
