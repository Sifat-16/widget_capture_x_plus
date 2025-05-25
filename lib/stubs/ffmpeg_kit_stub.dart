import 'dart:async';

class FFmpegKit {
  static Future<FFmpegSession> execute(String command) async {
    print(
      "FFmpegKit STUB (Web): Execute called with: $command (Not actually run on web via this stub)",
    );
    // Simulate a delay and a failure by default for stub testing
    await Future.delayed(const Duration(milliseconds: 100));
    return FFmpegSession._(ReturnCode._withValue(1)); // Simulate failure
  }

  // Add other static methods of FFmpegKit if you use them, e.g., cancel, getPlatform, etc.
}

class FFmpegSession {
  final ReturnCode? _returnCode;
  final String _logs;

  FFmpegSession._(
    this._returnCode, [
    this._logs = "FFmpeg stub logs for web. Command not executed.",
  ]);

  Future<ReturnCode?> getReturnCode() async => _returnCode;
  Future<String?> getAllLogsAsString() async => _logs;
}

class ReturnCode {
  final int _value;
  const ReturnCode._withValue(this._value); // Made const

  static bool isSuccess(ReturnCode? code) => code != null && code._value == 0;
  int? getValue() => _value;
}
