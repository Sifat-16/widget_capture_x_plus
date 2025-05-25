import 'dart:async';
// Conditional import for dart:io vs a stub for web
import 'dart:io'
    if (dart.library.html) 'package:widget_capture_x_plus/stubs/io_stub.dart';
import 'dart:typed_data'; // For Uint8List
import 'dart:ui' as ui show ImageByteFormat;

// Conditional imports for Native FFmpeg and path_provider (stubbed on web)
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart'
    if (dart.library.html) 'package:widget_capture_x_plus/stubs/ffmpeg_kit_stub.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart'
    if (dart.library.html) 'package:widget_capture_x_plus/stubs/ffmpeg_kit_stub.dart';
// --- Web specific import for ffmpeg_wasm ---
// This import will only be effective on web.
// For native, the NativeFfmpegExporter will be used which has its own imports.
import 'package:ffmpeg_wasm/ffmpeg_wasm.dart'
    if (dart.library.io) 'package:widget_capture_x_plus/stubs/ffmpeg_wasm_stub.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, ChangeNotifier, debugPrint;
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:widget_capture_x_plus/stubs/path_provider_stub.dart';
import 'package:screen_recorder/screen_recorder.dart'; // For ScreenRecorderController

// --- Data Structures ---
class RecordingOutput {
  final String? filePath;
  final Uint8List? rawData;
  final String? suggestedFileName;
  final bool success;
  final String? errorMessage;
  final String? userFriendlyMessage;

  RecordingOutput({
    this.filePath,
    this.rawData,
    this.suggestedFileName,
    this.success = true,
    this.errorMessage,
    this.userFriendlyMessage,
  });

  @override
  String toString() =>
      'RecordingOutput(success: $success, filePath: $filePath, rawDataLength: ${rawData?.length}, suggestedFileName: $suggestedFileName, userMessage: $userFriendlyMessage, errorMessage: $errorMessage)';
}

enum RecordingState { idle, preparing, recording, stopping, completed, error }

// --- Exporter Platform Interface ---
abstract class IWidgetCaptureXExporter extends Exporter {
  Future<void> init();
  // onNewFrame is inherited
  Future<void> finalizeRecording({
    required double outputTargetActualFpsFromController,
  });
  void dispose();

  void Function(Uint8List frameBytes)? onFrameStreamedCallback;
  bool Function()? isControllerDisposedCheckCallback;
}

