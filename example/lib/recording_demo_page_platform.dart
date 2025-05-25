import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:widget_capture_x_plus/widget_capture_x_plus.dart';
import 'package:widget_capture_x_plus/widget_capture_x_plus_controller.dart';

class RecordingDemoPage extends StatefulWidget {
  const RecordingDemoPage({super.key});

  @override
  State<RecordingDemoPage> createState() => _RecordingDemoPageState();
}

class _RecordingDemoPageState extends State<RecordingDemoPage> {
  late WidgetCaptureXPlusController _captureController;
  VideoPlayerController? _recordedVideoPlayerController;
  String _status =
      'Press "Start Recording" to capture the remote video playback.';
  bool _isProcessingVideo = false;

  final String _remoteVideoUrl =
      'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

  @override
  void initState() {
    super.initState();
    _captureController = WidgetCaptureXPlusController(
      pixelRatio: 1.0,
      skipFramesBetweenCaptures: 1,
      outputBaseFileName: "remote_video_capture",
      outputFormat: "mp4",
      targetOutputFps: 24,
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
        currentStatus = 'Recording remote video playback...';
        break;
      case RecordingState.stopping:
        currentStatus = 'Stopping and processing recorded video...';
        _isProcessingVideo = true;
        break;
      case RecordingState.completed:
        _isProcessingVideo = false;
        if (_captureController.lastOutput?.success == true &&
            _captureController.lastOutput?.filePath != null) {
          currentStatus =
              '${_captureController.lastOutput!.userFriendlyMessage ?? "Recording complete!"}\nSaved to: ${_captureController.lastOutput!.filePath}';
          _initializeRecordedVideoPlayer(
            _captureController.lastOutput!.filePath!,
          );
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
      _isProcessingVideo = false;
    });
    // Assuming RemoteVideoPlayerWidget needs to be playing for capture to be meaningful.
    // A more robust solution would involve RemoteVideoPlayerWidget signaling when it's ready.
    // For now, we rely on the user to ensure the video is playing or about to play.
    await _captureController.startRecording();
  }

  Future<void> _stopRecording() async {
    if (_captureController.recordingState != RecordingState.recording) return;
    await _captureController.stopRecording();
  }

  Future<void> _initializeRecordedVideoPlayer(String filePath) async {
    _recordedVideoPlayerController?.dispose();
    _recordedVideoPlayerController = VideoPlayerController.file(File(filePath));
    try {
      await _recordedVideoPlayerController!.initialize();
      await _recordedVideoPlayerController!.setLooping(true);
      await _recordedVideoPlayerController!.play();
      setState(() {});
    } catch (e) {
      setState(() {
        _status = 'Error initializing recorded video player: $e';
      });
      print('Error initializing recorded video player: $e');
    }
  }

  @override
  void dispose() {
    _captureController.removeListener(_onCaptureStateChanged);
    _captureController.dispose();
    _recordedVideoPlayerController?.dispose();
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
      appBar: AppBar(title: const Text('Record Remote Video & Frame Stream')),
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
            // Area for the widget to be recorded (Remote Video Player)
            Expanded(
              flex: 2, // Give it good space
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.indigo.withOpacity(0.5),
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
            // --- Live Frame Preview Area ---
            Text(
              "Live Frame Preview:",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Expanded(
              flex: 1, // Smaller preview area
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
                        return Image.memory(
                          snapshot.data!,
                          gaplessPlayback: true,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (ctx, err, stack) => Text(
                                "Error in preview frame",
                                style: TextStyle(color: Colors.red),
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
              flex: 2, // Give it good space
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  color: Colors.black, // Background for video player
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
          ],
        ),
      ),
    );
  }
}

// Widget to play the remote video that will be recorded
class RemoteVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onInitializedAndPlaying; // Optional callback

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
      // await _controller!.play();
      if (mounted) {
        setState(() {});
        widget.onInitializedAndPlaying?.call();
      }
    } catch (e) {
      print("Error initializing remote video player: $e");
      if (mounted) {
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
