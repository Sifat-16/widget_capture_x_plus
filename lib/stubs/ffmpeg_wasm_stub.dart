import 'dart:typed_data';

class FFmpeg {
  FFmpeg(); // Default constructor if needed
  bool isLoaded() => false;
  Future<void> load() async {}
  void writeFile(String path, Uint8List data) {}
  Future<void> runCommand(String command) async {}
  // Future<void> run(List<String> args) async {} // If you use run with List<String>
  Uint8List readFile(String path) => Uint8List(0);
  void unlink(String path) {}
  void exit() {}
}

class CreateFFmpegParam {
  final bool? log;
  final String? corePath;
  final String? mainName;
  CreateFFmpegParam({this.log, this.corePath, this.mainName});
}

FFmpeg createFFmpeg(CreateFFmpegParam? params) => FFmpeg();
