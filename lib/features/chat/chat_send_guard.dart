class ChatSendGuard {
  static const int maxMessageLength = 1000;
  static const Duration minInterval = Duration(milliseconds: 800);
  static const Duration duplicateWindow = Duration(seconds: 8);

  static String? validate({
    required String rawText,
    required DateTime now,
    DateTime? lastSentAt,
    String? lastSentContent,
  }) {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    if (text.length > maxMessageLength) {
      return 'Message trop long (${text.length}/$maxMessageLength caractères)';
    }

    if (lastSentAt != null &&
        lastSentContent != null &&
        text == lastSentContent &&
        now.difference(lastSentAt) < duplicateWindow) {
      return 'Message déjà envoyé il y a un instant';
    }

    if (lastSentAt != null && now.difference(lastSentAt) < minInterval) {
      return 'Tu envoies trop vite';
    }

    return null;
  }

  static String? validateAction({
    required String actionSignature,
    required DateTime now,
    DateTime? lastSentAt,
    String? lastSentContent,
  }) {
    final signature = actionSignature.trim();
    if (signature.isEmpty) return null;

    if (lastSentAt != null && now.difference(lastSentAt) < minInterval) {
      return 'Tu envoies trop vite';
    }

    if (lastSentAt != null &&
        lastSentContent != null &&
        signature == lastSentContent &&
        now.difference(lastSentAt) < duplicateWindow) {
      return 'Envoi déjà lancé il y a un instant';
    }

    return null;
  }
}