// --- Native FFmpeg Exporter ---
class _NativeFfmpegExporter extends Exporter
    implements IWidgetCaptureXExporter {
  // ... (Implementation remains IDENTICAL to the last full code version you had for native) ...
  final Completer<RecordingOutput> _recordingCompleter;
  final String _outputBaseFileName;
  final String _outputFormat;
  final double _inputFpsForFFmpegCommand;
  final String _targetOutputResolution;
  @override
  bool Function()? isControllerDisposedCheckCallback;
  @override
  void Function(Uint8List frameBytes)? onFrameStreamedCallback;
  Directory? _tempDir;
  int _savedFrameCount = 0;
  bool _isProcessingStarted = false;
  List<Future<bool>> _pendingFrameSaveFutures = [];
  int _fileNameFrameCounter = 0;

  _NativeFfmpegExporter(
    this._recordingCompleter, {
    required String outputBaseFileName,
    required String outputFormat,
    required double inputFpsForFFmpegCommand,
    required String targetOutputResolution,
  }) : _outputBaseFileName = outputBaseFileName,
       _outputFormat = outputFormat,
       _inputFpsForFFmpegCommand =
           inputFpsForFFmpegCommand.isFinite && inputFpsForFFmpegCommand > 0
               ? inputFpsForFFmpegCommand
               : 15.0,
       _targetOutputResolution = targetOutputResolution,
       super();

  @override
  Future<void> init() async {
    try {
      final tempDirFromProvider = await getTemporaryDirectory();
      _tempDir = Directory(
        tempDirFromProvider!.path +
            '/wcx_frames_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _tempDir!.create(recursive: true);
      _savedFrameCount = 0;
      _fileNameFrameCounter = 0;
      _isProcessingStarted = false;
      _pendingFrameSaveFutures = [];
      debugPrint(
        "NativeFfmpegExporter: Temp directory created at ${_tempDir!.path}",
      );
    } catch (e) {
      if (!_recordingCompleter.isCompleted)
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Failed to init native storage: $e",
          ),
        );
      throw Exception("Failed to init native exporter: $e");
    }
  }

  @override
  void onNewFrame(Frame frame) {
    if (isControllerDisposedCheckCallback?.call() ??
        false || _tempDir == null) {
      frame.image.dispose();
      return;
    }
    if (!_isProcessingStarted) _isProcessingStarted = true;
    final currentFileNumber = _fileNameFrameCounter++;
    final saveFuture = _processAndSaveFrame(frame, currentFileNumber);
    _pendingFrameSaveFutures.add(saveFuture);
  }

  Future<bool> _processAndSaveFrame(Frame frame, int frameNumberForFile) async {
    bool success = false;
    Directory? capturedTempDir = _tempDir;
    try {
      if (isControllerDisposedCheckCallback?.call() ??
          false || capturedTempDir == null || !await capturedTempDir.exists())
        return false;
      final frameNumberStr = frameNumberForFile.toString().padLeft(5, '0');
      final filePath = '${capturedTempDir?.path}/frame_$frameNumberStr.png';
      final File frameFile = File(filePath);
      final ByteData? byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        await frameFile.writeAsBytes(pngBytes, flush: true);
        onFrameStreamedCallback?.call(pngBytes);
        success = true;
      }
    } catch (e) {
      debugPrint(
        "NativeFfmpegExporter: ERROR writing frame $frameNumberForFile: $e",
      );
    } finally {
      frame.image.dispose();
    }
    return success;
  }

  @override
  Future<void> finalizeRecording({
    required double outputTargetActualFpsFromController,
  }) async {
    debugPrint("NativeFfmpegExporter: Finalizing. Waiting for frame saves...");
    List<bool> saveResults = [];
    if (_pendingFrameSaveFutures.isNotEmpty) {
      saveResults = await Future.wait(_pendingFrameSaveFutures).catchError((e) {
        return List<bool>.filled(_pendingFrameSaveFutures.length, false);
      });
    }
    _pendingFrameSaveFutures.clear();
    _savedFrameCount = saveResults.where((s) => s).length;
    debugPrint(
      "NativeFfmpegExporter: Frame saves complete. Saved frames: $_savedFrameCount",
    );
    if (_tempDir == null || _savedFrameCount == 0) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "No frames saved or temp dir missing for native.",
          ),
        );
      }
      await _cleanupTempDirAndFutures();
      return;
    }
    final Directory appDocDir = (await getApplicationDocumentsDirectory())!;
    final String intermediateOutputFileName =
        '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}_temp.${_outputFormat}';
    final String intermediateOutputFilePath =
        '${appDocDir.path}/$intermediateOutputFileName';
    final double outputFpsForCommand =
        (outputTargetActualFpsFromController > 0 &&
                outputTargetActualFpsFromController.isFinite)
            ? outputTargetActualFpsFromController
            : _inputFpsForFFmpegCommand;
    final double expectedDurationSecs =
        _savedFrameCount / _inputFpsForFFmpegCommand;
    final String durationString = expectedDurationSecs.toStringAsFixed(3);
    String resolutionFilterPart;
    if (_targetOutputResolution.isNotEmpty &&
        _targetOutputResolution.contains('x')) {
      resolutionFilterPart =
          "scale=$_targetOutputResolution:force_original_aspect_ratio=decrease,pad=$_targetOutputResolution:(ow-iw)/2:(oh-ih)/2:color=black";
    } else {
      resolutionFilterPart =
          "pad=width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=(ow-iw)/2:y=(oh-ih)/2:color=black";
    }
    final String ffmpegCommand =
        '-framerate $_inputFpsForFFmpegCommand -i "${_tempDir!.path}/frame_%05d.png" -vf "vflip,${resolutionFilterPart},format=yuv420p" -c:v libx264 -preset ultrafast -crf 23 -r $outputFpsForCommand -t $durationString "$intermediateOutputFilePath"';
    debugPrint("NativeFfmpegExporter: Executing FFmpeg: $ffmpegCommand");
    String finalSavedPath = intermediateOutputFilePath;
    String? userMessage;
    try {
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      final logs = await session.getAllLogsAsString();
      debugPrint("NativeFfmpegExporter: FFmpeg logs:\n$logs");
      if (ReturnCode.isSuccess(returnCode)) {
        try {
          Directory? downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            final String publicFileName =
                '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}.${_outputFormat}';
            final String publicFilePath =
                '${downloadsDir.path}/$publicFileName';
            File originalFile = File(intermediateOutputFilePath);
            if (await originalFile.exists()) {
              await originalFile.copy(publicFilePath);
              finalSavedPath = publicFilePath;
              userMessage = "Video saved to Downloads: $publicFileName";
            } else {
              userMessage = "Internal video ready, copy failed.";
            }
          } else {
            userMessage = "Video in app storage (Downloads not found).";
          }
        } catch (e_copy) {
          userMessage = "Video in app storage (Error copying to Downloads).";
        }
        if (!_recordingCompleter.isCompleted) {
          _recordingCompleter.complete(
            RecordingOutput(
              filePath: finalSavedPath,
              success: true,
              userFriendlyMessage: userMessage ?? "Video saved.",
            ),
          );
        }
      } else {
        if (!_recordingCompleter.isCompleted) {
          _recordingCompleter.complete(
            RecordingOutput(
              success: false,
              errorMessage: "FFmpeg failed. Code: ${returnCode?.getValue()}",
              userFriendlyMessage: "Video processing failed.",
            ),
          );
        }
      }
    } catch (e_ffmpeg) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "FFmpeg exception: $e_ffmpeg",
            userFriendlyMessage: "Video processing error.",
          ),
        );
      }
    } finally {
      await _cleanupTempDirAndFutures();
    }
  }

  Future<void> _cleanupTempDir() async {
    /* ... as before ... */
  }
  Future<void> _cleanupTempDirAndFutures() async {
    /* ... as before ... */
  }
  @override
  void dispose() {
    /* ... as before ... */
    debugPrint("NativeFfmpegExporter: dispose() called.");
    _cleanupTempDirAndFutures();
    if (!_recordingCompleter.isCompleted) {
      _recordingCompleter.complete(
        RecordingOutput(
          success: false,
          errorMessage: "Exporter disposed prematurely.",
          userFriendlyMessage: "Recording cancelled.",
        ),
      );
    }
  }
}

