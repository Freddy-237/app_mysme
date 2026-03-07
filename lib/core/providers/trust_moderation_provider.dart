import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';

// ---------------------------------------------------------------------------
// Trust DTO
// ---------------------------------------------------------------------------

class TrustDto {
  const TrustDto({
    required this.id,
    required this.conversationId,
    required this.level,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String level; // 'anonymous' | 'partial' | 'revealed'
  final DateTime updatedAt;

  factory TrustDto.fromJson(Map<String, dynamic> json) {
    return TrustDto(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      level:
          json['level'] as String? ?? json['status'] as String? ?? 'anonymous',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Trust repository
// ---------------------------------------------------------------------------

class TrustRepository {
  TrustRepository(this._client);
  final HttpClient _client;

  /// Get trust level for a conversation.
  Future<TrustDto> getTrust(String conversationId) async {
    final json = await _client.get('/trust/$conversationId');
    return TrustDto.fromJson(json as Map<String, dynamic>);
  }

  /// Upgrade trust level. Optionally jump to [targetStatus] directly.
  Future<TrustDto> upgradeTrust(String conversationId,
      {String? targetStatus}) async {
    final json = await _client.post('/trust/$conversationId/upgrade', {
      if (targetStatus != null) 'targetStatus': targetStatus,
    });
    return TrustDto.fromJson(json as Map<String, dynamic>);
  }
}

// ---------------------------------------------------------------------------
// Moderation repository
// ---------------------------------------------------------------------------

class ModerationRepository {
  ModerationRepository(this._client);
  final HttpClient _client;

  /// Report a conversation/message.
  Future<void> report({
    required String conversationId,
    String? messageId,
    String? reason,
  }) async {
    await _client.post('/moderation/report', {
      'conversationId': conversationId,
      if (messageId != null) 'messageId': messageId,
      if (reason != null) 'reason': reason,
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepository(ref.watch(httpClientProvider));
});

/// Trust level per conversation (family).
final trustProvider =
    FutureProvider.family<TrustDto, String>((ref, conversationId) async {
  final repo = ref.watch(trustRepositoryProvider);
  return repo.getTrust(conversationId);
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(httpClientProvider));
});
