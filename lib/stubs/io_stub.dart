import 'dart:typed_data'; // For Uint8List, if File methods need it

class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async {
    // print("STUB: Directory.exists() called for $path on web");
    return false; // Assume doesn't exist for stub
  }

  Future<Directory> create({bool recursive = false}) async {
    // print("STUB: Directory.create() called for $path on web");
    return this;
  }

  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    return [];
  }

  Future<Directory> delete({bool recursive = false}) async {
    return this;
  }

  void deleteSync({bool recursive = false}) {}

  bool existsSync() {
    return false;
  }
}

// Basic File stub for web
class File {
  final String path;
  File(this.path);

  Future<File> writeAsBytes(
    Uint8List bytes, {
    bool flush = false,
    FileMode mode = FileMode.write,
  }) async {
    return this;
  }

  Future<bool> exists() async {
    return false;
  }

  Future<File> copy(String newPath) async {
    return File(newPath);
  }

  Future<void> delete() async {}
}

// Basic FileSystemEntity stub for web
abstract class FileSystemEntity {
  String get path;
  Future<FileSystemEntity> delete({bool recursive = false});
  // Add other common methods if needed
}

// Stub for FileMode if used (File.writeAsBytes uses it)
class FileMode {
  final int _mode;
  const FileMode._internal(this._mode);

  static const FileMode read = FileMode._internal(0);
  static const FileMode write = FileMode._internal(1);
  static const FileMode append = FileMode._internal(2);
  static const FileMode writeOnly = FileMode._internal(3);
  static const FileMode writeOnlyAppend = FileMode._internal(4);
}
