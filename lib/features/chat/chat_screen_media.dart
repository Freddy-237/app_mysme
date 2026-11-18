// ignore_for_file: invalid_use_of_protected_member

part of 'chat_screen.dart';

extension _ChatScreenMedia on _ChatScreenState {
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

  Future<void> _pickAndSendImage(ImageSource source) async {
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
        _showMediaPreview(<XFile>[picked]);
      }
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible d\'ouvrir ce média pour le moment.',
      );
    }
  }

  void _showMediaPreview(List<XFile> files) {
    if (!mounted) return;
    final screenHeight = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => SizedBox(
        height: screenHeight,
        child: MediaPreviewSheet(
          initialFiles: files,
          onSend: (f, caption) => _uploadImagesWithCaption(f, caption),
        ),
      ),
    );
  }

  void _uploadImagesWithCaption(List<XFile> files, String caption) {
    Future<void>(() async {
      final total = files.length;
      for (int i = 0; i < total; i++) {
        final path = files[i].path;
        final isLast = i == total - 1;
        await _sendMediaAction(
          actionSignature: 'image:$path',
          label: total > 1 ? 'Image ${i + 1}/$total' : 'Envoi image',
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
    await _sendMediaAction(
      actionSignature: 'image:$path',
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
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      final path = picked.path;

      const maxBytes = 25 * 1024 * 1024;
      if (bytes != null) {
        if (bytes.length > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Fichier trop volumineux (max 25 Mo)')),
          );
          return;
        }
        await _sendMediaAction(
          actionSignature: 'file:${picked.name}:${bytes.length}',
          label: 'Envoi fichier',
          upload: (_) => ref.read(chatServiceProvider).sendMediaBytes(
                conversationId: _conversationId!,
                bytes: bytes,
                mediaType: 'file',
                filename: picked.name,
              ),
          retry: () async {},
        );
        return;
      }

      if (path != null && path.isNotEmpty) {
        if (picked.size > maxBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Fichier trop volumineux (max 25 Mo)')),
          );
          return;
        }
        await _sendFilePath(path);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lire ce fichier')),
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible d\'envoyer ce fichier pour le moment.',
      );
    }
  }

  Future<void> _sendFilePath(String path) async {
    await _sendMediaAction(
      actionSignature: 'file:$path',
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
      if (_isRecordingAudio) {
        final filePath = await _recorderService.stopRecording();
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

      await _recorderService.startRecording();
      setState(() => _isRecordingAudio = true);
    } catch (e) {
      if (mounted) setState(() => _isRecordingAudio = false);
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible d\'envoyer cet audio pour le moment.',
      );
    }
  }

  Future<void> _sendAudioPath(String path) async {
    await _sendMediaAction(
      actionSignature: 'audio:$path',
      label: 'Envoi audio',
      upload: (_) => ref.read(chatServiceProvider).sendMediaFile(
            conversationId: _conversationId!,
            filePath: path,
            mediaType: 'audio',
          ),
      retry: () => _sendAudioPath(path),
    );
  }

  Future<void> _sendMediaAction({
    required String actionSignature,
    required String label,
    required Future<void> Function(
            void Function(int sent, int total) onProgress)
        upload,
    required Future<void> Function() retry,
  }) async {
    if (_conversationId == null || _isInteractionRestricted || _isSending) {
      return;
    }

    final now = DateTime.now();
    final guardError = ChatSendGuard.validateAction(
      actionSignature: actionSignature,
      now: now,
      lastSentAt: _lastSentAt,
      lastSentContent: _lastSentContent,
    );
    if (guardError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(guardError)));
      return;
    }

    if (!mounted) return;
    setState(() {
      _uploadLabel = label;
      _uploadProgress = -1;
      _lastSentAt = now;
      _lastSentContent = actionSignature;
    });

    _armSendCooldown();

    try {
      await upload((sent, total) {
        if (!mounted) return;
        final value = total <= 0 ? 0.0 : sent / total;
        setState(() => _uploadProgress = value.clamp(0, 1));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Helpers.friendlyErrorMessage(
              e,
              fallback: 'Impossible d\'envoyer ce média pour le moment.',
            ),
          ),
          action: SnackBarAction(
            label: 'Reessayer',
            onPressed: () {
              retry();
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadLabel = null;
          _uploadProgress = null;
        });
      }
    }
  }
}
