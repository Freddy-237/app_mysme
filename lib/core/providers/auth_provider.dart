import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/services/push_notification_service.dart';

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

/// Represents the current authentication state.
class AuthState {
  const AuthState({
    this.userId,
    this.pseudo,
    this.avatarSeed,
    this.bio,
    this.isLoading = false,
    this.error,
  });

  final String? userId;
  final String? pseudo;
  final String? avatarSeed;
  final String? bio;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => userId != null;

  AuthState copyWith({
    String? userId,
    String? pseudo,
    String? avatarSeed,
    String? bio,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      pseudo: pseudo ?? this.pseudo,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      bio: bio ?? this.bio,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client) : super(const AuthState());

  final HttpClient _client;

  /// Extract seed from a DiceBear avatar URL, e.g.
  /// `https://api.dicebear.com/7.x/bottts/svg?seed=Fox` → `Fox`.
  /// Returns [fallback] if parsing fails.
  static String _extractSeed(String? avatarUrl, String? fallback) {
    if (avatarUrl != null && avatarUrl.contains('seed=')) {
      final uri = Uri.tryParse(avatarUrl);
      if (uri != null) {
        final seed = uri.queryParameters['seed'];
        if (seed != null && seed.isNotEmpty) return seed;
      }
    }
    return fallback ?? 'default';
  }

  /// Bootstrap: init the HTTP client (loads/creates identity), then set state.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.init();

      // _client.init() already called /identity/me or /identity/init.
      // Reuse the client's userId instead of making a redundant HTTP call.
      if (_client.isReady) {
        // One single call to get full profile data.
        final me = await _client.get('/identity/me');
        final pseudo = me['pseudo'] as String?;
        state = AuthState(
          userId: me['id'] as String,
          pseudo: pseudo,
          avatarSeed: _extractSeed(me['avatar_url'] as String?, pseudo),
          bio: (me['bio'] as String?) ?? '',
        );

        await PushNotificationService.syncToken(_client);
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Initialisation échouée');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh current user data from the backend.
  Future<void> refreshMe() async {
    try {
      final me = await _client.get('/identity/me');
      final pseudo = me['pseudo'] as String?;
      state = state.copyWith(
        userId: me['id'] as String,
        pseudo: pseudo,
        avatarSeed: _extractSeed(me['avatar_url'] as String?, pseudo),
        bio: (me['bio'] as String?) ?? '',
      );
    } catch (_) {}
  }

  /// Update the user pseudo on the backend.
  Future<void> updatePseudo(String pseudo) async {
    final res = await _client.patch('/identity/pseudo', {'pseudo': pseudo});
    final newPseudo = res['pseudo'] as String?;
    state = state.copyWith(
      pseudo: newPseudo,
      avatarSeed: _extractSeed(res['avatar_url'] as String?, newPseudo),
    );
  }

  /// Update the user bio on the backend.
  Future<void> updateBio(String bio) async {
    final res = await _client.patch('/identity/bio', {'bio': bio});
    state = state.copyWith(bio: (res['bio'] as String?) ?? '');
  }

  /// Sign out — clear token + reset state.
  Future<void> signOut() async {
    await _client.clearSession();
    state = const AuthState();
  }

  /// Generate a recovery key that can restore this account on another device.
  Future<String> generateRecoveryKey() async {
    final res = await _client.post('/identity/recovery-key', {});
    final key = res['recoveryKey'] as String?;
    if (key == null || key.isEmpty) {
      throw ApiException('Clé de récupération indisponible', 500);
    }
    return key;
  }

  /// Restore session from a recovery key and refresh auth state.
  Future<void> restoreWithRecoveryKey(String recoveryKey) async {
    await _client.restoreWithRecoveryKey(recoveryKey);
    await refreshMe();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(httpClientProvider));
});
