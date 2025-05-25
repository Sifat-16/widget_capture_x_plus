import 'dart:async';
import 'dart:html'
    if (dart.library.io) 'html_stub.dart'
    as html; // Use a stub for non-web
import 'dart:io' show File;
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:widget_capture_x_plus/widget_capture_x_plus.dart';
import 'package:widget_capture_x_plus/widget_capture_x_plus_controller.dart';

class RecordingDemoPageWeb extends StatefulWidget {
  const RecordingDemoPageWeb({super.key});

  @override
  State<RecordingDemoPageWeb> createState() => _RecordingDemoPageWebState();
}

class _RecordingDemoPageWebState extends State<RecordingDemoPageWeb> {
  late WidgetCaptureXPlusController _captureController;
  VideoPlayerController? _recordedVideoPlayerController;
  String? _webRecordedVideoBlobUrl; // To store and revoke blob URL for web
  String _status =
      'Press "Start Recording" to capture the remote video playback.';
  bool _isProcessingVideo = false; // For FFmpeg/exporter processing

  final String _remoteVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
  String _outputFormatForRecording = "mp4";

  @override
  void initState() {
    super.initState();
    // For web, webm with vp9 might be more efficient/reliable with ffmpeg.wasm
    // than mp4 with h264 unless the wasm build is specifically optimized for it.
    _outputFormatForRecording = kIsWeb ? "webm" : "mp4";

    _captureController = WidgetCaptureXPlusController(
      pixelRatio: 1.0,
      skipFramesBetweenCaptures: 1, // Aim for ~30 FPS if device is 60 FPS
      outputBaseFileName: "recorded_widget_video",
      outputFormat: _outputFormatForRecording,
      targetOutputFps: 24, // Common video frame rate
      // Example: targetOutputResolution: "640x360", // Ensure even dimensions if using yuv420p
    );

    _captureController.addListener(_onCaptureStateChanged);
  }

  void _onCaptureStateChanged() {
    if (!mounted) return;

    final state = _captureController.recordingState;
    String currentStatus = 'State: ${state.toString().split('.').last}';

    switch (state) {
      case RecordingState.idle:
        break;
      case RecordingState.preparing:
        currentStatus = 'Preparing recorder...';
        break;
      case RecordingState.recording:
        currentStatus = 'Recording...';
        break;
      case RecordingState.stopping:
        currentStatus = 'Stopping and processing video...';
        _isProcessingVideo = true;
        break;
      case RecordingState.completed:
        _isProcessingVideo = false;
        if (_captureController.lastOutput?.success == true) {
          final output = _captureController.lastOutput!;
          if (kIsWeb && output.rawData != null) {
            currentStatus =
                'Web recording complete! ${output.userFriendlyMessage ?? ""}';
            _initializeAndPlayWebVideo(
              output.rawData!,
              output.suggestedFileName ??
                  "recorded_video.${_outputFormatForRecording}",
            );
          } else if (!kIsWeb && output.filePath != null) {
            currentStatus =
                '${output.userFriendlyMessage ?? "Recording complete!"}\nPath: ${output.filePath}';
            _initializeAndPlayNativeVideo(output.filePath!);
          } else {
            currentStatus =
                'Recording completed but output data or path is missing.';
          }
        } else {
          currentStatus =
              'Processing finished. Issue: ${_captureController.lastOutput?.errorMessage ?? _captureController.lastOutput?.userFriendlyMessage ?? "Unknown"}';
        }
        break;
      case RecordingState.error:
        currentStatus =
            'Error: ${_captureController.currentError ?? "Unknown error"}';
        _isProcessingVideo = false;
        break;
    }
    setState(() {
      _status = currentStatus;
    });
  }

