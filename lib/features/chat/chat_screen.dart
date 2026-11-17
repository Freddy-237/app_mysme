import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mysme/core/config/monetization.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/core/utils/helpers.dart';
import 'package:mysme/features/chat/chat_send_error.dart';
import 'package:mysme/features/chat/chat_send_guard.dart';
import 'package:mysme/features/chat/widgets/chat_header.dart';
import 'package:mysme/features/chat/widgets/chat_input_bar.dart';
import 'package:mysme/features/chat/widgets/chat_lock_overlay.dart';
import 'package:mysme/features/chat/widgets/chat_message_list.dart';
import 'package:mysme/features/chat/widgets/chat_search_bar.dart';
import 'package:mysme/features/chat/media_gallery_screen.dart';
import 'package:mysme/features/chat/widgets/media_preview_sheet.dart';
import 'package:mysme/features/chat/widgets/menu_button.dart';

part 'chat_screen_core.dart';
part 'chat_screen_media.dart';

void _chatLog(String message) {
  debugPrint(message);
}

/// Full-screen ephemeral chat view.
///
/// The screen keeps layout and state orchestration here, while socket logic,
/// actions, and media workflows are split into dedicated part files.
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
  bool _conversationLoadFailed = false;
  Timer? _countdownTimer;
  Timer? _typingTimer;
  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _identityRevealed = false;
  String? _trustLevel = 'anonymous';
  bool _isTyping = false; // other person is typing
  bool _isOtherOnline = false;
  bool _isSending = false;
  bool _socketSetup = false;
  SocketService? _socketService;
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
  DateTime? _lastSentAt;
  String? _lastSentContent;
  bool _isSendCoolingDown = false;
  Timer? _localTypingTimer;
  Timer? _sendCooldownTimer;
  bool _hasReportedConversation = false;
  final Map<String, MessageDto> _pendingRealtimeMessages =
      <String, MessageDto>{};
  final Set<String> _pendingRemovedMessageIds = <String>{};
  bool _markOwnMessagesRead = false;
  bool _applyingPagingOverlay = false;

  /// Conversation locking is controlled centrally by monetization flags.
  bool get _isLocked {
    if (!kConversationExpiryEnabled) return false;
    if (_conversation == null) return false;
    return _conversation!.isExpired;
  }

  bool get _isInteractionRestricted => _isLocked || _expired;

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
    _pagingController.addListener(_applyPagingOverlay);
    _loadConversation();
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    _pagingController.removeListener(_applyPagingOverlay);
    _pagingController.dispose();
    _countdownTimer?.cancel();
    _typingTimer?.cancel();
    _localTypingTimer?.cancel();
    _highlightTimer?.cancel();
    _sendCooldownTimer?.cancel();
    _recorderService.dispose();
    _disposeSocketListeners();
    final socket = _socketService;
    if (_conversationId != null && socket != null) {
      socket.leaveConversation(_conversationId!);
    }
    super.dispose();
  }

  // -- Build --

  @override
  Widget build(BuildContext context) {
    final conv = _conversation;
    if (conv == null) {
      if (_conversationLoadFailed) {
        return Scaffold(
          appBar: AppBar(title: const Text('Discussion')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Impossible de charger cette discussion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vérifie ta connexion puis réessaie.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadConversation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mq = MediaQuery.of(context);
    final authUserId = ref.read(authProvider).userId ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              RepaintBoundary(
                child: ChatHeader(
                  topPadding: mq.padding.top,
                  peerPseudo:
                      _conversation?.peerPseudo(authUserId) ?? 'Anonyme',
                  identityRevealed: _identityRevealed,
                  trustLevel: _trustLevel,
                  isTyping: _isTyping,
                  isOnline: _isOtherOnline,
                  formattedRemaining: _formatRemaining(),
                  onBack: () => Navigator.pop(context),
                  onTrustTap: _showTrustInfo,
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
                            ChatMessageList(
                              pagingController: _pagingController,
                              scrollController: _scroll,
                              expired: _expired,
                              authUserId: authUserId,
                              messageKeys: _messageKeys,
                              highlightedMessageId: _highlightedMessageId,
                              onReplyTap: _jumpToOriginalMessage,
                              onLongPress: _startReply,
                              onOptionsTap: _openMessageOptions,
                            ),
                            Positioned.fill(
                              child: ChatLockOverlay(
                                onUnlock: _handleSingleUnlock,
                              ),
                            ),
                          ],
                        )
                      : ChatMessageList(
                          pagingController: _pagingController,
                          scrollController: _scroll,
                          expired: _expired,
                          authUserId: authUserId,
                          messageKeys: _messageKeys,
                          highlightedMessageId: _highlightedMessageId,
                          onReplyTap: _jumpToOriginalMessage,
                          onLongPress: _startReply,
                          onOptionsTap: _openMessageOptions,
                        ),
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
                    sendLocked: _isSendCoolingDown,
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
}