// --- Web FFmpeg.wasm Exporter (Using ffmpeg_wasm package) ---
class _WebFfmpegWasmExporter extends Exporter
    implements IWidgetCaptureXExporter {
  final Completer<RecordingOutput> _recordingCompleter;
  final String _outputBaseFileName;
  final String _outputFormat;
  final double _inputFpsForFFmpegCommand;
  final String _targetOutputResolution;

  @override
  bool Function()? isControllerDisposedCheckCallback;
  @override
  void Function(Uint8List frameBytes)? onFrameStreamedCallback;

  List<String> _savedFrameFileNamesInWasm = [];
  bool _isProcessingStarted = false;
  int _fileNameFrameCounter = 0;

  FFmpeg? _ffmpeg; // Instance from ffmpeg_wasm package

  _WebFfmpegWasmExporter(
    this._recordingCompleter, {
    required String outputBaseFileName,
    required String outputFormat,
    required double inputFpsForFFmpegCommand,
    required String targetOutputResolution,
  }) : _outputBaseFileName = outputBaseFileName,
       _outputFormat = outputFormat,
       _inputFpsForFFmpegCommand =
           inputFpsForFFmpegCommand.isFinite && inputFpsForFFmpegCommand > 0
               ? inputFpsForFFmpegCommand
               : 15.0,
       _targetOutputResolution = targetOutputResolution,
       super();

  @override
  Future<void> init() async {
    try {
      // Create and load FFmpeg instance using the ffmpeg_wasm package
      _ffmpeg = createFFmpeg(
        CreateFFmpegParam(
          log: true, // Enable console logging from ffmpeg.wasm
          corePath:
              'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js', // ST version
          mainName: 'main',
          // corePath:
          //     'https://unpkg.com/@ffmpeg/core@0.11.0/dist/ffmpeg-core.js', // Example
        ),
      );
      if (!_ffmpeg!.isLoaded()) {
        await _ffmpeg!.load();
      }
      debugPrint("WebFfmpegWasmExporter: FFmpeg.wasm loaded and initialized.");
      _isProcessingStarted = false;
      _savedFrameFileNamesInWasm = [];
      _fileNameFrameCounter = 0;
    } catch (e) {
      debugPrint("WebFfmpegWasmExporter: Error during ffmpeg.wasm init: $e");
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Failed to initialize WebAssembly FFmpeg: $e",
          ),
        );
      }
      throw Exception("Failed to initialize web exporter: $e");
    }
  }

  @override
  void onNewFrame(Frame frame) async {
    // Can be async void
    if (isControllerDisposedCheckCallback?.call() ?? false || _ffmpeg == null) {
      frame.image.dispose();
      return;
    }
    if (!_isProcessingStarted) _isProcessingStarted = true;

    final frameNumberForFile = _fileNameFrameCounter++;
    final fileNameInWasm =
        'frame_${frameNumberForFile.toString().padLeft(5, '0')}.png';

    try {
      final ByteData? byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Use ffmpeg_wasm package API to write file
        _ffmpeg!.writeFile(fileNameInWasm, pngBytes);
        // debugPrint("WebFfmpegWasmExporter: Wrote $fileNameInWasm to MEMFS.");

        _savedFrameFileNamesInWasm.add(fileNameInWasm);
        onFrameStreamedCallback?.call(pngBytes);
      } else {
        debugPrint(
          "WebFfmpegWasmExporter: Failed to get byteData for frame $fileNameInWasm.",
        );
      }
    } catch (e) {
      debugPrint(
        "WebFfmpegWasmExporter: ERROR processing frame $fileNameInWasm for WASM: $e",
      );
    } finally {
      frame.image.dispose();
    }
  }

  @override
  Future<void> finalizeRecording({
    required double outputTargetActualFpsFromController,
  }) async {
    if (_ffmpeg == null || _savedFrameFileNamesInWasm.isEmpty) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "FFmpeg not loaded or no frames captured for web.",
          ),
        );
      }
      await _cleanupWasmSessionFiles([]);
      return;
    }

    // final String outputWasmFileName = "output.${_outputFormat}";
    final String outputWasmFileName = "output.webm";
    final double outputFpsForCommand =
        (outputTargetActualFpsFromController > 0 &&
                outputTargetActualFpsFromController.isFinite)
            ? outputTargetActualFpsFromController
            : _inputFpsForFFmpegCommand;
    final double expectedDurationSecs =
        _savedFrameFileNamesInWasm.length / _inputFpsForFFmpegCommand;
    final String durationString = expectedDurationSecs.toStringAsFixed(3);
    String resolutionFilterPart;
    if (_targetOutputResolution.isNotEmpty &&
        _targetOutputResolution.contains('x')) {
      resolutionFilterPart =
          "scale=$_targetOutputResolution:force_original_aspect_ratio=decrease,pad=$_targetOutputResolution:(ow-iw)/2:(oh-ih)/2:color=black";
    } else {
      resolutionFilterPart =
          "pad=width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=(ow-iw)/2:y=(oh-ih)/2:color=black";
    }

    // Construct command as List<String> or a single string for runCommand
    // final String commandString =
    //     '-framerate $_inputFpsForFFmpegCommand -i frame_%05d.png ' +
    //     '-vf "vflip,${resolutionFilterPart},format=yuv420p" ' +
    //     '-c:v libx264 -preset ultrafast -crf 28 ' + // Ensure libx264 is in your ffmpeg.wasm build
    //     '-r $outputFpsForCommand -t $durationString ' +
    //     outputWasmFileName;

    String commandString =
        '-framerate $_inputFpsForFFmpegCommand -i frame_%05d.png '
        '-vf vflip '
        '-r $outputFpsForCommand -t $durationString '
        '${outputWasmFileName}';

    debugPrint(
      "WebFfmpegWasmExporter: Executing FFmpeg WASM command: $commandString",
    );

    try {
      // Use runCommand or run (which takes List<String>)
      await _ffmpeg!.runCommand(
        commandString,
      ); // or _ffmpeg.run([...list of args...]);

      final Uint8List outputBytes = _ffmpeg!.readFile(outputWasmFileName);

      if (outputBytes.isNotEmpty) {
        debugPrint(
          "WebFfmpegWasmExporter: FFmpeg WASM encoding successful. Output size: ${outputBytes.length} bytes.",
        );
        if (!_recordingCompleter.isCompleted) {
          _recordingCompleter.complete(
            RecordingOutput(
              rawData: outputBytes,
              success: true,
              suggestedFileName:
                  '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}.${_outputFormat}',
              userFriendlyMessage: "Video ready for download.",
            ),
          );
        }
      } else {
        debugPrint(
          "WebFfmpegWasmExporter: FFmpeg WASM encoding failed or produced empty output.",
        );
        if (!_recordingCompleter.isCompleted) {
          _recordingCompleter.complete(
            RecordingOutput(
              success: false,
              errorMessage: "FFmpeg WASM encoding failed (empty output).",
              userFriendlyMessage: "Web video processing failed.",
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
        "WebFfmpegWasmExporter: Exception during FFmpeg WASM execution: $e",
      );
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "FFmpeg WASM execution exception: $e",
            userFriendlyMessage: "Web video processing error.",
          ),
        );
      }
    } finally {
      await _cleanupWasmSessionFiles(
        List.from(_savedFrameFileNamesInWasm)..add(outputWasmFileName),
      );
      _isProcessingStarted = false;
      _savedFrameFileNamesInWasm = [];
      _fileNameFrameCounter = 0;
    }
  }

  Future<void> _cleanupWasmSessionFiles(List<String> filesToClean) async {
    if (_ffmpeg != null && filesToClean.isNotEmpty) {
      debugPrint(
        "WebFfmpegWasmExporter: Cleaning up ${filesToClean.length} WASM files.",
      );
      for (final fileName in filesToClean) {
        try {
          _ffmpeg!.unlink(fileName);
        } catch (e) {
          /* ignore if file not found during cleanup */
        }
      }
    }
  }

  @override
  void dispose() {
    debugPrint("WebFfmpegWasmExporter: dispose() called.");
    if (!_recordingCompleter.isCompleted) {
      _recordingCompleter.complete(
        RecordingOutput(
          success: false,
          errorMessage: "Exporter disposed prematurely.",
          userFriendlyMessage: "Recording cancelled.",
        ),
      );
    }
    // The readme says: "Do not call exit if you want to reuse same ffmpeg instance"
    // "When you call exit the temporary files are deleted from MEMFS"
    // If we want to ensure cleanup and not reuse this specific _ffmpeg instance for a *new* recording session,
    // calling exit() might be appropriate here. Or, manage cleanup with _cleanupWasmSessionFiles.
    // If _ffmpeg instance is per-recording session (recreated in controller.startRecording -> exporter.init), then exit() is fine.
    _ffmpeg?.exit(); // This should clean MEMFS.
    _ffmpeg = null;
    _isProcessingStarted = false;
    _savedFrameFileNamesInWasm = [];
    _fileNameFrameCounter = 0;
  }
}

