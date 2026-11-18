part of 'media_gallery_screen.dart';

extension _MediaGallerySections on _MediaGalleryScreenState {
  Widget _buildTabContent(int index) {
    if (_loading[index] ?? false) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errors[index];
    if (error != null) {
      return _buildErrorState(index, error);
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

  Widget _buildErrorState(int index, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _retryTab(index),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryStart,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
