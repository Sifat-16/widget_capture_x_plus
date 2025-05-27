// import 'dart:async';
// import 'dart:io'; // For File and Directory
// import 'dart:ui' as ui show ImageByteFormat;
//
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
// import 'package:flutter/foundation.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:screen_recorder/screen_recorder.dart'; // For ScreenRecorderController
//
// // --- Data Structures ---
// class RecordingOutput {
//   final String? filePath;
//   final Uint8List? rawData;
//   final bool success;
//   final String? errorMessage;
//   final String? userFriendlyMessage;
//
//   RecordingOutput({
//     this.filePath,
//     this.rawData,
//     this.success = true,
//     this.errorMessage,
//     this.userFriendlyMessage,
//   });
//
//   @override
//   String toString() {
//     return 'RecordingOutput(success: $success, filePath: $filePath, userMessage: $userFriendlyMessage, errorMessage: $errorMessage)';
//   }
// }
//
// enum RecordingState { idle, preparing, recording, stopping, completed, error }
//
// // --- Custom Exporter for FFmpeg ---
// class _WidgetCaptureXPlusExporter extends Exporter {
//   final Completer<RecordingOutput> _recordingCompleter;
//   final String _outputBaseFileName;
//   final String _outputFormat;
//   final double _inputFpsForFFmpegCommand; // FPS for FFmpeg's -framerate option
//   final String _targetOutputResolution;
//   final bool Function() _isControllerDisposedCheck;
//   final void Function(Uint8List frameBytes)? onFrameStreamed;
//
//   Directory? _tempDir;
//   int _savedFrameCount = 0; // Counts successfully saved frames
//   bool _isProcessingStarted = false;
//   List<Future<bool>> _pendingFrameSaveFutures = []; // To track save operations
//   int _fileNameFrameCounter = 0; // For unique filenames
//
//   _WidgetCaptureXPlusExporter(
//     this._recordingCompleter, {
//     required String outputBaseFileName,
//     required String outputFormat,
//     required double inputFpsForFFmpegCommand,
//     required String targetOutputResolution,
//     required bool Function() isControllerDisposedCheck,
//     this.onFrameStreamed,
//   }) : _outputBaseFileName = outputBaseFileName,
//        _outputFormat = outputFormat,
//        _inputFpsForFFmpegCommand =
//            inputFpsForFFmpegCommand.isFinite && inputFpsForFFmpegCommand > 0
//                ? inputFpsForFFmpegCommand
//                : 15.0, // Default if invalid
//        _targetOutputResolution = targetOutputResolution,
//        _isControllerDisposedCheck = isControllerDisposedCheck,
//        super();
//
//   Future<void> init() async {
//     try {
//       final appTempDir = await getTemporaryDirectory();
//       _tempDir = Directory(
//         '${appTempDir.path}/wcx_frames_${DateTime.now().millisecondsSinceEpoch}',
//       );
//       await _tempDir!.create(recursive: true);
//       _savedFrameCount = 0;
//       _fileNameFrameCounter = 0;
//       _isProcessingStarted = false;
//       _pendingFrameSaveFutures = []; // Reset list
//       debugPrint(
//         "WidgetCaptureXExporter: Temp directory created at ${_tempDir!.path}",
//       );
//     } catch (e) {
//       debugPrint("WidgetCaptureXExporter: Error creating temp directory: $e");
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Failed to initialize storage: $e",
//           ),
//         );
//       }
//       throw Exception("Failed to initialize exporter: $e");
//     }
//   }
//
//   // This method is called synchronously by ScreenRecorderController
//   @override
//   void onNewFrame(Frame frame) {
//     // DO NOT call super.onNewFrame()
//     if (_isControllerDisposedCheck() || _tempDir == null) {
//       debugPrint(
//         "WidgetCaptureXExporter: Controller disposed or tempDir null. Disposing image.",
//       );
//       frame.image.dispose();
//       return;
//     }
//
//     if (!_isProcessingStarted) {
//       _isProcessingStarted = true;
//       debugPrint(
//         "WidgetCaptureXExporter: First frame received by onNewFrame, queuing for processing.",
//       );
//     }
//
//     // Increment for filename uniqueness, add save operation to queue
//     final currentFileNumber = _fileNameFrameCounter++;
//     final saveFuture = _processAndSaveFrame(frame, currentFileNumber);
//     _pendingFrameSaveFutures.add(saveFuture);
//   }
//
//   Future<bool> _processAndSaveFrame(Frame frame, int frameNumberForFile) async {
//     // This method now handles the async work for one frame
//     // It's called from onNewFrame but its Future is added to a list
//     bool success = false;
//     try {
//       if (_isControllerDisposedCheck() ||
//           _tempDir == null ||
//           !await _tempDir!.exists()) {
//         debugPrint(
//           "WidgetCaptureXExporter (_processAndSaveFrame): Pre-conditions not met. Aborting save.",
//         );
//         return false; // Indicate failure
//       }
//
//       final frameNumberStr = frameNumberForFile.toString().padLeft(5, '0');
//       final filePath = '${_tempDir!.path}/frame_$frameNumberStr.png';
//       final File frameFile = File(filePath);
//
//       final ByteData? byteData = await frame.image.toByteData(
//         format: ui.ImageByteFormat.png,
//       );
//
//       if (byteData != null) {
//         final Uint8List pngBytes = byteData.buffer.asUint8List();
//         await frameFile.writeAsBytes(pngBytes, flush: true);
//         onFrameStreamed?.call(pngBytes);
//         success = true;
//       } else {
//         debugPrint(
//           "WidgetCaptureXExporter: Failed to get byteData for frame $frameNumberStr.",
//         );
//       }
//     } catch (e) {
//       debugPrint(
//         "WidgetCaptureXExporter: ERROR writing frame (file $frameNumberForFile): $e",
//       );
//     } finally {
//       frame.image.dispose();
//     }
//     return success;
//   }
//
//   Future<void> finalizeRecording({
//     required double outputTargetActualFpsFromController,
//   }) async {
//     debugPrint(
//       "WidgetCaptureXExporter: Finalizing recording. Waiting for all pending frame saves to complete...",
//     );
//     if (_isControllerDisposedCheck()) {
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Controller disposed during finalization process.",
//           ),
//         );
//       }
//       await _cleanupAllPendingAndTempDir();
//       return;
//     }
//
//     List<bool> saveResults = [];
//     if (_pendingFrameSaveFutures.isNotEmpty) {
//       try {
//         saveResults = await Future.wait(_pendingFrameSaveFutures);
//       } catch (e) {
//         debugPrint(
//           "WidgetCaptureXExporter: Error awaiting pending frame saves: $e",
//         );
//       }
//     }
//     _pendingFrameSaveFutures.clear(); // Clear the list of futures
//
//     _savedFrameCount =
//         saveResults.where((s) => s).length; // Count only successful saves
//     debugPrint(
//       "WidgetCaptureXExporter: All frame save operations completed. Successfully saved frames for FFmpeg: $_savedFrameCount",
//     );
//
//     if (_tempDir == null) {
//       // Should have been caught by dispose check, but good to have
//       debugPrint(
//         "WidgetCaptureXExporter: Temp directory is null before FFmpeg. Aborting.",
//       );
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "Internal error: Temp directory lost.",
//           ),
//         );
//       }
//       await _cleanupAllPendingAndTempDir();
//       return;
//     }
//
//     if (_savedFrameCount == 0) {
//       debugPrint(
//         "WidgetCaptureXExporter: No frames were successfully saved to process with FFmpeg.",
//       );
//       if (!_recordingCompleter.isCompleted) {
//         _recordingCompleter.complete(
//           RecordingOutput(
//             success: false,
//             errorMessage: "No frames were captured/saved.",
//           ),
//         );
//       }
//       await _cleanupAllPendingAndTempDir();
//       return;
//     }
//
//     // --- Optional: List frames before FFmpeg (for debugging) ---
//     // (You can add your frame listing code here if needed)
//     // ---
//
//     final Directory appDocDir = await getApplicationDocumentsDirectory();
//     final String intermediateOutputFileName =
//         '${_outputBaseFileName}_${DateTime.now().millisecondsSinceEpoch}_temp.${_outputFormat}';
//     final String intermediateOutputFilePath =
//         '${appDocDir.path}/$intermediateOutputFileName';
//
//     final double outputFpsForCommand =
//         (outputTargetActualFpsFromController > 0 &&
//                 outputTargetActualFpsFromController.isFinite)
//             ? outputTargetActualFpsFromController
//             : _inputFpsForFFmpegCommand;
//
//     final double expectedDurationSecs =
//         _savedFrameCount / _inputFpsForFFmpegCommand;
//     final String durationString = expectedDurationSecs.toStringAsFixed(3);
//
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
//     final String ffmpegCommand =
//         '-framerate $_inputFpsForFFmpegCommand -i "${_tempDir!.path}/frame_%05d.png" ' +
//         '-vf "vflip,${resolutionFilterPart},format=yuv420p" ' +
//         '-c:v libx264 -preset ultrafast -crf 23 ' +
//         '-r $outputFpsForCommand ' +
//         '-t $durationString ' +
//         '"$intermediateOutputFilePath"';
//
//     debugPrint(
//       "WidgetCaptureXExporter: Executing FFmpeg command: $ffmpegCommand",
//     );
//
//     String finalSavedPath = intermediateOutputFilePath;
//     String? userMessage;
//
//     try {
//       final session = await FFmpegKit.execute(ffmpegCommand);
//       final returnCode = await session.getReturnCode();
//       final logs = await session.getAllLogsAsString();
//       debugPrint(
//         "WidgetCaptureXExporter: FFmpeg processing completed. Logs:\n$logs",
//       );
//
//       if (ReturnCode.isSuccess(returnCode)) {
//         // ... (Logic to copy to Downloads folder as before) ...
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
//               // await originalFile.delete();
//             } else {
//               userMessage = "Internal video ready, copy failed.";
//             }
//           } else {
//             userMessage = "Video in app storage (Downloads not found).";
//           }
//         } catch (e_copy) {
//           userMessage = "Video in app storage (Error copying to Downloads).";
//         }
//
//         if (!_recordingCompleter.isCompleted) {
//           _recordingCompleter.complete(
//             RecordingOutput(
//               filePath: finalSavedPath,
//               success: true,
//               userFriendlyMessage: userMessage,
//             ),
//           );
//         }
//       } else {
//         /* ... FFmpeg failure handling ... */
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
//       /* ... FFmpeg exception handling ... */
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
//       await _cleanupAllPendingAndTempDir();
//     }
//   }
//
//   Future<void> _cleanupTempDir() async {
//     /* ... same as before ... */
//   }
//
//   Future<void> _cleanupAllPendingAndTempDir() async {
//     // This ensures we attempt to wait for any straggling writes if dispose is called
//     // though ideally, stopRecording should have handled awaiting.
//     if (_pendingFrameSaveFutures.isNotEmpty) {
//       debugPrint(
//         "WidgetCaptureXExporter: Cleaning up pending frames during dispose/cleanup...",
//       );
//       try {
//         await Future.wait(_pendingFrameSaveFutures);
//       } catch (e) {
//         debugPrint(
//           "WidgetCaptureXExporter: Error during cleanup await of pending frames: $e",
//         );
//       }
//       _pendingFrameSaveFutures.clear();
//     }
//     _cleanupTempDir(); // Cleans the directory
//   }
//
//   @override
//   void dispose() {
//     debugPrint("WidgetCaptureXExporter: dispose() called.");
//     // _cleanupAllPendingAndTempDir(); // Call new cleanup
//     // Call _cleanupTempDir directly as it handles nullability and also resets flags
//     _cleanupTempDir();
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
// // --- Main Controller ---
// class WidgetCaptureXPlusController extends ChangeNotifier {
//   // ... (Properties: _nativeScreenRecorderController, _exporter, _recordingCompleter, states, config options, _isDisposed, _frameStreamController, activeScreenRecorderController getter, constructor, _updateState)
//   // ... (These are mostly the same as the V4 version, with minor adjustments below) ...
//
//   ScreenRecorderController? _nativeScreenRecorderController;
//   _WidgetCaptureXPlusExporter? _exporter;
//   Completer<RecordingOutput>? _recordingCompleter;
//
//   RecordingState _recordingState = RecordingState.idle;
//   RecordingState get recordingState => _recordingState;
//
//   RecordingOutput? _lastOutput;
//   RecordingOutput? get lastOutput => _lastOutput;
//
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
//     if (_nativeScreenRecorderController == null) {
//       throw StateError("ScreenRecorderController not initialized.");
//     }
//     return _nativeScreenRecorderController!;
//   }
//
//   WidgetCaptureXPlusController({
//     this.pixelRatio = 1.0,
//     this.skipFramesBetweenCaptures = 2,
//     this.outputBaseFileName = "widget_capture",
//     this.outputFormat = "mp4",
//     this.targetOutputFps = 30.0,
//     this.targetOutputResolution = "", // e.g. "1080x1920"
//   }) {
//     _frameStreamController = StreamController<Uint8List>.broadcast();
//   }
//
//   void _updateState(
//     RecordingState newState, {
//     String? error,
//     RecordingOutput? output,
//   }) {
//     // ... (same _updateState as before, checking _isDisposed) ...
//     if (_isDisposed) return;
//     bool coreStateChanged =
//         _recordingState != newState || _currentError != error;
//     bool outputChanged =
//         (_lastOutput?.filePath != output?.filePath) ||
//         (_lastOutput?.success != output?.success);
//     if (!coreStateChanged &&
//         !outputChanged &&
//         _lastOutput?.userFriendlyMessage == output?.userFriendlyMessage)
//       return;
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
//         _recordingState == RecordingState.preparing)
//       return;
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
//     _exporter = _WidgetCaptureXPlusExporter(
//       _recordingCompleter!,
//       outputBaseFileName: outputBaseFileName,
//       outputFormat: outputFormat,
//       inputFpsForFFmpegCommand: inputFpsForFFmpegCommand,
//       targetOutputResolution: targetOutputResolution,
//       isControllerDisposedCheck: () => _isDisposed,
//       onFrameStreamed: (Uint8List frameBytes) {
//         if (!_frameStreamController.isClosed) {
//           _frameStreamController.add(frameBytes);
//         }
//       },
//     );
//
//     try {
//       await _exporter!.init();
//       if (_isDisposed) {
//         _exporter?.dispose();
//         return;
//       }
//
//       _nativeScreenRecorderController = ScreenRecorderController(
//         exporter: _exporter,
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
//         "WidgetCaptureXController: Recording started. Input FPS for FFmpeg: $inputFpsForFFmpegCommand. Target output FPS: $targetOutputFps",
//       );
//     } catch (e) {
//       // ... (error handling as before, ensure exporter is disposed) ...
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
//     if (_isDisposed)
//       return RecordingOutput(
//         success: false,
//         errorMessage: "Controller disposed.",
//       );
//     if (_recordingState != RecordingState.recording) {
//       // ... (handle non-recording states as before, ensuring exporter is disposed if it exists) ...
//       if (_recordingState == RecordingState.preparing) {
//         if (_recordingCompleter != null && !_recordingCompleter!.isCompleted) {
//           _recordingCompleter!.complete(
//             RecordingOutput(
//               success: false,
//               errorMessage: "Recording stopped during preparation.",
//             ),
//           );
//         }
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
//
//     _updateState(RecordingState.stopping);
//     try {
//       _nativeScreenRecorderController?.stop(); // Stops new frames to onNewFrame
//
//       if (_exporter != null) {
//         // Pass the controller's targetOutputFps to finalizeRecording
//         await _exporter!.finalizeRecording(
//           outputTargetActualFpsFromController: targetOutputFps,
//         );
//       } else {
//         throw Exception(
//           "Exporter was null during stopRecording in 'recording' state.",
//         );
//       }
//
//       final result = await _recordingCompleter!.future;
//       _updateState(
//         RecordingState.completed,
//         output: result,
//         error: result.success ? null : result.errorMessage,
//       );
//       return result;
//     } catch (e) {
//       // ... (error handling as before) ...
//       final errMessage = "Failed to stop/process recording: ${e.toString()}";
//       _updateState(RecordingState.error, error: errMessage);
//       if (!(_recordingCompleter?.isCompleted ?? true)) {
//         _recordingCompleter!.complete(
//           RecordingOutput(success: false, errorMessage: errMessage),
//         );
//       }
//       return RecordingOutput(success: false, errorMessage: errMessage);
//     } finally {
//       // _exporter is disposed inside its own finalizeRecording or if an error occurs.
//       // Here we just nullify our reference to it and the native controller.
//       // However, calling dispose again if it's not null is safer.
//       _exporter
//           ?.dispose(); // Ensure it's disposed if finalizeRecording threw before its own finally
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
//
//     if (_recordingState == RecordingState.recording ||
//         _recordingState == RecordingState.stopping ||
//         _recordingState == RecordingState.preparing) {
//       // If preparing, native controller might not exist yet
//       _nativeScreenRecorderController?.stop();
//     }
//
//     _exporter?.dispose(); // This will call _cleanupAllPendingAndTempDir
//     _exporter = null;
//     _nativeScreenRecorderController = null;
//
//     if (!_frameStreamController.isClosed) {
//       _frameStreamController.close();
//     }
//     super.dispose();
//   }
// }
