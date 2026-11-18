import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/utils/helpers.dart';

void _linkLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

const _defaultPwaBase = 'https://www.myst-me.com';

// Optional override:
// flutter run --dart-define=PWA_BASE_URL=https://your-domain.com
const _pwaBase = String.fromEnvironment(
  'PWA_BASE_URL',
  defaultValue: _defaultPwaBase,
);

// ---------------------------------------------------------------------------
// Link model (backend row)
// ---------------------------------------------------------------------------

class LinkModel {
  const LinkModel({
    required this.id,
    required this.code,
    required this.ownerId,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String ownerId;
  final bool isActive;
  final DateTime createdAt;

  factory LinkModel.fromJson(Map<String, dynamic> json) {
    final model = LinkModel(
      id: json['id'] as String,
      code: json['code'] as String,
      ownerId: json['owner_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
    _linkLog('[LinkModel.fromJson] id=${model.id} active=${model.isActive}');
    return model;
  }

  /// PWA display URL (shown in card — clean label).
  String get displayLink {
    final host = Uri.tryParse(_pwaBase)?.host;
    if (host == null || host.isEmpty) {
      return 'www.myst-me.com/c/$code';
    }
    return '$host/c/$code';
  }

  /// Full shareable URL. [name] is URL-encoded display name.
  String shareUrl(String name) {
    final encoded = Uri.encodeComponent(name);
    final url = '$_pwaBase/c/$code?name=$encoded';
    _linkLog('[LinkModel.shareUrl] code=$code');
    return url;
  }
}

// ---------------------------------------------------------------------------
// Link repository
// ---------------------------------------------------------------------------

class LinkRepository {
  LinkRepository(this._client);
  final HttpClient _client;

  /// Create a new shareable link.
  Future<LinkModel> createLink() async {
    _linkLog('[LinkRepository.createLink] POST /link');
    final json = await _client.post('/link', {});
    return LinkModel.fromJson(json as Map<String, dynamic>);
  }

  /// Get all my links.
  Future<List<LinkModel>> getMyLinks() async {
    _linkLog('[LinkRepository.getMyLinks] GET /link/mine');
    final json = await _client.get('/link/mine');
    final items = json as List;
    _linkLog('[LinkRepository.getMyLinks] count=${items.length}');
    return items.map((e) => LinkModel.fromJson(e)).toList();
  }

  /// Resolve an invite code (public endpoint).
  Future<LinkModel> getLinkByCode(String code) async {
    final json = await _client.get('/link/code/$code');
    return LinkModel.fromJson(json as Map<String, dynamic>);
  }

  /// Deactivate a link.
  Future<LinkModel> deactivateLink(String linkId) async {
    final json = await _client.delete('/link/$linkId');
    return LinkModel.fromJson(json as Map<String, dynamic>);
  }
}

// ---------------------------------------------------------------------------
// Link state
// ---------------------------------------------------------------------------

class LinkState {
  const LinkState({
    this.links = const [],
    this.isLoading = false,
    this.error,
  });

  final List<LinkModel> links;
  final bool isLoading;
  final String? error;

  /// The first active link, if any.
  LinkModel? get activeLink {
    for (final link in links) {
      if (link.isActive) {
        return link;
      }
    }
    return null;
  }

  LinkState copyWith({
    List<LinkModel>? links,
    bool? isLoading,
    String? error,
  }) {
    return LinkState(
      links: links ?? this.links,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Link Notifier
// ---------------------------------------------------------------------------

class LinkNotifier extends StateNotifier<LinkState> {
  LinkNotifier(this._repo) : super(const LinkState());

  final LinkRepository _repo;

  /// Fetch my links from the backend.
  Future<void> fetchMyLinks() async {
    _linkLog('[LinkNotifier.fetchMyLinks] START');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final links = await _repo.getMyLinks();
      _linkLog('[LinkNotifier.fetchMyLinks] OK count=${links.length}');
      state = LinkState(links: links);
    } catch (e, st) {
      _linkLog('[LinkNotifier.fetchMyLinks] ERROR: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: st);
      }
      state = state.copyWith(
        isLoading: false,
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de charger ton lien pour le moment.',
        ),
      );
    }
  }

  /// Get or create an active link.
  Future<LinkModel> getOrCreateLink() async {
    _linkLog(
        '[LinkNotifier.getOrCreateLink] START cached=${state.activeLink?.code != null}');
    if (state.activeLink != null) {
      _linkLog('[LinkNotifier.getOrCreateLink] return cached');
      return state.activeLink!;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      // Try fetching existing links first
      _linkLog('[LinkNotifier.getOrCreateLink] fetching existing');
      final links = await _repo.getMyLinks();
      _linkLog('[LinkNotifier.getOrCreateLink] fetched=${links.length}');
      if (links.isNotEmpty) {
        state = LinkState(links: links);
        final active = state.activeLink;
        if (active != null) {
          _linkLog('[LinkNotifier.getOrCreateLink] found active');
          return active;
        }
        _linkLog('[LinkNotifier.getOrCreateLink] no active link found');
      }

      // Create a new one
      _linkLog('[LinkNotifier.getOrCreateLink] creating new');
      final link = await _repo.createLink();
      _linkLog('[LinkNotifier.getOrCreateLink] created');
      state = LinkState(links: [...state.links, link]);
      return link;
    } catch (e, st) {
      _linkLog('[LinkNotifier.getOrCreateLink] ERROR: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: st);
      }
      state = state.copyWith(
        isLoading: false,
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de générer ton lien pour le moment.',
        ),
      );
      rethrow;
    }
  }

  /// Deactivate a link and remove it from local state.
  Future<void> deactivateLink(String linkId) async {
    try {
      await _repo.deactivateLink(linkId);
      state = LinkState(
        links: state.links.where((l) => l.id != linkId).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de mettre à jour le lien pour le moment.',
        ),
      );
    }
  }

  /// Force refresh.
  void invalidate() {
    state = const LinkState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final linkRepositoryProvider = Provider<LinkRepository>((ref) {
  return LinkRepository(ref.watch(httpClientProvider));
});

final linkProvider = StateNotifierProvider<LinkNotifier, LinkState>((ref) {
  return LinkNotifier(ref.watch(linkRepositoryProvider));
});
