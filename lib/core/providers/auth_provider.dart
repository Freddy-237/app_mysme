import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/services/push_notification_service.dart';
import 'package:mysme/core/utils/helpers.dart';

void _authLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Sentinel to distinguish "not passed" from "explicitly null".
const _absent = Object();

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
    this.email,
    this.emailVerifiedAt,
    this.systemWarningMessage,
    this.notificationsEnabled = true,
    this.isLoading = false,
    this.sessionLost = false,
    this.error,
  });

  final String? userId;
  final String? pseudo;
  final String? avatarSeed;
  final String? bio;
  final String? email;
  final DateTime? emailVerifiedAt;
  final String? systemWarningMessage;
  final bool notificationsEnabled;
  final bool isLoading;
  final bool sessionLost;
  final String? error;

  bool get isAuthenticated => userId != null;
  bool get isEmailVerified => emailVerifiedAt != null;

  AuthState copyWith({
    Object? userId = _absent,
    Object? pseudo = _absent,
    Object? avatarSeed = _absent,
    Object? bio = _absent,
    Object? email = _absent,
    Object? emailVerifiedAt = _absent,
    Object? systemWarningMessage = _absent,
    bool? notificationsEnabled,
    bool? isLoading,
    bool? sessionLost,
    String? error,
  }) {
    return AuthState(
      userId: userId == _absent ? this.userId : userId as String?,
      pseudo: pseudo == _absent ? this.pseudo : pseudo as String?,
      avatarSeed:
          avatarSeed == _absent ? this.avatarSeed : avatarSeed as String?,
      bio: bio == _absent ? this.bio : bio as String?,
      email: email == _absent ? this.email : email as String?,
      emailVerifiedAt: emailVerifiedAt == _absent
          ? this.emailVerifiedAt
          : emailVerifiedAt as DateTime?,
      systemWarningMessage: systemWarningMessage == _absent
          ? this.systemWarningMessage
          : systemWarningMessage as String?,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isLoading: isLoading ?? this.isLoading,
      sessionLost: sessionLost ?? this.sessionLost,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._client) : super(const AuthState()) {
    // Token rejected mid-session → expose it so the app opens recovery
    // instead of silently creating a new identity.
    _client.onSessionLost = () {
      state = const AuthState(
        sessionLost: true,
        error:
            'Session perdue. Restaurez votre compte ou créez une nouvelle identité.',
      );
    };
  }

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

  Future<void> _hydrateCurrentUser() async {
    final me = await _client.get('/identity/me');
    final pseudo = me['pseudo'] as String?;
    final notificationsEnabled = me['notifications_enabled'] as bool? ?? true;
    state = AuthState(
      userId: me['id'] as String,
      pseudo: pseudo,
      avatarSeed: _extractSeed(me['avatar_url'] as String?, pseudo),
      bio: (me['bio'] as String?) ?? '',
      email: me['email'] as String?,
      emailVerifiedAt: DateTime.tryParse(
        (me['email_verified_at'] as String?) ?? '',
      ),
      systemWarningMessage: me['system_warning_message'] as String?,
      notificationsEnabled: notificationsEnabled,
      sessionLost: false,
    );

    await PushNotificationService.applyUserPreference(
      _client,
      enabled: notificationsEnabled,
    );
  }

  /// Bootstrap: init the HTTP client (loads/creates identity), then set state.
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null, sessionLost: false);
    try {
      await _client.init();
      if (_client.isReady) {
        await _hydrateCurrentUser();
      } else {
        state =
            state.copyWith(isLoading: false, error: 'Initialisation échouée');
      }
    } on SessionLostException catch (e) {
      state = AuthState(
        isLoading: false,
        sessionLost: true,
        error: e.message,
      );
    } catch (e) {
      final message = Helpers.friendlyErrorMessage(
        e,
        fallback: 'Impossible d\'initialiser l\'application pour le moment.',
      );
      if (_client.hasStoredSession) {
        // Offline / server down: keep the user logged in with their stored
        // identity; data will refresh when the network is back.
        state = AuthState(
          userId: _client.userId,
          isLoading: false,
          error: message,
        );
      } else {
        state = state.copyWith(isLoading: false, error: message);
      }
    }
  }

  Future<void> createAnonymousIdentity() async {
    state = state.copyWith(isLoading: true, error: null, sessionLost: false);
    try {
      await _client.createAnonymousIdentity();
      await _hydrateCurrentUser();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de créer une nouvelle identité pour le moment.',
        ),
      );
    }
  }

  /// Refresh current user data from the backend.
  Future<void> refreshMe() async {
    try {
      await _hydrateCurrentUser();
    } catch (e) {
      _authLog('[AuthNotifier.refreshMe] ERROR: $e');
      state = state.copyWith(
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de récupérer les informations du compte.',
        ),
      );
    }
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

  /// Regenerate pseudo + avatar server-side.
  Future<void> regenerateIdentity() async {
    final res = await _client.patch('/identity/pseudo', {});
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

  /// Update the server-backed notification preference.
  Future<void> updateNotificationPreference(bool enabled) async {
    final res = await _client.patch('/identity/notifications', {
      'enabled': enabled,
    });
    final notificationsEnabled =
        res['notifications_enabled'] as bool? ?? enabled;
    state = state.copyWith(notificationsEnabled: notificationsEnabled);
    await PushNotificationService.applyUserPreference(
      _client,
      enabled: notificationsEnabled,
    );
  }

  /// Sign out — clear token + reset state.
  Future<void> signOut() async {
    await _client.clearSession();
    state = const AuthState();
  }

  /// Permanently delete the account on the server, then forget it locally.
  /// Throws if the server did not confirm: nothing is wiped in that case.
  Future<void> deleteAccount() async {
    await _client.delete('/identity/me');
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

  /// Restore session from a recovery key.
  Future<void> restoreWithRecoveryKey(String recoveryKey) async {
    await _client.restoreWithRecoveryKey(recoveryKey);
    await refreshMe();
  }

  /// Request OTP for email-based restore (unauthenticated).
  Future<Map<String, dynamic>> requestEmailRestore(String email) async {
    return _client.requestEmailRestore(email);
  }

  /// Verify OTP and restore account by email (unauthenticated).
  Future<void> verifyEmailRestore(String email, String code) async {
    await _client.verifyEmailRestore(email, code);
    await refreshMe();
  }

  /// Request OTP code to link an email to this anonymous account.
  Future<void> requestEmailOtp(String email) async {
    await _client.post('/identity/email/request-otp', {
      'email': email,
    });
  }

  /// Verify OTP code.  Caller is responsible for calling [refreshMe]
  /// after the UI (e.g. dialog) has been dismissed.
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    await _client.post('/identity/email/verify-otp', {
      'email': email,
      'code': code,
    });
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(httpClientProvider));
});
