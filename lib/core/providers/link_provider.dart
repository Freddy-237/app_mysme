import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';

const _defaultPwaBase = 'https://mystme-pwa.vercel.app';

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
    debugPrint('[LinkModel.fromJson] raw json: $json');
    final model = LinkModel(
      id: json['id'] as String,
      code: json['code'] as String,
      ownerId: json['owner_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
    debugPrint(
        '[LinkModel.fromJson] parsed → id=${model.id}, code=${model.code}, isActive=${model.isActive}');
    return model;
  }

  /// PWA display URL (shown in card — clean label).
  String get displayLink {
    final host = Uri.tryParse(_pwaBase)?.host;
    if (host == null || host.isEmpty) {
      return 'mystme-pwa.vercel.app/c/$code';
    }
    return '$host/c/$code';
  }

  /// Full shareable URL. [name] is URL-encoded display name.
  String shareUrl(String name) {
    final encoded = Uri.encodeComponent(name);
    final url = '$_pwaBase/c/$code?name=$encoded';
    debugPrint('[LinkModel.shareUrl] name="$name" → $url');
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
    debugPrint('[LinkRepository.createLink] POST /link');
    final json = await _client.post('/link', {});
    debugPrint('[LinkRepository.createLink] response: $json');
    return LinkModel.fromJson(json as Map<String, dynamic>);
  }

  /// Get all my links.
  Future<List<LinkModel>> getMyLinks() async {
    debugPrint('[LinkRepository.getMyLinks] GET /link/mine');
    final json = await _client.get('/link/mine');
    debugPrint(
        '[LinkRepository.getMyLinks] response count: ${(json as List).length}');
    return json.map((e) => LinkModel.fromJson(e)).toList();
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
    try {
      return links.firstWhere((l) => l.isActive);
    } catch (_) {
      return null;
    }
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
    debugPrint('[LinkNotifier.fetchMyLinks] START');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final links = await _repo.getMyLinks();
      debugPrint(
          '[LinkNotifier.fetchMyLinks] OK — ${links.length} links, active=${links.where((l) => l.isActive).length}');
      state = LinkState(links: links);
    } catch (e, st) {
      debugPrint('[LinkNotifier.fetchMyLinks] ERROR: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Get or create an active link.
  Future<LinkModel> getOrCreateLink() async {
    debugPrint(
        '[LinkNotifier.getOrCreateLink] START — cached activeLink=${state.activeLink?.code}');
    if (state.activeLink != null) {
      debugPrint(
          '[LinkNotifier.getOrCreateLink] returning cached link: ${state.activeLink!.code}');
      return state.activeLink!;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      // Try fetching existing links first
      debugPrint('[LinkNotifier.getOrCreateLink] fetching existing links…');
      final links = await _repo.getMyLinks();
      debugPrint(
          '[LinkNotifier.getOrCreateLink] fetched ${links.length} links');
      if (links.isNotEmpty) {
        state = LinkState(links: links);
        final active = state.activeLink;
        if (active != null) {
          debugPrint(
              '[LinkNotifier.getOrCreateLink] found active link: ${active.code}');
          return active;
        }
        debugPrint(
            '[LinkNotifier.getOrCreateLink] no active link among ${links.length} fetched');
      }

      // Create a new one
      debugPrint('[LinkNotifier.getOrCreateLink] creating new link…');
      final link = await _repo.createLink();
      debugPrint('[LinkNotifier.getOrCreateLink] created link: ${link.code}');
      state = LinkState(links: [...state.links, link]);
      return link;
    } catch (e, st) {
      debugPrint('[LinkNotifier.getOrCreateLink] ERROR: $e\n$st');
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(error: e.toString());
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