// --- Main Controller ---
class WidgetCaptureXPlusController extends ChangeNotifier {
  ScreenRecorderController? _nativeScreenRecorderController;
  IWidgetCaptureXExporter? _exporter; // Use the interface type
  Completer<RecordingOutput>? _recordingCompleter;

  RecordingState _recordingState = RecordingState.idle;
  RecordingState get recordingState => _recordingState;
  RecordingOutput? _lastOutput;
  RecordingOutput? get lastOutput => _lastOutput;
  String? _currentError;
  String? get currentError => _currentError;

  final double pixelRatio;
  final int skipFramesBetweenCaptures;
  final String outputBaseFileName;
  final String outputFormat;
  final double targetOutputFps;
  final String targetOutputResolution;

  bool _isDisposed = false;

  late StreamController<Uint8List> _frameStreamController;
  Stream<Uint8List> get frameStream => _frameStreamController.stream;

  ScreenRecorderController get activeScreenRecorderController {
    if (_nativeScreenRecorderController == null) {
      throw StateError("ScreenRecorderController not initialized.");
    }
    return _nativeScreenRecorderController!;
  }

  WidgetCaptureXPlusController({
    this.pixelRatio = 1.0,
    this.skipFramesBetweenCaptures = 2,
    this.outputBaseFileName = "widget_capture",
    this.outputFormat = "mp4",
    this.targetOutputFps = 30.0,
    this.targetOutputResolution = "",
  }) {
    _frameStreamController = StreamController<Uint8List>.broadcast();
  }