  Future<void> _startRecording() async {
    if (!(_captureController.recordingState == RecordingState.idle ||
        _captureController.recordingState == RecordingState.completed ||
        _captureController.recordingState == RecordingState.error)) {
      return;
    }
    setState(() {
      _status = 'Preparing to record...';
      _recordedVideoPlayerController?.dispose();
      _recordedVideoPlayerController = null;
      if (kIsWeb && _webRecordedVideoBlobUrl != null) {
        html.Url.revokeObjectUrl(_webRecordedVideoBlobUrl!);
        _webRecordedVideoBlobUrl = null;
      }
      _isProcessingVideo = false;
    });
    await _captureController.startRecording();
  }

  Future<void> _stopRecording() async {
    if (_captureController.recordingState != RecordingState.recording) return;
    await _captureController.stopRecording();
  }

  Future<void> _initializeAndPlayNativeVideo(String filePath) async {
    _recordedVideoPlayerController?.dispose();
    _recordedVideoPlayerController = VideoPlayerController.file(
      File(filePath),
    ); // dart:io File
    try {
      await _recordedVideoPlayerController!.initialize();
      await _recordedVideoPlayerController!.setLooping(true);
      await _recordedVideoPlayerController!.play();
      setState(() {});
    } catch (e) {
      setState(() {
        _status = 'Error initializing native video player: $e';
      });
      debugPrint('Error initializing native video player: $e');
    }
  }

