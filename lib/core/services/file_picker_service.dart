import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Metadata returned by [FilePickerService.pickFile].
typedef PickedFile = ({Uint8List bytes, String name, String extension});

/// Wraps [FilePicker] and returns file bytes + metadata in one call.
class FilePickerService {
  /// Pick any file and return its raw bytes along with the name and extension.
  /// Returns null when the user cancels or no data is available.
  Future<PickedFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    return _fromResult(result);
  }

  PickedFile? _fromResult(FilePickerResult? result) {
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes == null) return null;
    return (
      bytes: f.bytes!,
      name: f.name,
      extension: f.extension ?? 'bin',
    );
  }
}