  void _updateState(
    RecordingState newState, {
    String? error,
    RecordingOutput? output,
  }) {
    if (_isDisposed) return;
    bool coreStateChanged =
        _recordingState != newState || _currentError != error;
    bool outputChanged =
        (_lastOutput?.filePath != output?.filePath) ||
        (_lastOutput?.rawData?.length != output?.rawData?.length) ||
        (_lastOutput?.success != output?.success);
    if (!coreStateChanged &&
        !outputChanged &&
        _lastOutput?.userFriendlyMessage == output?.userFriendlyMessage)
      return;
    _recordingState = newState;
    _currentError = error;
    if (output != null) _lastOutput = output;
    if (error != null) debugPrint("WidgetCaptureXController Error: $error");
    notifyListeners();
  }

  Future<void> startRecording({
    Duration initialDelay = const Duration(milliseconds: 200),
  }) async {
    if (_isDisposed ||
        _recordingState == RecordingState.recording ||
        _recordingState == RecordingState.preparing)
      return;

    _updateState(RecordingState.preparing);
    _lastOutput = null;
    _currentError = null;

    if (_frameStreamController.isClosed) {
      _frameStreamController = StreamController<Uint8List>.broadcast();
    }
    _recordingCompleter = Completer<RecordingOutput>();

    const double assumedDeviceFps = 60.0;
    final double actualCaptureInputFps =
        assumedDeviceFps / (1 + skipFramesBetweenCaptures);
    final double inputFpsForFFmpegCommand = actualCaptureInputFps;

    String currentOutputFormat = outputFormat;
    // Example: Prefer 'webm' for web if output is mp4, as h264 in wasm can be tricky
    // if (kIsWeb && outputFormat.toLowerCase() == "mp4") {
    //   currentOutputFormat = "webm";
    //   debugPrint("WidgetCaptureXController: Web platform, suggesting output format 'webm'.");
    // }

    if (kIsWeb) {
      debugPrint(
        "WidgetCaptureXController: Initializing Web Exporter using ffmpeg_wasm package.",
      );
      _exporter = _WebFfmpegWasmExporter(
        _recordingCompleter!,
        outputBaseFileName: outputBaseFileName,
        outputFormat: currentOutputFormat,
        inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
        targetOutputResolution: targetOutputResolution,
      );
    } else {
      debugPrint("WidgetCaptureXController: Initializing Native Exporter.");
      _exporter = _NativeFfmpegExporter(
        _recordingCompleter!,
        outputBaseFileName: outputBaseFileName,
        outputFormat: currentOutputFormat,
        inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
        targetOutputResolution: targetOutputResolution,
      );
    }

    _exporter!.isControllerDisposedCheckCallback = () => _isDisposed;
    _exporter!.onFrameStreamedCallback = (Uint8List frameBytes) {
      if (!_frameStreamController.isClosed) {
        _frameStreamController.add(frameBytes);
      }
    };

    try {
      await _exporter!.init();
      if (_isDisposed) {
        _exporter?.dispose();
        return;
      }

      _nativeScreenRecorderController = ScreenRecorderController(
        exporter:
            _exporter!, // Pass the IWidgetCaptureXExporter (which is an Exporter)
        pixelRatio: pixelRatio,
        skipFramesBetweenCaptures: skipFramesBetweenCaptures,
      );
      notifyListeners();

      await Future.delayed(initialDelay);
      if (_isDisposed) {
        _exporter?.dispose();
        return;
      }

      _nativeScreenRecorderController!.start();
      _updateState(RecordingState.recording);
      debugPrint(
        "WidgetCaptureXController: Recording started. Platform: ${kIsWeb ? "Web" : "Native"}. Input FPS for FFmpeg: $inputFpsForFFmpegCommand. Target output FPS: $targetOutputFps",
      );
    } catch (e) {
      final errMessage = "Failed to start recording: ${e.toString()}";
      _updateState(RecordingState.error, error: errMessage);
      if (!(_recordingCompleter?.isCompleted ?? true)) {
        _recordingCompleter!.complete(
          RecordingOutput(success: false, errorMessage: errMessage),
        );
      }
      _exporter?.dispose();
      _exporter = null;
    }
  }