  Future<void> _initializeAndPlayWebVideo(
    Uint8List videoData,
    String suggestedFileName,
  ) async {
    if (_webRecordedVideoBlobUrl != null) {
      html.Url.revokeObjectUrl(_webRecordedVideoBlobUrl!);
    }
    _recordedVideoPlayerController?.dispose();

    String mimeType =
        'video/$_outputFormatForRecording'; // e.g. video/mp4, video/webm
    if (_outputFormatForRecording == "mov") mimeType = "video/quicktime";

    final blob = html.Blob([videoData], mimeType);
    _webRecordedVideoBlobUrl = html.Url.createObjectUrlFromBlob(blob);

    _recordedVideoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(_webRecordedVideoBlobUrl!),
    );
    try {
      await _recordedVideoPlayerController!.initialize();
      await _recordedVideoPlayerController!.setLooping(true);
      await _recordedVideoPlayerController!.play();
      setState(() {});
      debugPrint(
        "Web recorded video initialized and playing from blob URL: $_webRecordedVideoBlobUrl",
      );
    } catch (e) {
      setState(() {
        _status = 'Error initializing recorded web video player: $e';
      });
      debugPrint('Error initializing recorded web video player: $e');
      if (_webRecordedVideoBlobUrl != null) {
        html.Url.revokeObjectUrl(_webRecordedVideoBlobUrl!);
        _webRecordedVideoBlobUrl = null;
      }
    }
  }

  // Optional: Function to trigger download for web
  Future<void> _triggerWebVideoDownload() async {
    if (!kIsWeb ||
        _captureController.lastOutput?.rawData == null ||
        _captureController.lastOutput?.suggestedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No web video data available to download."),
        ),
      );
      return;
    }
    final output = _captureController.lastOutput!;
    try {
      String mimeType = 'video/$_outputFormatForRecording';
      if (_outputFormatForRecording == "mov") mimeType = "video/quicktime";

      final blob = html.Blob([output.rawData!], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement(href: url)
            ..setAttribute("download", output.suggestedFileName!)
            ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download initiated: ${output.suggestedFileName!}"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error initiating download: $e")));
    }
  }

  @override
  void dispose() {
    _captureController.removeListener(_onCaptureStateChanged);
    _captureController.dispose();
    _recordedVideoPlayerController?.dispose();
    if (kIsWeb && _webRecordedVideoBlobUrl != null) {
      html.Url.revokeObjectUrl(_webRecordedVideoBlobUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRecState = _captureController.recordingState;
    final bool canStart =
        currentRecState == RecordingState.idle ||
        currentRecState == RecordingState.completed ||
        currentRecState == RecordingState.error;
    final bool canStop = currentRecState == RecordingState.recording;
    final bool showWidgetCaptureXWrapper =
        currentRecState == RecordingState.preparing ||
        currentRecState == RecordingState.recording ||
        currentRecState == RecordingState.stopping;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Remote Video Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Area for the widget to be recorded (Remote Video Player)
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blueGrey.withOpacity(0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                ),
                child:
                    showWidgetCaptureXWrapper
                        ? WidgetCaptureXPlus(
                          controller: _captureController,
                          childToRecord: RemoteVideoPlayerWidget(
                            videoUrl: _remoteVideoUrl,
                          ),
                        )
                        : RemoteVideoPlayerWidget(videoUrl: _remoteVideoUrl),
              ),
            ),
            const SizedBox(height: 8),
            // Live Frame Preview Area
            Text(
              "Live Frame Preview:",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Expanded(
              flex: 1,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: StreamBuilder<Uint8List>(
                    stream: _captureController.frameStream,
                    builder: (context, snapshot) {
                      if (currentRecState != RecordingState.recording &&
                          currentRecState != RecordingState.preparing) {
                        return Center(
                          child: Text(
                            "Preview active during recording",
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Transform(
                          // To flip preview if frames are captured upside down
                          alignment: Alignment.center,
                          transform: Matrix4.rotationX(
                            3.1415926535,
                          ), // Pi radians for 180 deg
                          child: Image.memory(
                            snapshot.data!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (ctx, err, stack) => Text(
                                  "Error in preview frame",
                                  style: TextStyle(color: Colors.red),
                                ),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Text(
                          "Frame stream error",
                          style: TextStyle(color: Colors.red),
                        );
                      }
                      return Center(
                        child: Text(
                          "Waiting for frames...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Area for playing back the recorded video
            Text(
              "Recorded Video Playback:",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Expanded(
              flex: 2,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child:
                      (_recordedVideoPlayerController != null &&
                              _recordedVideoPlayerController!
                                  .value
                                  .isInitialized)
                          ? AspectRatio(
                            aspectRatio:
                                _recordedVideoPlayerController!
                                    .value
                                    .aspectRatio,
                            child: VideoPlayer(_recordedVideoPlayerController!),
                          )
                          : (_isProcessingVideo ||
                              currentRecState == RecordingState.stopping)
                          ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text("Processing recorded video..."),
                            ],
                          )
                          : Center(
                            child: Text(
                              'Recorded video playback will appear here',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed: canStart ? _startRecording : null,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Start Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: canStop ? _stopRecording : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Stop Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                  ),
                ),
              ],
            ),
            if (kIsWeb &&
                _captureController.lastOutput?.rawData != null &&
                _captureController.lastOutput?.success == true)
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton.icon(
                  onPressed: _triggerWebVideoDownload,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Web Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget to play the remote video that will be recorded
class RemoteVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onInitializedAndPlaying;

  const RemoteVideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.onInitializedAndPlaying,
  });

  @override
  State<RemoteVideoPlayerWidget> createState() =>
      _RemoteVideoPlayerWidgetState();
}

class _RemoteVideoPlayerWidgetState extends State<RemoteVideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _showControls = false;
  bool _errorLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      // For recording, you might want it to autoplay or have explicit control
      // For this example, let's make it autoplay once loaded for easier recording start
      if (mounted) {
        await _controller!.play();
        setState(() {});
        widget.onInitializedAndPlaying?.call();
      }
    } catch (e) {
      print("Error initializing remote video player: $e");
      if (mounted) {
        setState(() {
          _errorLoading = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading video to record: $e")),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 10),
            Text(
              "Failed to load video.",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 10),
            Text(
              "Loading video to record...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _showControls = true),
      onExit: (_) => setState(() => _showControls = false),
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
              VideoPlayer(_controller!),
              AnimatedOpacity(
                opacity:
                    _showControls || !_controller!.value.isPlaying ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: ColoredBox(
                  color: Colors.black26,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: Theme.of(context).colorScheme.primary,
                          bufferedColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                          backgroundColor: Colors.grey.withOpacity(0.5),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
