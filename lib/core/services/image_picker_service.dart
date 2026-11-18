import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Presents a bottom-sheet source picker (camera / gallery) and returns the
/// path of the selected image or video, or null when cancelled.
class ImagePickerService {
  final _picker = ImagePicker();

  /// Pick an image from camera or gallery.
  Future<String?> pickImage(BuildContext context) async {
    final source = await _showSourceSheet(context, label: 'photo');
    if (source == null) return null;
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
    );
    return file?.path;
  }

  /// Pick a video from camera or gallery (max 3 min).
  Future<String?> pickVideo(BuildContext context) async {
    final source = await _showSourceSheet(context, label: 'vidéo');
    if (source == null) return null;
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    return file?.path;
  }

  Future<ImageSource?> _showSourceSheet(
    BuildContext context, {
    required String label,
  }) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('Prendre une $label'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}
