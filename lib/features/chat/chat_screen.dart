import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/services/iap_service.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/chat/widgets/chat_bubble.dart';
import 'package:mysme/features/chat/widgets/chat_header.dart';
import 'package:mysme/features/chat/widgets/chat_input_bar.dart';
import 'package:mysme/features/chat/widgets/chat_lock_overlay.dart';
import 'package:mysme/features/chat/widgets/chat_search_bar.dart';
import 'package:mysme/features/chat/media_gallery_screen.dart';
import 'package:mysme/features/chat/widgets/media_preview_sheet.dart';
import 'package:mysme/features/chat/widgets/menu_button.dart';

/// Full-screen ephemeral chat view.
///
/// Receives [conversationId] as a constructor parameter from go_router.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _pageSize = 30;

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  late final PagingController<int, MessageDto> _pagingController;

  String? _conversationId;
  ConversationDto? _conversation;
  Timer? _countdownTimer;
  Timer? _typingTimer;
  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _identityRevealed = false;
  bool _isTyping = false; // other person is typing
  bool _isOtherOnline = false;
  bool _isSending = false;
  bool _socketSetup = false;
  MessageDto? _replyTo;
  final List<void Function()> _socketDisposers = [];
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  late final AudioRecorderService _recorderService;
  bool _isRecordingAudio = false;
  double? _uploadProgress;
  String? _uploadLabel;
  bool _showSearch = false;

  /// Conversation is locked after 7 days.
  bool get _isLocked {
    if (_conversation == null) return false;
    return _conversation!.isExpired;
  }

  @override
  void initState() {
    super.initState();
    _recorderService = AudioRecorderService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_conversationId != null) return;

    _conversationId = widget.conversationId;
    _pagingController = PagingController<int, MessageDto>(
      getNextPageKey: (state) {
        if (!state.hasNextPage) return null;
        final pages = state.pages;
        if (pages == null || pages.isEmpty) return 0;
        // If the last fetched page has fewer items than _pageSize, we're done.
        if (pages.last.length < _pageSize) return null;
        final totalItems = pages.fold<int>(0, (sum, page) => sum + page.length);
        return totalItems;
      },
      fetchPage: (offset) async {
        final repo = ref.read(messageRepositoryProvider);
        return repo.getMessages(
          _conversationId!,
          limit: _pageSize,
          offset: offset,
        );
      },
    );
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    try {
      final repo = ref.read(conversationRepositoryProvider);
      final conv = await repo.getConversation(_conversationId!);
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        _expired = conv.isExpired;
        _remaining = conv.remainingTime;
      });
      _startCountdown();
      _setupSocket();
      // Mark as read when entering conversation.
      ref.read(conversationProvider.notifier).markAsRead(_conversationId!);
      // Restore trust level from backend.
      _loadTrustLevel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  // -- Socket --

  Future<void> _setupSocket() async {
    if (_socketSetup) return;
    _socketSetup = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect(apiBaseUrl);

    _disposeSocketListeners();

    socket.joinConversation(_conversationId!);
    socket.emitMarkRead(_conversationId!);

    _socketDisposers.add(socket.onNewMessage((data) {
      if (!mounted) return;
      final msg = MessageDto.fromJson(data);
      final currentItems = _pagingController.items ?? [];
      if (currentItems.any((m) => m.id == msg.id)) return;
      final currentPages = _pagingController.value.pages ?? [];
      final firstPage =
          currentPages.isNotEmpty ? [msg, ...currentPages.first] : [msg];
      _pagingController.value = _pagingController.value.copyWith(
        pages: [firstPage, ...currentPages.skip(1)],
      );
      _scrollToBottom();
    }));

    _socketDisposers.add(socket.onMessageDeleted((data) {
      if (!mounted) return;
      final id = (data['messageId'] ?? data['id'] ?? '') as String;
      if (id.isEmpty) return;
      final currentPages = _pagingController.value.pages;
      if (currentPages == null) return;
      _pagingController.value = _pagingController.value.copyWith(
        pages: currentPages
            .map((page) => page.where((m) => m.id != id).toList())
            .toList(),
      );
    }));

    _socketDisposers.add(socket.onTypingStart((data) {
      if (!mounted) return;
      final cid = (data['conversationId'] ?? '') as String;
      if (cid != _conversationId) return;
      _typingTimer?.cancel();
      setState(() => _isTyping = true);
      _typingTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }));

    _socketDisposers.add(socket.onTypingStop((data) {
      if (!mounted) return;
      final cid = (data['conversationId'] ?? '') as String;
      if (cid != _conversationId) return;
      _typingTimer?.cancel();
      setState(() => _isTyping = false);
    }));

    _socketDisposers.add(socket.onMessagesRead((data) {
      if (!mounted) return;
      final cid = (data['conversationId'] ?? '') as String;
      final readerId = (data['userId'] ?? '') as String;
      final myId = ref.read(authProvider).userId ?? '';
      if (cid != _conversationId || readerId.isEmpty || readerId == myId) {
        return;
      }
      _markMyMessagesAsRead();
    }));

    // --- Presence tracking ---
    final myId = ref.read(authProvider).userId ?? '';
    final conv = _conversation!;
    final otherUserId =
        (myId == conv.ownerId) ? conv.anonymousId : conv.ownerId;

    if (otherUserId != null && otherUserId.isNotEmpty) {
      _socketDisposers.add(socket.onUserOnline((data) {
        if (!mounted) return;
        final uid = (data['userId'] ?? '') as String;
        if (uid == otherUserId) setState(() => _isOtherOnline = true);
      }));

      _socketDisposers.add(socket.onUserOffline((data) {
        if (!mounted) return;
        final uid = (data['userId'] ?? '') as String;
        if (uid == otherUserId) setState(() => _isOtherOnline = false);
      }));

      _socketDisposers.add(socket.onPresenceResult((data) {
        if (!mounted) return;
        final uid = (data['userId'] ?? '') as String;
        final online = (data['online'] ?? false) as bool;
        if (uid == otherUserId) setState(() => _isOtherOnline = online);
      }));

      socket.checkPresence(otherUserId);
    }
  }

  void _disposeSocketListeners() {
    for (final disposeListener in _socketDisposers) {
      disposeListener();
    }
    _socketDisposers.clear();
  }

  void _markMyMessagesAsRead() {
    final myId = ref.read(authProvider).userId ?? '';
    final currentPages = _pagingController.value.pages;
    if (currentPages == null || myId.isEmpty) return;

    final updatedPages = currentPages
        .map(
          (page) => page
              .map(
                (m) => m.senderId == myId && !m.isRead
                    ? m.copyWith(isRead: true)
                    : m,
              )
              .toList(),
        )
        .toList();

    _pagingController.value = _pagingController.value.copyWith(
      pages: updatedPages,
    );
  }

  Timer? _localTypingTimer;

  void _onInputChanged(String text) {
    if (_conversationId == null) return;
    final socket = ref.read(socketServiceProvider);
    if (text.isNotEmpty) {
      socket.emitTypingStart(_conversationId!);
      _localTypingTimer?.cancel();
      _localTypingTimer = Timer(const Duration(seconds: 3), () {
        socket.emitTypingStop(_conversationId!);
      });
    } else {
      _localTypingTimer?.cancel();
      socket.emitTypingStop(_conversationId!);
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToOriginalMessage(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;

    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      _highlightTimer?.cancel();
      if (mounted) {
        setState(() => _highlightedMessageId = messageId);
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      _highlightTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && _highlightedMessageId == messageId) {
          setState(() => _highlightedMessageId = null);
        }
      });
      return;
    }

    final loaded =
        _pagingController.items?.any((message) => message.id == messageId) ??
            false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loaded
              ? 'Fais defiler pour voir le message original'
              : 'Message original non charge',
        ),
      ),
    );
  }

  void _startCountdown() {
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (_conversation == null) return;
    final remaining = _conversation!.remainingTime;
    if (remaining == Duration.zero) {
      _countdownTimer?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _expired = true;
      });
    } else {
      setState(() => _remaining = remaining);
    }
  }

  String _formatRemaining() {
    if (_remaining.inDays > 0) return '-${_remaining.inDays}j';
    if (_remaining.inHours > 0) return '-${_remaining.inHours}h';
    if (_remaining.inMinutes > 0) return '-${_remaining.inMinutes}min';
    if (_remaining.inSeconds > 0) return '-${_remaining.inSeconds}s';
    return '0';
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MenuButton(
                  label: 'Rechercher un message',
                  icon: Icons.search,
                  iconColor: AppColors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _showSearch = true);
                  },
                ),
                const SizedBox(height: 16),
                MenuButton(
                  label: 'Médias partagés',
                  icon: Icons.photo_library_outlined,
                  iconColor: AppColors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MediaGalleryScreen(
                          conversationId: _conversationId!,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                MenuButton(
                  label: 'Delete this discution',
                  icon: Icons.delete_outline,
                  iconColor: AppColors.primaryEnd,
                  onTap: () async {
                    Navigator.pop(context);
                    if (_conversationId != null) {
                      try {
                        await ref
                            .read(conversationProvider.notifier)
                            .deleteConversation(_conversationId!);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                MenuButton(
                  label: 'Report this user',
                  icon: Icons.thumb_down_alt_outlined,
                  iconColor: AppColors.primaryEnd,
                  onTap: () async {
                    Navigator.pop(context);
                    if (_conversationId != null) {
                      try {
                        await ref.read(moderationRepositoryProvider).report(
                              conversationId: _conversationId!,
                              reason: 'user_report',
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Utilisateur signale avec succes'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTrustLevel() async {
    try {
      final trust =
          await ref.read(trustRepositoryProvider).getTrust(_conversationId!);
      if (!mounted) return;
      setState(() {
        _identityRevealed = trust.level == 'revealed';
      });
    } catch (_) {
      // Trust may not be initialised yet — ignore.
    }
  }

  Future<void> _handleSingleUnlock() async {
    if (_conversationId == null) return;
    try {
      final iap = ref.read(iapServiceProvider);
      await iap.buyUnlock(_conversationId!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'achat: $e')),
      );
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _expired || _conversationId == null || _isSending) {
      return;
    }

    final replyTarget = _replyTo;

    setState(() => _isSending = true);
    _input.clear();
    _scrollToBottom();
    try {
      await ref.read(messageRepositoryProvider).sendMessage(
            _conversationId!,
            text,
            replyToMessageId: replyTarget?.id,
          );
      if (mounted) {
        setState(() => _replyTo = null);
      }
    } catch (e) {
      if (!mounted) return;

      // Queue message for offline retry on network errors
      final isNetwork = e is SocketException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Connection') ||
          e.toString().contains('timeout');

      if (isNetwork) {
        await ref.read(offlineQueueProvider).enqueue(PendingMessage(
              conversationId: _conversationId!,
              content: text,
              replyToMessageId: replyTarget?.id,
              queuedAt: DateTime.now(),
            ));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Hors ligne — message en file d\'attente')),
        );
      } else {
        _input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Echec de l\'envoi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _replyPreview(MessageDto msg) {
    final raw = msg.content.trim();
    if (raw.isEmpty) return 'Message';
    const limit = 40;
    if (raw.length <= limit) return raw;
    return '${raw.substring(0, limit)}...';
  }

  void _startReply(MessageDto msg) {
    if (!mounted) return;
    setState(() => _replyTo = msg);
    _inputFocus.requestFocus();
  }

  void _removeMessageLocally(String messageId) {
    final currentPages = _pagingController.value.pages;
    if (currentPages == null) return;
    _pagingController.value = _pagingController.value.copyWith(
      pages: currentPages
          .map((page) => page.where((m) => m.id != messageId).toList())
          .toList(),
    );
    if (_replyTo?.id == messageId) {
      setState(() => _replyTo = null);
    }
  }

  void _restoreMessageLocally(MessageDto msg) {
    final currentPages = _pagingController.value.pages;
    if (currentPages == null) return;

    final alreadyPresent =
        currentPages.any((page) => page.any((m) => m.id == msg.id));
    if (alreadyPresent) return;

    final firstPage =
        currentPages.isNotEmpty ? [msg, ...currentPages.first] : [msg];
    _pagingController.value = _pagingController.value.copyWith(
      pages: [firstPage, ...currentPages.skip(1)],
    );
  }

  Future<void> _deleteMessageForEveryone(MessageDto msg) async {
    try {
      await ref.read(messageRepositoryProvider).deleteMessage(msg.id);
      _removeMessageLocally(msg.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec suppression: $e')),
      );
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    debugPrint(
      '[ChatScreen._pickAndSendImage] source=${source.name} '
      'conversationId=$_conversationId expired=$_expired '
      'isSending=$_isSending uploadProgress=$_uploadProgress',
    );
    if (_expired ||
        _conversationId == null ||
        _isSending ||
        _uploadProgress != null) return;
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final picked = await picker.pickMultiImage(imageQuality: 85);
        if (picked.isEmpty || !mounted) return;
        _showMediaPreview(picked);
      } else {
        final picked = await picker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
        if (picked == null || !mounted) return;
        _showMediaPreview([picked]);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec: $e')),
      );
    }
  }

  /// Show the image preview/caption sheet before uploading.
  void _showMediaPreview(List<XFile> files) {
    debugPrint('[ChatScreen._showMediaPreview] files=${files.length}');
    if (!mounted) return;
    final screenHeight = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: screenHeight,
        child: MediaPreviewSheet(
          initialFiles: files,
          onSend: (f, caption) => _uploadImagesWithCaption(f, caption),
        ),
      ),
    );
  }

  /// Upload [files] one by one. The caption is attached to the last image
  /// message so image + text arrive as a single message (like WhatsApp).
  void _uploadImagesWithCaption(List<XFile> files, String caption) {
    debugPrint(
      '[ChatScreen._uploadImagesWithCaption] files=${files.length} '
      'caption="${caption.isEmpty ? '' : caption}" conversationId=$_conversationId',
    );
    Future(() async {
      final total = files.length;
      for (int i = 0; i < total; i++) {
        final label = total > 1 ? 'Image ${i + 1}/$total' : 'Envoi image';
        final path = files[i].path;
        final isLast = i == total - 1;
        await _runMediaUpload(
          label: label,
          upload: (_) => ref.read(chatServiceProvider).sendMediaFile(
                conversationId: _conversationId!,
                filePath: path,
                mediaType: 'image',
                caption: isLast ? caption : '',
              ),
          retry: () => _sendImagePath(path),
        );
      }
    });
  }

  Future<void> _sendImagePath(String path) async {
    final file = File(path);
    final exists = await file.exists();
    final size = exists ? await file.length() : -1;
    debugPrint(
      '[ChatScreen._sendImagePath] conversationId=$_conversationId '
      'path=$path exists=$exists size=$size',
    );
    await _runMediaUpload(
      label: 'Envoi image',
      upload: (_) => ref.read(chatServiceProvider).sendMediaFile(
            conversationId: _conversationId!,
            filePath: path,
            mediaType: 'image',
          ),
      retry: () => _sendImagePath(path),
    );
  }

  Future<void> _pickAndSendFile() async {
    if (_expired ||
        _conversationId == null ||
        _isSending ||
        _uploadProgress != null) return;
    try {
      debugPrint(
        '[ChatScreen._pickAndSendFile] conversationId=$_conversationId '
        'expired=$_expired isSending=$_isSending uploadProgress=$_uploadProgress',
      );
      // withData: true ensures bytes are loaded even for content URIs
      // (Google Drive, OneDrive, etc.) where .path would be null
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      final path = picked.path;
      debugPrint(
        '[ChatScreen._pickAndSendFile] path=$path '
        'name=${picked.name} size=${picked.size} hasBytes=${bytes != null}',
      );

      const maxBytes = 25 * 1024 * 1024; // 25 MB

      if (bytes != null) {
        // Bytes loaded in memory — send directly (works for cloud storage too)
        if (bytes.length > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Fichier trop volumineux (max 25 Mo)')),
          );
          return;
        }
        await _runMediaUpload(
          label: 'Envoi fichier',
          upload: (_) => ref.read(chatServiceProvider).sendMediaBytes(
                conversationId: _conversationId!,
                bytes: bytes,
                mediaType: 'file',
                filename: picked.name,
              ),
          retry: () async {},
        );
      } else if (path != null && path.isNotEmpty) {
        // Fallback: path available — check size then send by path
        if (picked.size > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Fichier trop volumineux (max 25 Mo)')),
          );
          return;
        }
        await _sendFilePath(path);
      } else {
        // No bytes and no path — should not happen with withData: true
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lire ce fichier')),
        );
      }
    } catch (e, st) {
      debugPrint('[ChatScreen._pickAndSendFile] ERROR: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec envoi fichier: $e')),
      );
    }
  }

  Future<void> _sendFilePath(String path) async {
    final file = File(path);
    final exists = await file.exists();
    final size = exists ? await file.length() : -1;
    debugPrint(
      '[ChatScreen._sendFilePath] conversationId=$_conversationId '
      'path=$path exists=$exists size=$size',
    );
    await _runMediaUpload(
      label: 'Envoi fichier',
      upload: (_) => ref.read(chatServiceProvider).sendMediaFile(
            conversationId: _conversationId!,
            filePath: path,
            mediaType: 'file',
          ),
      retry: () => _sendFilePath(path),
    );
  }

  Future<void> _toggleAudioRecording() async {
    if (_expired || _conversationId == null || _isSending) return;

    try {
      debugPrint(
        '[ChatScreen._toggleAudioRecording] isRecording=$_isRecordingAudio '
        'conversationId=$_conversationId expired=$_expired isSending=$_isSending '
        'uploadProgress=$_uploadProgress',
      );
      if (_isRecordingAudio) {
        final filePath = await _recorderService.stopRecording();
        debugPrint('[ChatScreen._toggleAudioRecording] stop path=$filePath');
        setState(() => _isRecordingAudio = false);
        if (filePath == null || filePath.isEmpty) return;
        if (!await File(filePath).exists()) return;
        await _sendAudioPath(filePath);
        return;
      }

      if (_uploadProgress != null) return;

      if (!await _recorderService.requestPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission micro refusee')),
        );
        return;
      }

      debugPrint('[ChatScreen._toggleAudioRecording] start recording...');
      await _recorderService.startRecording();
      setState(() => _isRecordingAudio = true);
    } catch (e, st) {
      debugPrint('[ChatScreen._toggleAudioRecording] ERROR: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() => _isRecordingAudio = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec audio: $e')),
      );
    }
  }

  Future<void> _sendAudioPath(String path) async {
    final file = File(path);
    final exists = await file.exists();
    final size = exists ? await file.length() : -1;
    debugPrint(
      '[ChatScreen._sendAudioPath] conversationId=$_conversationId '
      'path=$path exists=$exists size=$size',
    );
    await _runMediaUpload(
      label: 'Envoi audio',
      upload: (_) => ref.read(chatServiceProvider).sendMediaFile(
            conversationId: _conversationId!,
            filePath: path,
            mediaType: 'audio',
          ),
      retry: () => _sendAudioPath(path),
    );
  }

  Future<void> _runMediaUpload({
    required String label,
    required Future<void> Function(
            void Function(int sent, int total) onProgress)
        upload,
    required Future<void> Function() retry,
  }) async {
    if (!mounted) return;
    debugPrint(
        '[ChatScreen._runMediaUpload] start label=$label conversationId=$_conversationId');
    setState(() {
      _uploadLabel = label;
      // -1 = uploading but no progress estimate (socket transport)
      _uploadProgress = -1;
    });

    try {
      await upload((sent, total) {
        if (!mounted) return;
        final value = total <= 0 ? 0.0 : sent / total;
        debugPrint(
          '[ChatScreen._runMediaUpload] progress label=$label '
          'sent=$sent total=$total value=$value',
        );
        setState(() => _uploadProgress = value.clamp(0, 1));
      });
      debugPrint('[ChatScreen._runMediaUpload] success label=$label');
    } catch (e, st) {
      debugPrint('[ChatScreen._runMediaUpload] ERROR label=$label error=$e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Echec upload: $e'),
          action: SnackBarAction(
            label: 'Reessayer',
            onPressed: () {
              retry();
            },
          ),
        ),
      );
    } finally {
      debugPrint(
          '[ChatScreen._runMediaUpload] finally label=$label mounted=$mounted');
      if (mounted) {
        setState(() {
          _uploadLabel = null;
          _uploadProgress = null;
        });
      }
    }
  }

  void _openMediaMenu() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Image depuis galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Fichier'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hideMessageForMe(MessageDto msg) async {
    _removeMessageLocally(msg.id);

    try {
      await ref.read(messageRepositoryProvider).hideMessageForMe(msg.id);
    } catch (e) {
      _restoreMessageLocally(msg);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echec masquage: $e')),
      );
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Message masque'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () {},
            ),
          ),
        )
        .closed;

    if (reason == SnackBarClosedReason.action) {
      try {
        await ref.read(messageRepositoryProvider).unhideMessageForMe(msg.id);
        if (mounted) {
          _restoreMessageLocally(msg);
        }
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Echec restauration: $e')),
        );
      }
    }
  }

  void _openMessageOptions(MessageDto msg) {
    final isSelf = msg.isSelf(ref.read(authProvider).userId ?? '');
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Repondre'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Masquer pour moi'),
                onTap: () {
                  Navigator.pop(ctx);
                  _hideMessageForMe(msg);
                },
              ),
              if (isSelf)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Supprimer pour tous'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessageForEveryone(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Date helpers --

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return "Aujourd'hui";
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    _pagingController.dispose();
    _countdownTimer?.cancel();
    _typingTimer?.cancel();
    _localTypingTimer?.cancel();
    _highlightTimer?.cancel();
    _recorderService.dispose();
    _disposeSocketListeners();
    if (_conversationId != null) {
      final socket = ref.read(socketServiceProvider);
      socket.leaveConversation(_conversationId!);
    }
    super.dispose();
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final conv = _conversation;
    if (conv == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              RepaintBoundary(
                child: ChatHeader(
                  topPadding: mq.padding.top,
                  peerPseudo: _conversation
                          ?.peerPseudo(ref.read(authProvider).userId ?? '') ??
                      'Anonyme',
                  identityRevealed: _identityRevealed,
                  isTyping: _isTyping,
                  isOnline: _isOtherOnline,
                  formattedRemaining: _formatRemaining(),
                  onBack: () => Navigator.pop(context),
                  onMenu: _showMenu,
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF3E8FF)],
                      stops: [0.55, 1.0],
                    ),
                  ),
                  child: _isLocked
                      ? Stack(
                          children: [
                            _buildPagedMessageList(),
                            Positioned.fill(
                              child: ChatLockOverlay(
                                onUnlock: _handleSingleUnlock,
                              ),
                            ),
                          ],
                        )
                      : _buildPagedMessageList(),
                ),
              ),
              if (!_expired && !_isLocked)
                RepaintBoundary(
                  child: ChatInputBar(
                    bottomPadding: mq.padding.bottom,
                    controller: _input,
                    focusNode: _inputFocus,
                    expired: _expired,
                    isSending: _isSending,
                    isRecordingAudio: _isRecordingAudio,
                    recorderController: _recorderService.controller,
                    uploadProgress: _uploadProgress,
                    uploadLabel: _uploadLabel,
                    replyTo: _replyTo,
                    onSend: _send,
                    onMediaMenu: _openMediaMenu,
                    onToggleAudio: _toggleAudioRecording,
                    onInputChanged: _onInputChanged,
                    onClearReply: () => setState(() => _replyTo = null),
                    replyPreviewText:
                        _replyTo != null ? _replyPreview(_replyTo!) : '',
                  ),
                ),
            ],
          ),
          if (_showSearch)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChatSearchBar(
                conversationId: _conversationId!,
                messageRepository: ref.read(messageRepositoryProvider),
                onResultTap: (msg) {
                  setState(() => _showSearch = false);
                  _jumpToOriginalMessage(msg.id);
                },
                onClose: () => setState(() => _showSearch = false),
              ),
            ),
        ],
      ),
    );
  }

  // -- Messages (paginated + reversed) --

  Widget _buildPagedMessageList() {
    return PagingListener<int, MessageDto>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) {
        // Deduplicate: socket events can prepend messages already in fetched pages.
        final rawItems = state.items ?? [];
        final seen = <String>{};
        final allItems = <MessageDto>[];
        for (final m in rawItems) {
          if (seen.add(m.id)) allItems.add(m);
        }
        return PagedListView<int, MessageDto>(
          state: state,
          fetchNextPage: fetchNextPage,
          scrollController: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          builderDelegate: PagedChildBuilderDelegate<MessageDto>(
            noItemsFoundIndicatorBuilder: (_) => Center(
              child: Text(
                _expired ? 'Cette conversation a expire.' : 'Dites bonjour...',
                style: TextStyle(
                  color: _expired
                      ? AppColors.textSecondary
                      : AppColors.textDisabled,
                  fontSize: 14,
                ),
              ),
            ),
            firstPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            newPageProgressIndicatorBuilder: (_) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            itemBuilder: (context, msg, index) {
              Widget? separator;
              final dateStr = _formatDate(msg.createdAt);
              if (index == allItems.length - 1) {
                separator = _buildDateSeparator(dateStr);
              } else if (index + 1 < allItems.length) {
                final nextMsg = allItems[index + 1];
                final nextDateStr = _formatDate(nextMsg.createdAt);
                if (dateStr != nextDateStr) {
                  separator = _buildDateSeparator(dateStr);
                }
              }

              final messageKey =
                  _messageKeys.putIfAbsent(msg.id, GlobalKey.new);

              return Column(
                children: [
                  if (separator != null) separator,
                  Padding(
                    key: messageKey,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ChatBubble(
                      message: msg.content,
                      isSelf: msg.isSelf(ref.read(authProvider).userId ?? ''),
                      isHighlighted: _highlightedMessageId == msg.id,
                      isRead: msg.isRead,
                      timestamp: msg.formattedTime,
                      mediaUrl: msg.mediaUrl,
                      mediaType: msg.mediaType,
                      replyToContent: msg.replyToContent,
                      onReplyTap: msg.replyToMessageId == null
                          ? null
                          : () => _jumpToOriginalMessage(msg.replyToMessageId),
                      onLongPress: () => _startReply(msg),
                      onOptionsTap: () => _openMessageOptions(msg),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primaryEnd.withOpacity(0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primaryEnd.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}
