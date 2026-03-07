import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Full-screen grid gallery of media shared in a conversation.
class MediaGalleryScreen extends ConsumerStatefulWidget {
  const MediaGalleryScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _tabs = ['Tout', 'Images', 'Vidéos', 'Audio', 'Fichiers'];
  final List<String?> _typeFilters = [null, 'image', 'video', 'audio', 'file'];

  final Map<int, List<MessageDto>> _cache = {};
  final Map<int, bool> _loading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadTab(_tabController.index);
    });
    _loadTab(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTab(int index) async {
    if (_cache.containsKey(index) || (_loading[index] ?? false)) return;
    setState(() => _loading[index] = true);
    try {
      final repo = ref.read(messageRepositoryProvider);
      final media = await repo.getMedia(
        widget.conversationId,
        type: _typeFilters[index],
      );
      if (!mounted) return;
      setState(() {
        _cache[index] = media;
        _loading[index] = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading[index] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Médias partagés'),
        backgroundColor: AppColors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(_tabs.length, _buildTabContent),
      ),
    );
  }

  Widget _buildTabContent(int index) {
    if (_loading[index] ?? false) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _cache[index];
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Aucun média',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildGridTile(items[i]),
    );
  }

  Widget _buildGridTile(MessageDto msg) {
    final url = msg.mediaUrl;
    final type = msg.mediaType ?? '';

    return GestureDetector(
      onTap: () => _openMediaViewer(msg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _buildThumb(url, type),
      ),
    );
  }

  Widget _buildThumb(String? url, String type) {
    if (type == 'image' && url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(Icons.broken_image),
      );
    }
    if (type == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black12),
          const Center(
            child:
                Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
          ),
        ],
      );
    }
    if (type == 'audio') {
      return _placeholder(Icons.audiotrack);
    }
    return _placeholder(Icons.insert_drive_file);
  }

  Widget _placeholder(IconData icon) {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(icon, size: 32, color: AppColors.deepPurple),
      ),
    );
  }

  void _openMediaViewer(MessageDto msg) {
    final url = msg.mediaUrl;
    if (url == null) return;
    final type = msg.mediaType ?? '';

    if (type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _FullImageViewer(url: url),
        ),
      );
    }
    // For video/audio/file, a more advanced viewer could be added later.
  }
}

/// Simple full-screen image viewer with pinch-to-zoom.
class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