  Future<RecordingOutput?> stopRecording() async {
    if (_isDisposed)
      return RecordingOutput(
        success: false,
        errorMessage: "Controller disposed.",
      );
    if (_recordingState != RecordingState.recording) {
      if (_recordingState == RecordingState.preparing &&
          _recordingCompleter != null &&
          !_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Recording stopped during preparation.",
          ),
        );
        _exporter?.dispose();
        _exporter = null;
      }
      if (_recordingState != RecordingState.error &&
          _recordingState != RecordingState.completed &&
          _recordingState != RecordingState.stopping) {
        _updateState(RecordingState.idle);
      }
      return _lastOutput;
    }
    _updateState(RecordingState.stopping);
    try {
      _nativeScreenRecorderController?.stop();
      if (_exporter != null) {
        await _exporter!.finalizeRecording(
          outputTargetActualFpsFromController: targetOutputFps,
        );
      } else {
        throw Exception("Exporter was null during stopRecording.");
      }
      final result = await _recordingCompleter!.future;
      _updateState(
        RecordingState.completed,
        output: result,
        error: result.success ? null : result.errorMessage,
      );
      return result;
    } catch (e) {
      final errMessage = "Failed to stop/process recording: ${e.toString()}";
      _updateState(RecordingState.error, error: errMessage);
      if (!(_recordingCompleter?.isCompleted ?? true)) {
        _recordingCompleter!.complete(
          RecordingOutput(success: false, errorMessage: errMessage),
        );
      }
      return RecordingOutput(success: false, errorMessage: errMessage);
    } finally {
      _exporter?.dispose();
      _exporter = null;
      _nativeScreenRecorderController = null;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint("WidgetCaptureXController: dispose() called.");
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.stopping ||
        _recordingState == RecordingState.preparing) {
      _nativeScreenRecorderController?.stop();
    }
    _exporter?.dispose();
    _exporter = null;
    _nativeScreenRecorderController = null;
    if (!_frameStreamController.isClosed) {
      _frameStreamController.close();
    }
    super.dispose();
  }
}
