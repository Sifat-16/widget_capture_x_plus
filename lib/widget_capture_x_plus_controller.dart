// import 'dart:async';
// // Conditional import for dart:io vs a stub for web
// import 'dart:io'
//     if (dart.library.html) 'package:widget_capture_x_plus/stubs/io_stub.dart';
// import 'dart:typed_data'; // For Uint8List
// import 'dart:ui' as ui show ImageByteFormat;
//
// // Conditional imports for Native FFmpeg and path_provider (stubbed on web)
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart'
//     if (dart.library.html) 'package:widget_capture_x_plus/stubs/ffmpeg_kit_stub.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart'
//     if (dart.library.html) 'package:widget_capture_x_plus/stubs/ffmpeg_kit_stub.dart';
// // --- Web specific import for ffmpeg_wasm ---
// // This import will only be effective on web.
// // For native, the NativeFfmpegExporter will be used which has its own imports.
// import 'package:ffmpeg_wasm/ffmpeg_wasm.dart'
//     if (dart.library.io) 'package:widget_capture_x_plus/stubs/ffmpeg_wasm_stub.dart';
// import 'package:flutter/foundation.dart'
//     show kIsWeb, ChangeNotifier, debugPrint;
// import 'package:path_provider/path_provider.dart'
//     if (dart.library.html) 'package:widget_capture_x_plus/stubs/path_provider_stub.dart';
// import 'package:screen_recorder/screen_recorder.dart'; // For ScreenRecorderController
//
// // --- Data Structures ---
// class RecordingOutput {
//   final String? filePath;
//   final Uint8List? rawData;
//   final String? suggestedFileName;
//   final bool success;
//   final String? errorMessage;
//   final String? userFriendlyMessage;
//
//   RecordingOutput({
//     this.filePath,
//     this.rawData,
//     this.suggestedFileName,
//     this.success = true,
//     this.errorMessage,
//     this.userFriendlyMessage,
//   });
//
//   @override
//   String toString() =>
//       'RecordingOutput(success: $success, filePath: $filePath, rawDataLength: ${rawData?.length}, suggestedFileName: $suggestedFileName, userMessage: $userFriendlyMessage, errorMessage: $errorMessage)';
// }
//
// enum RecordingState { idle, preparing, recording, stopping, completed, error }
//
// // --- Exporter Platform Interface ---
// abstract class IWidgetCaptureXExporter extends Exporter {
//   Future<void> init();
//   // onNewFrame is inherited
//   Future<void> finalizeRecording({
//     required double outputTargetActualFpsFromController,
//   });
//   void dispose();
//
//   void Function(Uint8List frameBytes)? onFrameStreamedCallback;
//   bool Function()? isControllerDisposedCheckCallback;
// }
//
// // --- Native FFmpeg Exporter ---
// class _NativeFfmpegExporter extends Exporter
//     implements IWidgetCaptureXExporter {
//   // ... (Implementation remains IDENTICAL to the last full code version you had for native) ...
//   final Completer<RecordingOutput> _recordingCompleter;
//   final String _outputBaseFileName;
//   final String _outputFormat;
//   final double _inputFpsForFFmpegCommand;
//   final String _targetOutputResolution;
//   @override
//   bool Function()? isControllerDisposedCheckCallback;
//   @override
//   void Function(Uint8List frameBytes)? onFrameStreamedCallback;
//   Directory? _tempDir;
//   int _savedFrameCount = 0;
//   bool _isProcessingStarted = false;
//   List<Future<bool>> _pendingFrameSaveFutures = [];
//   int _fileNameFrameCounter = 0;
//
//   _NativeFfmpegExporter(
//     this._recordingCompleter, {
//     required String outputBaseFileName,
//     required String outputFormat,
//     required double inputFpsForFFmpegCommand,
//     required String targetOutputResolution,
//   }) : _outputBaseFileName = outputBaseFileName,
//        _outputFormat = outputFormat,
//        _inputFpsForFFmpegCommand =
//            inputFpsForFFmpegCommand.isFinite && inputFpsForFFmpegCommand > 0
//                ? inputFpsForFFmpegCommand
//                : 15.0,
//        _targetOutputResolution = targetOutputResolution,
//        super();
//
//   @override
//   Future<void> init() async {
//     try {
//       final tempDirFromProvider = await getTemporaryDirectory();
//       _tempDir = Directory(
//         '${tempDirFromProvider!.path}/wcx_frames_${DateTime.now().millisecondsSinceEpoch}',
//       );
//       await _tempDir!.create(recursive: true);
//       _savedFrameCount = 0;
//       _fileNameFrameCounter = 0;
//       _isProcessingStarted = false;
//       _pendingFrameSaveFutures = [];
//       debugPrint(
//         "NativeFfmpegExporter: Temp directory created at ${_tempDir!.path}",
//       );
//     } catch (e) {
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Failed to init native storage: $e",
//           ),
//         );
//       }
//       throw Exception("Failed to init native exporter: $e");
//     }
//   }
//
//   @override
//   void onNewFrame(Frame frame) {
//     if (isControllerDisposedCheckCallback?.call() ??
//         false || _tempDir == null) {
//       frame.image.dispose();
//       return;
//     }
//     if (!_isProcessingStarted) _isProcessingStarted = true;
//     final currentFileNumber = _fileNameFrameCounter++;
//     final saveFuture = _processAndSaveFrame(frame, currentFileNumber);
//     _pendingFrameSaveFutures.add(saveFuture);
//   }
//
//   Future<bool> _processAndSaveFrame(Frame frame, int frameNumberForFile) async {
//     bool success = false;
//     Directory? capturedTempDir = _tempDir;
//     try {
//       if (isControllerDisposedCheckCallback?.call() ??
//           false || capturedTempDir == null || !await capturedTempDir.exists()) {
//         return false;
//       }
//       final frameNumberStr = frameNumberForFile.toString().padLeft(5, '0');
//       final filePath = '${capturedTempDir?.path}/frame_$frameNumberStr.png';
//       final File frameFile = File(filePath);
//       final ByteData? byteData = await frame.image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );
//       if (byteData != null) {
//         final Uint8List pngBytes = byteData.buffer.asUint8List();
//         await frameFile.writeAsBytes(pngBytes, flush: true);
//         onFrameStreamedCallback?.call(pngBytes);
//         success = true;
//       }
//     } catch (e) {
//       debugPrint(
//         "NativeFfmpegExporter: ERROR writing frame $frameNumberForFile: $e",
//       );
//     } finally {
//       frame.image.dispose();
//     }
//     return success;
//   }
//
//   @override
//   Future<void> finalizeRecording({
//     required double outputTargetActualFpsFromController,
//   }) async {
//     debugPrint("NativeFfmpegExporter: Finalizing. Waiting for frame saves...");
//     List<bool> saveResults = [];
//     if (_pendingFrameSaveFutures.isNotEmpty) {
//       saveResults = await Future.wait(_pendingFrameSaveFutures).catchError((e) {
//         return List<bool>.filled(_pendingFrameSaveFutures.length, false);
//       });
//     }
//     _pendingFrameSaveFutures.clear();
//     _savedFrameCount = saveResults.where((s) => s).length;
//     debugPrint(
//       "NativeFfmpegExporter: Frame saves complete. Saved frames: $_savedFrameCount",
//     );
//     if (_tempDir == null || _savedFrameCount == 0) {
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "No frames saved or temp dir missing for native.",
//           ),
//         );
//       }
//       await _cleanupTempDirAndFutures();
//       return;
//     }
//     final Directory appDocDir = (await getApplicationDocumentsDirectory())!;
//     final String intermediateOutputFileName =
//         '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}_temp.${_outputFormat}';
//     final String intermediateOutputFilePath =
//         '${appDocDir.path}/$intermediateOutputFileName';
//     final double outputFpsForCommand =
//         (outputTargetActualFpsFromController > 0 &&
//                 outputTargetActualFpsFromController.isFinite)
//             ? outputTargetActualFpsFromController
//             : _inputFpsForFFmpegCommand;
//     final double expectedDurationSecs =
//         _savedFrameCount / _inputFpsForFFmpegCommand;
//     final String durationString = expectedDurationSecs.toStringAsFixed(3);
//     String resolutionFilterPart;
//     if (_targetOutputResolution.isNotEmpty &&
//         _targetOutputResolution.contains('x')) {
//       resolutionFilterPart =
//           "scale=$_targetOutputResolution:force_original_aspect_ratio=decrease,pad=$_targetOutputResolution:(ow-iw)/2:(oh-ih)/2:color=black";
//     } else {
//       resolutionFilterPart =
//           "pad=width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=(ow-iw)/2:y=(oh-ih)/2:color=black";
//     }
//     final String ffmpegCommand =
//         '-framerate $_inputFpsForFFmpegCommand -i "${_tempDir!.path}/frame_%05d.png" -vf "${resolutionFilterPart},format=yuv420p" -c:v libx264 -preset ultrafast -crf 23 -r $outputFpsForCommand -t $durationString "$intermediateOutputFilePath"';
//     debugPrint("NativeFfmpegExporter: Executing FFmpeg: $ffmpegCommand");
//     String finalSavedPath = intermediateOutputFilePath;
//     String? userMessage;
//     try {
//       final session = await FFmpegKit.execute(ffmpegCommand);
//       final returnCode = await session.getReturnCode();
//       final logs = await session.getAllLogsAsString();
//       debugPrint("NativeFfmpegExporter: FFmpeg logs:\n$logs");
//       if (ReturnCode.isSuccess(returnCode)) {
//         try {
//           Directory? downloadsDir = await getDownloadsDirectory();
//           if (downloadsDir != null) {
//             final String publicFileName =
//                 '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}.${_outputFormat}';
//             final String publicFilePath =
//                 '${downloadsDir.path}/$publicFileName';
//             File originalFile = File(intermediateOutputFilePath);
//             if (await originalFile.exists()) {
//               await originalFile.copy(publicFilePath);
//               finalSavedPath = publicFilePath;
//               userMessage = "Video saved to Downloads: $publicFileName";
//             } else {
//               userMessage = "Internal video ready, copy failed.";
//             }
//           } else {
//             userMessage = "Video in app storage (Downloads not found).";
//           }
//         } catch (e_copy) {
//           userMessage = "Video in app storage (Error copying to Downloads).";
//         }
//         if (!_recordingCompleter.isCompleted) {
//           _recordingCompleter.complete(
//             RecordingOutput(
//               filePath: finalSavedPath,
//               success: true,
//               userFriendlyMessage: userMessage ?? "Video saved.",
//             ),
//           );
//         }
//       } else {
//         if (!_recordingCompleter.isCompleted) {
//           _recordingCompleter.complete(
//             RecordingOutput(
//               success: false,
//               errorMessage: "FFmpeg failed. Code: ${returnCode?.getValue()}",
//               userFriendlyMessage: "Video processing failed.",
//             ),
//           );
//         }
//       }
//     } catch (e_ffmpeg) {
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "FFmpeg exception: $e_ffmpeg",
//             userFriendlyMessage: "Video processing error.",
//           ),
//         );
//       }
//     } finally {
//       await _cleanupTempDirAndFutures();
//     }
//   }
//
//   Future<void> _cleanupTempDir() async {
//     /* ... as before ... */
//   }
//   Future<void> _cleanupTempDirAndFutures() async {
//     /* ... as before ... */
//   }
//   @override
//   void dispose() {
//     /* ... as before ... */
//     debugPrint("NativeFfmpegExporter: dispose() called.");
//     _cleanupTempDirAndFutures();
//     if (!_recordingCompleter.isCompleted) {
//       _recordingCompleter.complete(
//         RecordingOutput(
//           success: false,
//           errorMessage: "Exporter disposed prematurely.",
//           userFriendlyMessage: "Recording cancelled.",
//         ),
//       );
//     }
//   }
// }
//
// // --- Web FFmpeg.wasm Exporter (Using ffmpeg_wasm package) ---
// class _WebFfmpegWasmExporter extends Exporter
//     implements IWidgetCaptureXExporter {
//   final Completer<RecordingOutput> _recordingCompleter;
//   final String _outputBaseFileName;
//   final String _outputFormat;
//   final double _inputFpsForFFmpegCommand;
//   final String _targetOutputResolution;
//
//   @override
//   bool Function()? isControllerDisposedCheckCallback;
//   @override
//   void Function(Uint8List frameBytes)? onFrameStreamedCallback;
//
//   List<String> _savedFrameFileNamesInWasm = [];
//   bool _isProcessingStarted = false;
//   int _fileNameFrameCounter = 0;
//
//   FFmpeg? _ffmpeg; // Instance from ffmpeg_wasm package
//
//   _WebFfmpegWasmExporter(
//     this._recordingCompleter, {
//     required String outputBaseFileName,
//     required String outputFormat,
//     required double inputFpsForFFmpegCommand,
//     required String targetOutputResolution,
//   }) : _outputBaseFileName = outputBaseFileName,
//        _outputFormat = outputFormat,
//        _inputFpsForFFmpegCommand =
//            inputFpsForFFmpegCommand.isFinite && inputFpsForFFmpegCommand > 0
//                ? inputFpsForFFmpegCommand
//                : 15.0,
//        _targetOutputResolution = targetOutputResolution,
//        super();
//
//   @override
//   Future<void> init() async {
//     try {
//       // Create and load FFmpeg instance using the ffmpeg_wasm package
//       _ffmpeg = createFFmpeg(
//         CreateFFmpegParam(
//           log: true, // Enable console logging from ffmpeg.wasm
//           corePath:
//               'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js', // ST version
//           mainName: 'main',
//           // corePath:
//           //     'https://unpkg.com/@ffmpeg/core@0.11.0/dist/ffmpeg-core.js', // Example
//         ),
//       );
//       if (!_ffmpeg!.isLoaded()) {
//         await _ffmpeg!.load();
//       }
//       debugPrint("WebFfmpegWasmExporter: FFmpeg.wasm loaded and initialized.");
//       _isProcessingStarted = false;
//       _savedFrameFileNamesInWasm = [];
//       _fileNameFrameCounter = 0;
//     } catch (e) {
//       debugPrint("WebFfmpegWasmExporter: Error during ffmpeg.wasm init: $e");
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Failed to initialize WebAssembly FFmpeg: $e",
//           ),
//         );
//       }
//       throw Exception("Failed to initialize web exporter: $e");
//     }
//   }
//
//   @override
//   void onNewFrame(Frame frame) async {
//     // Can be async void
//     if (isControllerDisposedCheckCallback?.call() ?? false || _ffmpeg == null) {
//       frame.image.dispose();
//       return;
//     }
//     if (!_isProcessingStarted) _isProcessingStarted = true;
//
//     final frameNumberForFile = _fileNameFrameCounter++;
//     final fileNameInWasm =
//         'frame_${frameNumberForFile.toString().padLeft(5, '0')}.png';
//
//     try {
//       final ByteData? byteData = await frame.image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );
//       if (byteData != null) {
//         final Uint8List pngBytes = byteData.buffer.asUint8List();
//
//         // Use ffmpeg_wasm package API to write file
//         _ffmpeg!.writeFile(fileNameInWasm, pngBytes);
//         // debugPrint("WebFfmpegWasmExporter: Wrote $fileNameInWasm to MEMFS.");
//
//         _savedFrameFileNamesInWasm.add(fileNameInWasm);
//         onFrameStreamedCallback?.call(pngBytes);
//       } else {
//         debugPrint(
//           "WebFfmpegWasmExporter: Failed to get byteData for frame $fileNameInWasm.",
//         );
//       }
//     } catch (e) {
//       debugPrint(
//         "WebFfmpegWasmExporter: ERROR processing frame $fileNameInWasm for WASM: $e",
//       );
//     } finally {
//       frame.image.dispose();
//     }
//   }
//
//   @override
//   Future<void> finalizeRecording({
//     required double outputTargetActualFpsFromController,
//   }) async {
//     if (_ffmpeg == null || _savedFrameFileNamesInWasm.isEmpty) {
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "FFmpeg not loaded or no frames captured for web.",
//           ),
//         );
//       }
//       await _cleanupWasmSessionFiles([]);
//       return;
//     }
//
//     // final String outputWasmFileName = "output.${_outputFormat}";
//     final String outputWasmFileName = "output.webm";
//     final double outputFpsForCommand =
//         (outputTargetActualFpsFromController > 0 &&
//                 outputTargetActualFpsFromController.isFinite)
//             ? outputTargetActualFpsFromController
//             : _inputFpsForFFmpegCommand;
//     final double expectedDurationSecs =
//         _savedFrameFileNamesInWasm.length / _inputFpsForFFmpegCommand;
//     final String durationString = expectedDurationSecs.toStringAsFixed(3);
//     String resolutionFilterPart;
//     if (_targetOutputResolution.isNotEmpty &&
//         _targetOutputResolution.contains('x')) {
//       resolutionFilterPart =
//           "scale=$_targetOutputResolution:force_original_aspect_ratio=decrease,pad=$_targetOutputResolution:(ow-iw)/2:(oh-ih)/2:color=black";
//     } else {
//       resolutionFilterPart =
//           "pad=width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=(ow-iw)/2:y=(oh-ih)/2:color=black";
//     }
//
//     // Construct command as List<String> or a single string for runCommand
//     // final String commandString =
//     //     '-framerate $_inputFpsForFFmpegCommand -i frame_%05d.png ' +
//     //     '-vf "vflip,${resolutionFilterPart},format=yuv420p" ' +
//     //     '-c:v libx264 -preset ultrafast -crf 28 ' + // Ensure libx264 is in your ffmpeg.wasm build
//     //     '-r $outputFpsForCommand -t $durationString ' +
//     //     outputWasmFileName;
//
//     String commandString =
//         '-framerate $_inputFpsForFFmpegCommand -i frame_%05d.png '
//         '-r $outputFpsForCommand -t $durationString '
//         '${outputWasmFileName}';
//
//     debugPrint(
//       "WebFfmpegWasmExporter: Executing FFmpeg WASM command: $commandString",
//     );
//
//     try {
//       // Use runCommand or run (which takes List<String>)
//       await _ffmpeg!.runCommand(
//         commandString,
//       ); // or _ffmpeg.run([...list of args...]);
//
//       final Uint8List outputBytes = _ffmpeg!.readFile(outputWasmFileName);
//
//       if (outputBytes.isNotEmpty) {
//         debugPrint(
//           "WebFfmpegWasmExporter: FFmpeg WASM encoding successful. Output size: ${outputBytes.length} bytes.",
//         );
//         if (!_recordingCompleter.isCompleted) {
//           _recordingCompleter.complete(
//             RecordingOutput(
//               rawData: outputBytes,
//               success: true,
//               suggestedFileName:
//                   '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}.${_outputFormat}',
//               userFriendlyMessage: "Video ready for download.",
//             ),
//           );
//         }
//       } else {
//         debugPrint(
//           "WebFfmpegWasmExporter: FFmpeg WASM encoding failed or produced empty output.",
//         );
//         if (!_recordingCompleter.isCompleted) {
//           _recordingCompleter.complete(
//             RecordingOutput(
//               success: false,
//               errorMessage: "FFmpeg WASM encoding failed (empty output).",
//               userFriendlyMessage: "Web video processing failed.",
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       debugPrint(
//         "WebFfmpegWasmExporter: Exception during FFmpeg WASM execution: $e",
//       );
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "FFmpeg WASM execution exception: $e",
//             userFriendlyMessage: "Web video processing error.",
//           ),
//         );
//       }
//     } finally {
//       await _cleanupWasmSessionFiles(
//         List.from(_savedFrameFileNamesInWasm)..add(outputWasmFileName),
//       );
//       _isProcessingStarted = false;
//       _savedFrameFileNamesInWasm = [];
//       _fileNameFrameCounter = 0;
//     }
//   }
//
//   Future<void> _cleanupWasmSessionFiles(List<String> filesToClean) async {
//     if (_ffmpeg != null && filesToClean.isNotEmpty) {
//       debugPrint(
//         "WebFfmpegWasmExporter: Cleaning up ${filesToClean.length} WASM files.",
//       );
//       for (final fileName in filesToClean) {
//         try {
//           _ffmpeg!.unlink(fileName);
//         } catch (e) {
//           /* ignore if file not found during cleanup */
//         }
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     debugPrint("WebFfmpegWasmExporter: dispose() called.");
//     if (!_recordingCompleter.isCompleted) {
//       _recordingCompleter.complete(
//         RecordingOutput(
//           success: false,
//           errorMessage: "Exporter disposed prematurely.",
//           userFriendlyMessage: "Recording cancelled.",
//         ),
//       );
//     }
//     // The readme says: "Do not call exit if you want to reuse same ffmpeg instance"
//     // "When you call exit the temporary files are deleted from MEMFS"
//     // If we want to ensure cleanup and not reuse this specific _ffmpeg instance for a *new* recording session,
//     // calling exit() might be appropriate here. Or, manage cleanup with _cleanupWasmSessionFiles.
//     // If _ffmpeg instance is per-recording session (recreated in controller.startRecording -> exporter.init), then exit() is fine.
//     _ffmpeg?.exit(); // This should clean MEMFS.
//     _ffmpeg = null;
//     _isProcessingStarted = false;
//     _savedFrameFileNamesInWasm = [];
//     _fileNameFrameCounter = 0;
//   }
// }
//
// // --- Main Controller ---
// class WidgetCaptureXPlusController extends ChangeNotifier {
//   ScreenRecorderController? _nativeScreenRecorderController;
//   IWidgetCaptureXExporter? _exporter; // Use the interface type
//   Completer<RecordingOutput>? _recordingCompleter;
//
//   RecordingState _recordingState = RecordingState.idle;
//   RecordingState get recordingState => _recordingState;
//   RecordingOutput? _lastOutput;
//   RecordingOutput? get lastOutput => _lastOutput;
//   String? _currentError;
//   String? get currentError => _currentError;
//
//   final double pixelRatio;
//   final int skipFramesBetweenCaptures;
//   final String outputBaseFileName;
//   final String outputFormat;
//   final double targetOutputFps;
//   final String targetOutputResolution;
//
//   bool _isDisposed = false;
//
//   late StreamController<Uint8List> _frameStreamController;
//   Stream<Uint8List> get frameStream => _frameStreamController.stream;
//
//   ScreenRecorderController get activeScreenRecorderController {
//     _nativeScreenRecorderController ??= ScreenRecorderController();
//     return _nativeScreenRecorderController!;
//   }
//
//   WidgetCaptureXPlusController({
//     this.pixelRatio = 1.0,
//     this.skipFramesBetweenCaptures = 2,
//     this.outputBaseFileName = "widget_capture",
//     this.outputFormat = "mp4",
//     this.targetOutputFps = 30.0,
//     this.targetOutputResolution = "",
//   }) {
//     _frameStreamController = StreamController<Uint8List>.broadcast();
//   }
//
//   void _updateState(
//     RecordingState newState, {
//     String? error,
//     RecordingOutput? output,
//   }) {
//     if (_isDisposed) return;
//     bool coreStateChanged =
//         _recordingState != newState || _currentError != error;
//     bool outputChanged =
//         (_lastOutput?.filePath != output?.filePath) ||
//         (_lastOutput?.rawData?.length != output?.rawData?.length) ||
//         (_lastOutput?.success != output?.success);
//     if (!coreStateChanged &&
//         !outputChanged &&
//         _lastOutput?.userFriendlyMessage == output?.userFriendlyMessage) {
//       return;
//     }
//     _recordingState = newState;
//     _currentError = error;
//     if (output != null) _lastOutput = output;
//     if (error != null) debugPrint("WidgetCaptureXController Error: $error");
//     notifyListeners();
//   }
//
//   Future<void> startRecording({
//     Duration initialDelay = const Duration(milliseconds: 200),
//   }) async {
//     if (_isDisposed ||
//         _recordingState == RecordingState.recording ||
//         _recordingState == RecordingState.preparing) {
//       return;
//     }
//
//     _updateState(RecordingState.preparing);
//     _lastOutput = null;
//     _currentError = null;
//
//     if (_frameStreamController.isClosed) {
//       _frameStreamController = StreamController<Uint8List>.broadcast();
//     }
//     _recordingCompleter = Completer<RecordingOutput>();
//
//     const double assumedDeviceFps = 60.0;
//     final double actualCaptureInputFps =
//         assumedDeviceFps / (1 + skipFramesBetweenCaptures);
//     final double inputFpsForFFmpegCommand = actualCaptureInputFps;
//
//     String currentOutputFormat = outputFormat;
//     // Example: Prefer 'webm' for web if output is mp4, as h264 in wasm can be tricky
//     // if (kIsWeb && outputFormat.toLowerCase() == "mp4") {
//     //   currentOutputFormat = "webm";
//     //   debugPrint("WidgetCaptureXController: Web platform, suggesting output format 'webm'.");
//     // }
//
//     if (kIsWeb) {
//       debugPrint(
//         "WidgetCaptureXController: Initializing Web Exporter using ffmpeg_wasm package.",
//       );
//       _exporter = _WebFfmpegWasmExporter(
//         _recordingCompleter!,
//         outputBaseFileName: outputBaseFileName,
//         outputFormat: currentOutputFormat,
//         inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
//         targetOutputResolution: targetOutputResolution,
//       );
//     } else {
//       debugPrint("WidgetCaptureXController: Initializing Native Exporter.");
//       _exporter = _NativeFfmpegExporter(
//         _recordingCompleter!,
//         outputBaseFileName: outputBaseFileName,
//         outputFormat: currentOutputFormat,
//         inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
//         targetOutputResolution: targetOutputResolution,
//       );
//     }
//
//     _exporter!.isControllerDisposedCheckCallback = () => _isDisposed;
//     _exporter!.onFrameStreamedCallback = (Uint8List frameBytes) {
//       if (!_frameStreamController.isClosed) {
//         _frameStreamController.add(frameBytes);
//       }
//     };
//
//     try {
//       await _exporter!.init();
//       if (_isDisposed) {
//         _exporter?.dispose();
//         return;
//       }
//
//       _nativeScreenRecorderController = ScreenRecorderController(
//         exporter:
//             _exporter!, // Pass the IWidgetCaptureXExporter (which is an Exporter)
//         pixelRatio: pixelRatio,
//         skipFramesBetweenCaptures: skipFramesBetweenCaptures,
//       );
//       notifyListeners();
//
//       await Future.delayed(initialDelay);
//       if (_isDisposed) {
//         _exporter?.dispose();
//         return;
//       }
//
//       _nativeScreenRecorderController!.start();
//       _updateState(RecordingState.recording);
//       debugPrint(
//         "WidgetCaptureXController: Recording started. Platform: ${kIsWeb ? "Web" : "Native"}. Input FPS for FFmpeg: $inputFpsForFFmpegCommand. Target output FPS: $targetOutputFps",
//       );
//     } catch (e) {
//       final errMessage = "Failed to start recording: ${e.toString()}";
//       _updateState(RecordingState.error, error: errMessage);
//       if (!(_recordingCompleter?.isCompleted ?? true)) {
//         _recordingCompleter!.complete(
//           RecordingOutput(success: false, errorMessage: errMessage),
//         );
//       }
//       _exporter?.dispose();
//       _exporter = null;
//     }
//   }
//
//   Future<RecordingOutput?> stopRecording() async {
//     if (_isDisposed) {
//       return RecordingOutput(
//         success: false,
//         errorMessage: "Controller disposed.",
//       );
//     }
//     if (_recordingState != RecordingState.recording) {
//       if (_recordingState == RecordingState.preparing &&
//           _recordingCompleter != null &&
//           !_recordingCompleter!.isCompleted) {
//         _recordingCompleter!.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Recording stopped during preparation.",
//           ),
//         );
//         _exporter?.dispose();
//         _exporter = null;
//       }
//       if (_recordingState != RecordingState.error &&
//           _recordingState != RecordingState.completed &&
//           _recordingState != RecordingState.stopping) {
//         _updateState(RecordingState.idle);
//       }
//       return _lastOutput;
//     }
//     _updateState(RecordingState.stopping);
//     try {
//       _nativeScreenRecorderController?.stop();
//       if (_exporter != null) {
//         await _exporter!.finalizeRecording(
//           outputTargetActualFpsFromController: targetOutputFps,
//         );
//       } else {
//         throw Exception("Exporter was null during stopRecording.");
//       }
//       final result = await _recordingCompleter!.future;
//       _updateState(
//         RecordingState.completed,
//         output: result,
//         error: result.success ? null : result.errorMessage,
//       );
//       return result;
//     } catch (e) {
//       final errMessage = "Failed to stop/process recording: ${e.toString()}";
//       _updateState(RecordingState.error, error: errMessage);
//       if (!(_recordingCompleter?.isCompleted ?? true)) {
//         _recordingCompleter!.complete(
//           RecordingOutput(success: false, errorMessage: errMessage),
//         );
//       }
//       return RecordingOutput(success: false, errorMessage: errMessage);
//     } finally {
//       _exporter?.dispose();
//       _exporter = null;
//       _nativeScreenRecorderController = null;
//     }
//   }
//
//   @override
//   void dispose() {
//     if (_isDisposed) return;
//     _isDisposed = true;
//     debugPrint("WidgetCaptureXController: dispose() called.");
//     if (_recordingState == RecordingState.recording ||
//         _recordingState == RecordingState.stopping ||
//         _recordingState == RecordingState.preparing) {
//       _nativeScreenRecorderController?.stop();
//     }
//     _exporter?.dispose();
//     _exporter = null;
//     _nativeScreenRecorderController = null;
//     if (!_frameStreamController.isClosed) {
//       _frameStreamController.close();
//     }
//     super.dispose();
//   }
// }

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

  bool _isDisposedInternally = false; // MODIFIED: Internal disposed flag

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
    if (_isDisposedInternally) {
      throw Exception("Exporter is already disposed.");
    }
    try {
      final tempDirFromProvider = await getTemporaryDirectory();
      _tempDir = Directory(
        '${tempDirFromProvider?.path}/wcx_frames_${DateTime.now().millisecondsSinceEpoch}',
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
      debugPrint("NativeFfmpegExporter: Error during init: $e");
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Failed to init native storage: $e",
          ),
        );
      }
      throw Exception("Failed to init native exporter: $e");
    }
  }

  @override
  void onNewFrame(Frame frame) {
    if (_isDisposedInternally ||
        (isControllerDisposedCheckCallback?.call() ?? false) ||
        _tempDir == null) {
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
    // Capture _tempDir at the start of the method, as it might be nullified by a concurrent dispose.
    Directory? capturedTempDir = _tempDir;

    try {
      // Re-check disposal status and capturedTempDir validity before expensive operations
      if (_isDisposedInternally ||
          (isControllerDisposedCheckCallback?.call() ?? false) ||
          capturedTempDir == null ||
          !await capturedTempDir.exists()) {
        // Check existence of the captured directory path
        frame.image.dispose();
        return false;
      }

      // MODIFIED: Increased padding for frame numbers
      final frameNumberStr = frameNumberForFile.toString().padLeft(7, '0');
      final filePath = '${capturedTempDir.path}/frame_$frameNumberStr.png';
      final File frameFile = File(filePath);
      final ByteData? byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        // Final check before writing
        if (_isDisposedInternally ||
            (isControllerDisposedCheckCallback?.call() ?? false)) {
          frame.image.dispose();
          return false;
        }
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        await frameFile.writeAsBytes(pngBytes, flush: true);
        onFrameStreamedCallback?.call(pngBytes);
        success = true;
      }
    } catch (e) {
      // More specific error handling for PathNotFound could be added here if it persists
      // For example, checking if `e` is a FileSystemException with osError.errorCode == 2
      // and if `_isDisposedInternally` is true, to identify if it's a race condition artifact.
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
    if (_isDisposedInternally) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Finalizing on a disposed exporter.",
          ),
        );
      }
      return;
    }
    if (_recordingCompleter.isCompleted) {
      debugPrint(
        "NativeFfmpegExporter: Finalize called but recording completer is already done.",
      );
      // Ensure cleanup if somehow missed, though _performFullCleanup should handle _tempDir null state.
      await _performFullCleanup();
      return;
    }

    debugPrint("NativeFfmpegExporter: Finalizing. Waiting for frame saves...");
    List<bool> saveResults = [];
    if (_pendingFrameSaveFutures.isNotEmpty) {
      try {
        saveResults = await Future.wait(_pendingFrameSaveFutures);
      } catch (e) {
        debugPrint(
          "NativeFfmpegExporter: Error waiting for pending frame saves: $e",
        );
        // Ensure all futures are caught if one throws, fill with false
        saveResults = List<bool>.filled(_pendingFrameSaveFutures.length, false);
      }
    }
    // Clear list immediately after waiting, as they are now processed or failed.
    _pendingFrameSaveFutures.clear();
    _savedFrameCount = saveResults.where((s) => s).length;

    debugPrint(
      "NativeFfmpegExporter: Frame saves complete. Saved frames: $_savedFrameCount",
    );

    Directory? currentTempDir =
        _tempDir; // Capture before any potential nullification by dispose

    if (currentTempDir == null || _savedFrameCount == 0) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage:
                _savedFrameCount == 0
                    ? "No frames were successfully saved for native processing."
                    : "Temporary directory missing for native processing.",
          ),
        );
      }
      await _performFullCleanup(); // MODIFIED: Centralized cleanup call
      return;
    }

    final Directory? appDocDir = await getApplicationDocumentsDirectory();
    final String intermediateOutputFileName =
        '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}_temp.${_outputFormat}';
    final String intermediateOutputFilePath =
        '${appDocDir?.path}/$intermediateOutputFileName';
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

    // MODIFIED: Updated frame pattern to %07d
    final String ffmpegCommand =
        '-framerate $_inputFpsForFFmpegCommand -i "${currentTempDir.path}/frame_%07d.png" -vf "${resolutionFilterPart},format=yuv420p" -c:v libx264 -preset ultrafast -crf 23 -r $outputFpsForCommand -t $durationString "$intermediateOutputFilePath"';
    debugPrint("NativeFfmpegExporter: Executing FFmpeg: $ffmpegCommand");
    String finalSavedPath = intermediateOutputFilePath;
    String? userMessage;

    try {
      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();
      final logs =
          await session
              .getAllLogsAsString(); // Call this regardless of success to aid debugging
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
              // Attempt to delete the intermediate file after successful copy
              try {
                await originalFile.delete();
              } catch (e_del_int) {
                debugPrint(
                  "NativeFfmpegExporter: Could not delete intermediate file: $e_del_int",
                );
              }
              finalSavedPath = publicFilePath;
              userMessage = "Video saved to Downloads: $publicFileName";
            } else {
              userMessage =
                  "Internal video ready, but copy to Downloads failed (source missing).";
              finalSavedPath =
                  intermediateOutputFilePath; // Fallback to intermediate
            }
          } else {
            userMessage =
                "Video in app storage (Downloads directory not found).";
          }
        } catch (e_copy) {
          userMessage =
              "Video in app storage (Error copying to Downloads: $e_copy).";
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
              errorMessage:
                  "FFmpeg failed. Code: ${returnCode?.getValue()}. Logs: $logs",
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
      debugPrint(
        "NativeFfmpegExporter: Finalize recording's finally block executing.",
      );
      await _performFullCleanup(); // MODIFIED: Centralized cleanup call
    }
  }

  // MODIFIED: New helper to only clear futures and nullify tempDir reference
  Future<void> _clearFrameFuturesAndNullifyTempDir() async {
    _pendingFrameSaveFutures.clear(); // Stop tracking new/pending operations
    if (_tempDir != null) {
      // Nullify _tempDir so no NEW operations try to use it via this instance.
      // This doesn't delete the directory from disk yet.
      debugPrint(
        "NativeFfmpegExporter: Nullifying temp directory reference: ${_tempDir!.path}",
      );
      _tempDir = null;
    }
  }

  // MODIFIED: New helper for actual disk deletion
  Future<void> _deleteTempDirectoryFromDisk(Directory? dirToDelete) async {
    if (dirToDelete != null) {
      debugPrint(
        "NativeFfmpegExporter: Attempting to delete directory from disk: ${dirToDelete.path}",
      );
      try {
        if (await dirToDelete.exists()) {
          await dirToDelete.delete(recursive: true);
          debugPrint(
            "NativeFfmpegExporter: Temp directory ${dirToDelete.path} deleted from disk.",
          );
        } else {
          debugPrint(
            "NativeFfmpegExporter: Temp directory ${dirToDelete.path} not found for deletion.",
          );
        }
      } catch (e) {
        debugPrint(
          "NativeFfmpegExporter: Error deleting temp directory ${dirToDelete.path} from disk: $e",
        );
      }
    } else {
      debugPrint(
        "NativeFfmpegExporter: No directory to delete from disk (dirToDelete was null).",
      );
    }
  }

  // MODIFIED: Renamed and refactored original _cleanupTempDirAndFutures
  Future<void> _performFullCleanup() async {
    debugPrint("NativeFfmpegExporter: Performing full cleanup.");
    Directory? dirCache =
        _tempDir; // Cache _tempDir before nullifying by the clear method
    await _clearFrameFuturesAndNullifyTempDir(); // Clear futures and nullify the instance's _tempDir
    await _deleteTempDirectoryFromDisk(
      dirCache,
    ); // Attempt to delete the actual directory using the cached path
  }

  @override
  void dispose() {
    debugPrint(
      "NativeFfmpegExporter: dispose() called. Internal disposed state: $_isDisposedInternally",
    );
    if (_isDisposedInternally) return;
    _isDisposedInternally = true;

    // The isControllerDisposedCheckCallback should reflect this change.
    // (The callback provided by WidgetCaptureXPlusController already checks its own _isDisposed flag)

    // Stop new work and nullify tempDir reference immediately.
    // This helps prevent new frames from trying to use a directory that might be cleaned up,
    // or an exporter that is no longer valid.
    _clearFrameFuturesAndNullifyTempDir(); // MODIFIED

    // If recording isn't fully completed, signal abortion.
    // finalizeRecording's finally block is responsible for actual disk cleanup for that session.
    // If finalizeRecording never runs its finally block (e.g., controller disposed before stop),
    // the temp dir for *that session* might be orphaned. This is preferable to PathNotFound.
    if (!_recordingCompleter.isCompleted) {
      _recordingCompleter.complete(
        RecordingOutput(
          success: false,
          errorMessage: "Exporter disposed prematurely.",
          userFriendlyMessage: "Recording cancelled.",
        ),
      );
    }
    debugPrint("NativeFfmpegExporter: dispose() finished.");
  }
}

