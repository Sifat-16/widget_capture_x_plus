import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_recorder/screen_recorder.dart';
import 'package:widget_capture_x_plus/widget_capture_x_plus_controller.dart';

class _SizeReporter extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  const _SizeReporter({
    Key? key,
    required this.child,
    required this.onSizeChanged,
  }) : super(key: key);

  @override
  _SizeReporterState createState() => _SizeReporterState();
}

class _SizeReporterState extends State<_SizeReporter> {
  final GlobalKey _childKey = GlobalKey();
  Size? _lastReportedSize;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  @override
  void didUpdateWidget(covariant _SizeReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    SchedulerBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  void _reportSize() {
    if (!mounted) return;

    final context = _childKey.currentContext;
    if (context != null) {
      final newSize = context.size;
      if (newSize != null && newSize.width > 0 && newSize.height > 0) {
        if (_lastReportedSize != newSize) {
          _lastReportedSize = newSize;
          widget.onSizeChanged(newSize);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Using a Container as it's a common RenderBox
      key: _childKey,
      child: widget.child,
    );
  }
}

class WidgetCaptureXPlus extends StatefulWidget {
  final Widget childToRecord;
  final WidgetCaptureXPlusController controller;

  const WidgetCaptureXPlus({
    super.key,
    required this.childToRecord,
    required this.controller,
  });

  @override
  State<WidgetCaptureXPlus> createState() => _WidgetCaptureXPlusState();
}

class _WidgetCaptureXPlusState extends State<WidgetCaptureXPlus> {
  Size? _measuredChildSize;
  bool _isMeasuring = true;

  @override
  void initState() {
    super.initState();
    // Listen to the controller if we need to react to state changes,
    // e.g., to ensure ScreenRecorder rebuilds if its controller instance changes.
    widget.controller.addListener(_handleControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  void _handleControllerUpdate() {
    // This listener ensures that if the WidgetCaptureXController signals a state
    // change that requires the ScreenRecorder widget to get a new
    // ScreenRecorderController instance (which happens in startRecording),
    // this widget rebuilds.
    if (mounted) {
      setState(() {
        // Just rebuild, WidgetCaptureX's build method will get the latest
        // activeScreenRecorderController.
      });
    }
  }

  void _handleSizeChanged(Size newSize) {
    if (mounted) {
      if (_measuredChildSize != newSize) {
        setState(() {
          _measuredChildSize = newSize;
          _isMeasuring = false;
        });
      } else if (_isMeasuring) {
        setState(() {
          _isMeasuring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only build the ScreenRecorder part if we are past measuring AND
    // the controller state suggests it's ready for recording.
    final controllerState = widget.controller.recordingState;
    final bool canShowRecorder =
        !_isMeasuring &&
        _measuredChildSize != null &&
        (controllerState == RecordingState.preparing ||
            controllerState == RecordingState.recording ||
            controllerState == RecordingState.stopping);

    if (_isMeasuring || _measuredChildSize == null) {
      // Measurement Pass
      return _SizeReporter(
        onSizeChanged: _handleSizeChanged,
        child: widget.childToRecord,
      );
    } else if (canShowRecorder) {
      // Recording Pass - use the activeScreenRecorderController
      // This part of the tree will rebuild if _handleControllerUpdate calls setState,
      // ensuring it gets the latest _nativeController instance from the getter.
      return ScreenRecorder(
        key: ValueKey(
          widget.controller.activeScreenRecorderController,
        ), // Ensure it rebuilds if controller instance changes
        width: _measuredChildSize!.width,
        height: _measuredChildSize!.height,
        controller: widget.controller.activeScreenRecorderController,
        child: widget.childToRecord,
      );
    } else {
      // Fallback: If not measuring and not in a state to show recorder,
      // show the child directly or a placeholder. This handles idle, completed, error states.
      // Or, if you want the last frame to persist, you might need more complex state.
      return widget.childToRecord;
    }
  }
}
