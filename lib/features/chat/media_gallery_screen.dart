import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/core/utils/helpers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mysme/shared/widgets/themed_icon_button.dart';
import 'package:video_player/video_player.dart';

part 'media_gallery_screen_sections.dart';
part 'media_gallery_screen_viewer.dart';

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
  final Map<int, String?> _errors = {};

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
    setState(() {
      _loading[index] = true;
      _errors[index] = null;
    });
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
        _errors[index] = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading[index] = false;
        _errors[index] = 'Impossible de charger cet onglet pour le moment';
      });
    }
  }

  Future<void> _retryTab(int index) async {
    if (!mounted) return;
    setState(() {
      _cache.remove(index);
      _errors[index] = null;
    });
    await _loadTab(index);
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
}