// --- Web FFmpeg.wasm Exporter (Using ffmpeg_wasm package) ---
class _WebFfmpegWasmExporter extends Exporter
    implements IWidgetCaptureXExporter {
  final Completer<RecordingOutput> _recordingCompleter;
  final String _outputBaseFileName;
  final String
  _outputFormat; // Note: ffmpeg.wasm might prefer specific formats like webm for h264
  final double _inputFpsForFFmpegCommand;
  final String _targetOutputResolution;

  @override
  bool Function()? isControllerDisposedCheckCallback;
  @override
  void Function(Uint8List frameBytes)? onFrameStreamedCallback;

  List<String> _savedFrameFileNamesInWasm = [];
  bool _isProcessingStarted = false;
  int _fileNameFrameCounter = 0;
  bool _isDisposedInternally = false;

  FFmpeg? _ffmpeg;

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
    if (_isDisposedInternally) {
      throw Exception("WebExporter is already disposed.");
    }
    try {
      _ffmpeg = createFFmpeg(
        CreateFFmpegParam(
          log: true, // Enable console logging from ffmpeg.wasm
          corePath:
              'https://unpkg.com/@ffmpeg/core-st@0.11.1/dist/ffmpeg-core.js', // ST version
          mainName: 'main',
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
    if (_isDisposedInternally ||
        (isControllerDisposedCheckCallback?.call() ?? false) ||
        _ffmpeg == null ||
        !_ffmpeg!.isLoaded()) {
      frame.image.dispose();
      return;
    }
    if (!_isProcessingStarted) _isProcessingStarted = true;

    final frameNumberForFile = _fileNameFrameCounter++;
    // MODIFIED: Increased padding for frame numbers
    final fileNameInWasm =
        'frame_${frameNumberForFile.toString().padLeft(7, '0')}.png';

    try {
      final ByteData? byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        // Final check before writing
        if (_isDisposedInternally ||
            (isControllerDisposedCheckCallback?.call() ?? false)) {
          frame.image.dispose();
          return;
        }
        _ffmpeg!.writeFile(fileNameInWasm, pngBytes);
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
    if (_isDisposedInternally) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "Finalizing on a disposed web exporter.",
          ),
        );
      }
      return;
    }
    if (_recordingCompleter.isCompleted) {
      debugPrint(
        "WebFfmpegWasmExporter: Finalize called but recording completer is already done.",
      );
      await _cleanupWasmSessionFiles(
        List.from(_savedFrameFileNamesInWasm)..add("output.$_outputFormat"),
      ); // Attempt cleanup if missed
      return;
    }

    if (_ffmpeg == null ||
        !_ffmpeg!.isLoaded() ||
        _savedFrameFileNamesInWasm.isEmpty) {
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage:
                _savedFrameFileNamesInWasm.isEmpty
                    ? "No frames captured for web processing."
                    : "FFmpeg not loaded for web processing.",
          ),
        );
      }
      await _cleanupWasmSessionFiles([]); // Ensure cleanup even on early exit
      return;
    }

    // For web, webm with vp9 is often more compatible or easier than mp4/h264 in wasm
    String currentOutputFormat =
        _outputFormat.toLowerCase() == "mp4" ? "webm" : _outputFormat;
    final String outputWasmFileName = "output.$currentOutputFormat";

    final double outputFpsForCommand =
        (outputTargetActualFpsFromController > 0 &&
                outputTargetActualFpsFromController.isFinite)
            ? outputTargetActualFpsFromController
            : _inputFpsForFFmpegCommand;
    final double expectedDurationSecs =
        _savedFrameFileNamesInWasm.length / _inputFpsForFFmpegCommand;
    final String durationString = expectedDurationSecs.toStringAsFixed(3);
    String
    resolutionFilterPart; // Not used in the simplified web command below, but kept for potential future use

    // MODIFIED: Updated frame pattern to %07d
    // Simplified command for web, focusing on basic conversion.
    // For webm/vp9: '-c:v libvpx-vp9 -crf 30 -b:v 0' (CRF mode)
    // For webm/av1: '-c:v libaom-av1 -crf 30 -b:v 0 -cpu-used 4' (slower, better compression)
    // Using simple conversion to webm (often defaults to vp8 or vp9 based on ffmpeg.wasm build)
    String commandString =
        '-framerate $_inputFpsForFFmpegCommand -i frame_%07d.png '
        '-r $outputFpsForCommand -t $durationString ';

    if (currentOutputFormat == "webm") {
      commandString +=
          '-c:v libvpx-vp9 -deadline realtime -cpu-used 8 -crf 35 -b:v 0 '; // VP9 with faster settings
    } else if (currentOutputFormat == "gif") {
      commandString += ''; // No specific video codec for GIF
    } else {
      // E.g. mp4, though h264 might need a specific ffmpeg.wasm core with the encoder
      commandString += '-c:v libx264 -preset ultrafast -crf 28 ';
    }
    commandString += outputWasmFileName;

    debugPrint(
      "WebFfmpegWasmExporter: Executing FFmpeg WASM command: $commandString",
    );
    List<String> filesToCleanInitially = List.from(_savedFrameFileNamesInWasm)
      ..add(outputWasmFileName);

    try {
      // Use run or runCommand (runCommand is newer and simpler for single string commands)
      await _ffmpeg!.runCommand(commandString);

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
                  '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}.$currentOutputFormat',
              userFriendlyMessage: "Video ready for download.",
            ),
          );
        }
      } else {
        debugPrint(
          "WebFfmpegWasmExporter: FFmpeg WASM encoding failed or produced empty output.",
        );
        String? logs = "No logs captured.";
        if (!_recordingCompleter.isCompleted) {
          _recordingCompleter.complete(
            RecordingOutput(
              success: false,
              errorMessage:
                  "FFmpeg WASM encoding failed (empty output). Logs: $logs",
              userFriendlyMessage: "Web video processing failed.",
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(
        "WebFfmpegWasmExporter: Exception during FFmpeg WASM execution: $e",
      );
      String? logs = "No logs captured.";
      if (!_recordingCompleter.isCompleted) {
        _recordingCompleter.complete(
          RecordingOutput(
            success: false,
            errorMessage: "FFmpeg WASM execution exception: $e. Logs: $logs",
            userFriendlyMessage: "Web video processing error.",
          ),
        );
      }
    } finally {
      await _cleanupWasmSessionFiles(filesToCleanInitially);
      _isProcessingStarted =
          false; // Reset for potential re-use if controller allows
      _savedFrameFileNamesInWasm = [];
      _fileNameFrameCounter = 0;
    }
  }

  Future<void> _cleanupWasmSessionFiles(List<String> filesToClean) async {
    if (_ffmpeg != null && _ffmpeg!.isLoaded() && filesToClean.isNotEmpty) {
      debugPrint(
        "WebFfmpegWasmExporter: Cleaning up ${filesToClean.length} WASM files.",
      );
      for (final fileName in filesToClean) {
        try {
          // Check if file exists before unlinking, though unlink might not throw if not found
          // List<Dirent> dirContents = _ffmpeg!.readDir(".");
          // if (dirContents.any((dirent) => dirent.name == fileName && !dirent.isDir)) {
          _ffmpeg!.unlink(fileName);
          // }
        } catch (e) {
          debugPrint(
            "WebFfmpegWasmExporter: Error unlinking $fileName from MEMFS (may be benign): $e",
          );
        }
      }
    }
  }

  @override
  void dispose() {
    debugPrint(
      "WebFfmpegWasmExporter: dispose() called. Internal disposed state: $_isDisposedInternally",
    );
    if (_isDisposedInternally) return;
    _isDisposedInternally = true;

    // The ffmpeg.wasm `exit()` method cleans up MEMFS and terminates the WebWorker.
    // It's generally good to call if you are done with the FFmpeg instance.
    try {
      if (_ffmpeg != null && _ffmpeg!.isLoaded()) {
        _ffmpeg!.exit(); // Cleans MEMFS and terminates worker
        debugPrint("WebFfmpegWasmExporter: FFmpeg instance exited.");
      }
    } catch (e) {
      debugPrint("WebFfmpegWasmExporter: Error exiting FFmpeg instance: $e");
    }
    _ffmpeg = null; // Release the instance

    if (!_recordingCompleter.isCompleted) {
      _recordingCompleter.complete(
        RecordingOutput(
          success: false,
          errorMessage: "Web exporter disposed prematurely.",
          userFriendlyMessage: "Recording cancelled.",
        ),
      );
    }
    _isProcessingStarted = false;
    _savedFrameFileNamesInWasm = [];
    _fileNameFrameCounter = 0;
    debugPrint("WebFfmpegWasmExporter: dispose() finished.");
  }
}

// --- Main Controller ---
// WidgetCaptureXPlusController remains largely the same.
// Ensure its _isDisposed flag is correctly used by the exporter's isControllerDisposedCheckCallback.
class WidgetCaptureXPlusController extends ChangeNotifier {
  ScreenRecorderController? _nativeScreenRecorderController;
  IWidgetCaptureXExporter? _exporter;
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

  bool _isDisposed = false; // This is the controller's disposed flag

  late StreamController<Uint8List> _frameStreamController;
  Stream<Uint8List> get frameStream => _frameStreamController.stream;

  // Optional: Expose a way to get the native controller if needed for direct manipulation,
  // but generally, interaction should be through WidgetCaptureXPlusController methods.
  ScreenRecorderController get activeScreenRecorderController {
    _nativeScreenRecorderController ??= ScreenRecorderController(
      // Default init, will be re-configured in startRecording if needed
      // pixelRatio: pixelRatio,
      // skipFramesBetweenCaptures: skipFramesBetweenCaptures,
    );
    return _nativeScreenRecorderController!;
  }

  WidgetCaptureXPlusController({
    this.pixelRatio = 1.0, // Default 1.0, adjust as needed
    this.skipFramesBetweenCaptures =
        0, // Default 0 for capturing every frame subject to device limits
    this.outputBaseFileName = "widget_capture",
    this.outputFormat = "mp4", // Default mp4, webm for web might be more robust
    this.targetOutputFps = 15.0, // Default 15fps, adjust as needed
    this.targetOutputResolution = "", // e.g. "640x480" or "" for original
  }) {
    _frameStreamController = StreamController<Uint8List>.broadcast();
  }

  void _updateState(
    RecordingState newState, {
    String? error,
    RecordingOutput? output,
  }) {
    if (_isDisposed &&
        newState != RecordingState.idle &&
        newState != RecordingState.completed &&
        newState != RecordingState.error) {
      // Allow final states after dispose
      debugPrint(
        "WidgetCaptureXController: Attempted to update state on disposed controller to $newState. Ignoring.",
      );
      return;
    }
    // Prevent re-notifying if nothing substantial changed
    bool coreStateChanged =
        _recordingState != newState || _currentError != error;
    bool outputChanged =
        (_lastOutput?.filePath != output?.filePath) ||
        (_lastOutput?.rawData?.length != output?.rawData?.length) ||
        (_lastOutput?.success != output?.success);
    if (!coreStateChanged &&
        !outputChanged &&
        _lastOutput?.userFriendlyMessage == output?.userFriendlyMessage) {
      return;
    }

    _recordingState = newState;
    _currentError = error;
    if (output != null) _lastOutput = output;

    if (error != null)
      debugPrint("WidgetCaptureXController Error: $error. State: $newState");
    if (_isDisposed && !_frameStreamController.isClosed) {
      // If controller is disposed, don't notify listeners as they might be gone.
      // Log instead.
      debugPrint(
        "WidgetCaptureXController: State updated post-dispose. New state: $newState, Output: $output, Error: $error",
      );
    } else if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> startRecording({
    Duration initialDelay = const Duration(milliseconds: 200),
  }) async {
    if (_isDisposed) {
      debugPrint(
        "WidgetCaptureXController: startRecording called on disposed controller.",
      );
      return;
    }
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.preparing) {
      debugPrint(
        "WidgetCaptureXController: Recording already in progress or preparing.",
      );
      return;
    }

    _updateState(RecordingState.preparing);
    _lastOutput = null;
    _currentError = null;

    if (_frameStreamController.isClosed) {
      _frameStreamController = StreamController<Uint8List>.broadcast();
    }
    _recordingCompleter = Completer<RecordingOutput>();

    // Use targetOutputFps for FFmpeg input framerate if it's what we aim for the captured frames to represent.
    // Or, calculate based on skipFrames if that's more accurate for the input stream.
    // For simplicity, let's use targetOutputFps as the intended input rate for FFmpeg processing.
    // If skipFramesBetweenCaptures is high, actual captured FPS might be lower.
    // The exporter's _inputFpsForFFmpegCommand will use this.
    // A more accurate `inputFpsForFFmpegCommand` might be:
    // const double assumedDeviceFps = 60.0; // Or make this configurable
    // final double actualCaptureInputFps = assumedDeviceFps / (1 + skipFramesBetweenCaptures);
    // For now, let's assume targetOutputFps is a good proxy for the desired input rate to ffmpeg.
    final double inputFpsForFFmpegCommand = targetOutputFps;

    String currentOutputFormat = outputFormat;
    if (kIsWeb && outputFormat.toLowerCase() == "mp4") {
      // WebM with VP9/VP8 is generally more reliable with ffmpeg.wasm than MP4/H.264
      // unless a specific ffmpeg.wasm core with H.264 encoder is used.
      currentOutputFormat = "webm";
      debugPrint(
        "WidgetCaptureXController: Web platform, defaulting MP4 to WEBM output format for better compatibility.",
      );
    }

    if (kIsWeb) {
      debugPrint("WidgetCaptureXController: Initializing Web Exporter.");
      _exporter = _WebFfmpegWasmExporter(
        _recordingCompleter!,
        outputBaseFileName: outputBaseFileName,
        outputFormat: currentOutputFormat, // Use potentially adjusted format
        inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
        targetOutputResolution: targetOutputResolution,
      );
    } else {
      debugPrint("WidgetCaptureXController: Initializing Native Exporter.");
      _exporter = _NativeFfmpegExporter(
        _recordingCompleter!,
        outputBaseFileName: outputBaseFileName,
        outputFormat: currentOutputFormat, // Native usually handles mp4 well
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
        // Check again after await, in case dispose was called during init
        debugPrint(
          "WidgetCaptureXController: Disposed during exporter init. Cleaning up exporter.",
        );
        _exporter?.dispose(); // Dispose the partially initialized exporter
        _exporter = null;
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.complete(
            RecordingOutput(
              success: false,
              errorMessage:
                  "Recording aborted during initialization due to disposal.",
            ),
          );
        }
        _updateState(
          RecordingState.idle,
          error: "Recording aborted during initialization.",
        );
        return;
      }

      // Initialize or reconfigure the ScreenRecorderController
      _nativeScreenRecorderController = ScreenRecorderController(
        exporter: _exporter!,
        pixelRatio: pixelRatio,
        skipFramesBetweenCaptures: skipFramesBetweenCaptures,
      );
      // notifyListeners(); // Consider if this notify is needed here or if covered by _updateState

      await Future.delayed(initialDelay);
      if (_isDisposed) {
        // Check again after delay
        debugPrint(
          "WidgetCaptureXController: Disposed during initial delay. Cleaning up.",
        );
        _exporter?.dispose();
        _exporter = null;
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.complete(
            RecordingOutput(
              success: false,
              errorMessage:
                  "Recording aborted during initial delay due to disposal.",
            ),
          );
        }
        _updateState(
          RecordingState.idle,
          error: "Recording aborted during initial delay.",
        );
        return;
      }

      _nativeScreenRecorderController!.start();
      _updateState(RecordingState.recording);
      debugPrint(
        "WidgetCaptureXController: Recording started. Platform: ${kIsWeb ? "Web" : "Native"}. Input FPS for FFmpeg: $inputFpsForFFmpegCommand. Target output FPS: $targetOutputFps",
      );
    } catch (e) {
      final errMessage = "Failed to start recording: ${e.toString()}";
      debugPrint(
        errMessage,
      ); // Also print the error here for immediate visibility
      _updateState(RecordingState.error, error: errMessage);
      if (!(_recordingCompleter?.isCompleted ?? true)) {
        _recordingCompleter!.complete(
          RecordingOutput(success: false, errorMessage: errMessage),
        );
      }
      _exporter?.dispose(); // Ensure exporter is disposed on error
      _exporter = null;
    }
  }

  Future<RecordingOutput?> stopRecording() async {
    if (_isDisposed &&
        _recordingState != RecordingState.recording &&
        _recordingState != RecordingState.stopping) {
      debugPrint(
        "WidgetCaptureXController: stopRecording called on disposed controller that is not actively recording/stopping.",
      );
      return _lastOutput ??
          RecordingOutput(success: false, errorMessage: "Controller disposed.");
    }

    if (_recordingState != RecordingState.recording &&
        _recordingState != RecordingState.preparing) {
      debugPrint(
        "WidgetCaptureXController: Stop called but not in recording or preparing state. Current state: $_recordingState",
      );
      if (_recordingState == RecordingState.stopping &&
          _recordingCompleter != null) {
        debugPrint(
          "WidgetCaptureXController: Already stopping, returning current completer's future.",
        );
        return _recordingCompleter!
            .future; // Return the future of the ongoing stop operation
      }
      // If was preparing and stop is called, ensure completer is handled.
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
        _updateState(
          RecordingState.idle,
          error: "Recording stopped during preparation.",
        );
        return _lastOutput; // Or the newly completed output
      }
      if (_recordingState != RecordingState.error &&
          _recordingState != RecordingState.completed) {
        // Only transition to idle if not already in a terminal state from this flow or error
        _updateState(RecordingState.idle);
      }
      return _lastOutput;
    }

    // If it was preparing, but now we stop, it's like an early stop.
    if (_recordingState == RecordingState.preparing) {
      debugPrint(
        "WidgetCaptureXController: Recording stopped while preparing.",
      );
      // ScreenRecorder might not have started, exporter might be initializing.
      // Let dispose handle cleanup if it was an early exit.
      _nativeScreenRecorderController?.stop(); // Stop if it somehow started
      _exporter?.dispose(); // Dispose the exporter
      _exporter = null;
      if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
        _recordingCompleter!.complete(
          RecordingOutput(
            success: false,
            errorMessage:
                "Recording stopped before it fully started (during preparation).",
          ),
        );
      }
      _updateState(
        RecordingState.idle,
        error: "Recording stopped during preparation phase.",
      );
      return _lastOutput;
    }

    _updateState(RecordingState.stopping);
    RecordingOutput? result;
    try {
      _nativeScreenRecorderController?.stop(); // Stop frame capture

      if (_exporter != null) {
        // The exporter's finalizeRecording will complete the _recordingCompleter
        await _exporter!.finalizeRecording(
          outputTargetActualFpsFromController: targetOutputFps,
        );
      } else {
        // This case should ideally not be reached if recording was active
        if (!_recordingCompleter!.isCompleted) {
          _recordingCompleter!.complete(
            RecordingOutput(
              success: false,
              errorMessage: "Exporter was null during stopRecording.",
            ),
          );
        }
        debugPrint(
          "WidgetCaptureXController: Exporter was null during stopRecording. This should not happen if recording was active.",
        );
      }
      result =
          await _recordingCompleter!
              .future; // Wait for the final result from the exporter
      _updateState(
        result.success ? RecordingState.completed : RecordingState.error,
        output: result,
        error:
            result.success
                ? null
                : (result.errorMessage ?? "Unknown error during finalization."),
      );
    } catch (e) {
      final errMessage = "Failed to stop/process recording: ${e.toString()}";
      debugPrint(errMessage);
      if (!(_recordingCompleter?.isCompleted ?? true)) {
        _recordingCompleter!.complete(
          RecordingOutput(success: false, errorMessage: errMessage),
        );
      }
      // Get the result from the now-completed completer, even if it's an error.
      result =
          await _recordingCompleter?.future ??
          RecordingOutput(success: false, errorMessage: errMessage);
      _updateState(RecordingState.error, error: errMessage, output: result);
    } finally {
      // Exporter dispose is critical here.
      // If finalizeRecording threw an exception BEFORE its own finally block called _performFullCleanup,
      // the exporter's _tempDir might still exist if the dispose method was also not called or only nullified reference.
      // However, the refactored exporter's finalizeRecording always calls _performFullCleanup in its finally block.
      _exporter?.dispose();
      _exporter = null;
      // _nativeScreenRecorderController = null; // Keep instance if user might restart, or nullify if one-shot
      // For safety, let's nullify to ensure clean state for next startRecording
      _nativeScreenRecorderController = null;
      debugPrint(
        "WidgetCaptureXController: stopRecording finished. Final state: $_recordingState",
      );
    }
    return result;
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint(
      "WidgetCaptureXController: dispose() called. Current recording state: $_recordingState",
    );

    // If recording is in a state where it might be actively using the exporter or screen recorder
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.stopping ||
        _recordingState == RecordingState.preparing) {
      _nativeScreenRecorderController
          ?.stop(); // Attempt to stop ongoing capture
    }

    _exporter
        ?.dispose(); // Dispose the exporter, which should handle its internal state
    _exporter = null;
    _nativeScreenRecorderController = null; // Release screen recorder

    // If there's an active recording completer that hasn't been finished, complete it.
    if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
      _recordingCompleter!.complete(
        RecordingOutput(
          success: false,
          errorMessage:
              "Controller disposed during an incomplete recording operation.",
          userFriendlyMessage:
              "Recording cancelled due to controller disposal.",
        ),
      );
    }

    if (!_frameStreamController.isClosed) {
      _frameStreamController.close();
    }
    _updateState(
      RecordingState.idle,
      error: "Controller disposed.",
    ); // Update to a final state
    super
        .dispose(); // This will call notifyListeners one last time if not overridden to prevent it.
    debugPrint("WidgetCaptureXController: Controller fully disposed.");
  }
}
