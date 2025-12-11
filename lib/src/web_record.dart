import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:developer' as developer;

// ============================================================================
// LOGGING
// ============================================================================

/// Log level for recording events
enum RecordingLogLevel {
  debug,
  info,
  warning,
  error,
}

/// Callback for logging events during recording
typedef RecordingLogCallback = void Function(
  String message, {
  RecordingLogLevel level,
  Object? error,
  StackTrace? stackTrace,
});

/// Internal logging utility
class _RecordingLogger {
  static RecordingLogCallback? _callback;
  static bool _useDevLog = true;

  static void configure({
    RecordingLogCallback? callback,
    bool useDevLog = true,
  }) {
    _callback = callback;
    _useDevLog = useDevLog;
  }

  static void log(
    String message, {
    RecordingLogLevel level = RecordingLogLevel.info,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _callback?.call(message,
        level: level, error: error, stackTrace: stackTrace);

    if (_useDevLog && kDebugMode) {
      final levelValue = _getLevelValue(level);
      developer.log(
        message,
        name: 'flutter_web_record',
        level: levelValue,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static int _getLevelValue(RecordingLogLevel level) {
    switch (level) {
      case RecordingLogLevel.debug:
        return 500;
      case RecordingLogLevel.info:
        return 800;
      case RecordingLogLevel.warning:
        return 900;
      case RecordingLogLevel.error:
        return 1000;
    }
  }

  static void debug(String message) =>
      log(message, level: RecordingLogLevel.debug);
  static void info(String message) =>
      log(message, level: RecordingLogLevel.info);
  static void warning(String message) =>
      log(message, level: RecordingLogLevel.warning);
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(message,
          level: RecordingLogLevel.error, error: error, stackTrace: stackTrace);
}

// ============================================================================
// CONFIGURATION CLASSES
// ============================================================================

class RecordingIndicatorConfig {
  final Color recordingColor;
  final Color pausedColor;
  final Color backgroundColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsets padding;
  final TextStyle? timeTextStyle;
  final TextStyle? statusTextStyle;
  final Alignment position;
  final Offset? customOffset;

  const RecordingIndicatorConfig({
    this.recordingColor = Colors.red,
    this.pausedColor = Colors.orange,
    this.backgroundColor = Colors.black87,
    this.borderWidth = 2.0,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.all(16),
    this.timeTextStyle,
    this.statusTextStyle,
    this.position = Alignment.topRight,
    this.customOffset,
  });
}

class ControlButtonConfig {
  final IconData? pauseIcon;
  final IconData? playIcon;
  final IconData? stopIcon;
  final IconData? cancelIcon;
  final Color pauseColor;
  final Color stopColor;
  final Color cancelColor;
  final double buttonSize;
  final double iconSize;
  final double spacing;

  const ControlButtonConfig({
    this.pauseIcon,
    this.playIcon,
    this.stopIcon,
    this.cancelIcon,
    this.pauseColor = Colors.orange,
    this.stopColor = Colors.red,
    this.cancelColor = Colors.grey,
    this.buttonSize = 32.0,
    this.iconSize = 18.0,
    this.spacing = 8.0,
  });
}

class RecordingConfig {
  final int idealWidth;
  final int idealHeight;
  final int idealFrameRate;
  final int videoBitsPerSecond;
  final bool captureAudio;
  final bool showCursor;
  final AudioCaptureMode audioCaptureMode;

  const RecordingConfig({
    this.idealWidth = 1920,
    this.idealHeight = 1080,
    this.idealFrameRate = 30,
    this.videoBitsPerSecond = 5000000,
    this.captureAudio = true,
    this.showCursor = true,
    this.audioCaptureMode = AudioCaptureMode.system,
  });
}

enum AudioCaptureMode {
  system,
  microphone,
  both,
  none,
}

class RecordingResult {
  final Uint8List fileBytes;
  final String fileName;
  final String mimeType;
  final String blobUrl;
  final int durationSeconds;

  RecordingResult({
    required this.fileBytes,
    required this.fileName,
    required this.mimeType,
    required this.blobUrl,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'fileBytes': fileBytes,
      'fileName': fileName,
      'mimeType': mimeType,
      'url': blobUrl,
      'duration': durationSeconds,
    };
  }
}

// ============================================================================
// MAIN SCREEN RECORDER
// ============================================================================

class ScreenRecorder {
  static Future<RecordingResult?> startRecording(
    BuildContext context, {
    RecordingConfig recordingConfig = const RecordingConfig(),
    RecordingIndicatorConfig? indicatorConfig,
    ControlButtonConfig? controlConfig,
    bool showPreview = false,
    Function(RecordingResult)? onRecordingComplete,
    VoidCallback? onRecordingCancelled,
    RecordingLogCallback? onLog,
    bool enableLogging = true,
  }) async {
    _RecordingLogger.configure(
      callback: onLog,
      useDevLog: enableLogging,
    );

    try {
      _RecordingLogger.info('Starting screen recording request...');

      final mediaStream = await _getMediaStream(recordingConfig);

      if (mediaStream == null || mediaStream.getTracks().toDart.isEmpty) {
        _RecordingLogger.warning('User cancelled screen selection');
        onRecordingCancelled?.call();
        return null;
      }

      _RecordingLogger.info('Media stream obtained successfully');
      _RecordingLogger.debug(
          'Video tracks: ${mediaStream.getVideoTracks().toDart.length}');
      _RecordingLogger.debug(
          'Audio tracks: ${mediaStream.getAudioTracks().toDart.length}');

      final completer = Completer<RecordingResult?>();

      if (context.mounted) {
        ScreenRecordingOverlay.show(
          context,
          mediaStream: mediaStream,
          recordingConfig: recordingConfig,
          indicatorConfig: indicatorConfig ?? const RecordingIndicatorConfig(),
          controlConfig: controlConfig ?? const ControlButtonConfig(),
          onComplete: (result) async {
            if (result != null) {
              _RecordingLogger.info('Recording completed: ${result.fileName}');

              if (showPreview && context.mounted) {
                _RecordingLogger.debug('Showing preview dialog');
                final confirmed = await _showPreviewDialog(context, result);
                if (confirmed == true) {
                  onRecordingComplete?.call(result);
                  completer.complete(result);
                } else {
                  _RecordingLogger.info('Recording discarded by user');
                  onRecordingCancelled?.call();
                  completer.complete(null);
                }
              } else {
                onRecordingComplete?.call(result);
                completer.complete(result);
              }
            } else {
              _RecordingLogger.warning('Recording cancelled');
              onRecordingCancelled?.call();
              completer.complete(null);
            }
          },
        );
      }

      return completer.future;
    } catch (e, stackTrace) {
      _RecordingLogger.error(
        'Error starting recording',
        error: e,
        stackTrace: stackTrace,
      );
      onRecordingCancelled?.call();
      return null;
    }
  }

  static Future<web.MediaStream?> _getMediaStream(
      RecordingConfig config) async {
    try {
      _RecordingLogger.debug('Requesting display media with constraints');

      final navigator = web.window.navigator;
      final mediaDevices = navigator.mediaDevices;

      final audioConstraints = _getAudioConstraints(config.audioCaptureMode);

      final constraints = <String, JSAny?>{
        'video': <String, JSAny?>{
          'cursor': (config.showCursor ? 'always' : 'never').toJS,
          'width': <String, JSAny?>{'ideal': config.idealWidth.toJS}.jsify(),
          'height': <String, JSAny?>{'ideal': config.idealHeight.toJS}.jsify(),
          'frameRate': <String, JSAny?>{'ideal': config.idealFrameRate.toJS}.jsify(),
        }.jsify(),
        'audio': audioConstraints,
      }.jsify() as web.DisplayMediaStreamOptions;

      _RecordingLogger.debug('Audio mode: ${config.audioCaptureMode.name}');

      final streamPromise = mediaDevices.getDisplayMedia(constraints);
      final stream = await streamPromise.toDart;

      _RecordingLogger.info('Media stream obtained successfully');
      _RecordingLogger.debug(
          'Video tracks: ${stream.getVideoTracks().toDart.length}');
      _RecordingLogger.debug(
          'Audio tracks: ${stream.getAudioTracks().toDart.length}');

      if (config.audioCaptureMode == AudioCaptureMode.microphone ||
          config.audioCaptureMode == AudioCaptureMode.both) {
        _RecordingLogger.debug('Requesting microphone access');
        final micStream = await _getMicrophoneStream();
        if (micStream != null) {
          final micTracks = micStream.getAudioTracks().toDart;
          for (var track in micTracks) {
            stream.addTrack(track);
          }
          _RecordingLogger.info('Microphone tracks added: ${micTracks.length}');
        } else {
          _RecordingLogger.warning('Could not access microphone');
        }
      }

      return stream;
    } catch (e, stackTrace) {
      _RecordingLogger.error(
        'Error getting media stream',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static JSAny _getAudioConstraints(AudioCaptureMode mode) {
    switch (mode) {
      case AudioCaptureMode.system:
        return <String, JSBoolean>{
          'echoCancellation': false.toJS,
          'noiseSuppression': false.toJS,
          'autoGainControl': false.toJS,
        }.jsify()!;
      case AudioCaptureMode.microphone:
        return false.toJS;
      case AudioCaptureMode.both:
        return <String, JSBoolean>{
          'echoCancellation': false.toJS,
          'noiseSuppression': false.toJS,
          'autoGainControl': false.toJS,
        }.jsify()!;
      case AudioCaptureMode.none:
        return false.toJS;
    }
  }

  static Future<web.MediaStream?> _getMicrophoneStream() async {
    try {
      final navigator = web.window.navigator;
      final mediaDevices = navigator.mediaDevices;

      final constraints = <String, JSAny?>{
        'audio': <String, JSBoolean>{
          'echoCancellation': true.toJS,
          'noiseSuppression': true.toJS,
          'autoGainControl': true.toJS,
        }.jsify(),
        'video': false.toJS,
      }.jsify() as web.MediaStreamConstraints;

      final streamPromise = mediaDevices.getUserMedia(constraints);
      final stream = await streamPromise.toDart;
      return stream;
    } catch (e) {
      _RecordingLogger.warning('Could not get microphone stream: $e');
      return null;
    }
  }

  static Future<bool?> _showPreviewDialog(
      BuildContext context, RecordingResult result) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordingPreviewDialog(result: result),
    );
  }
}

// ============================================================================
// RECORDING OVERLAY
// ============================================================================

class ScreenRecordingOverlay {
  static OverlayEntry? _overlayEntry;
  static web.MediaRecorder? _mediaRecorder;
  static web.MediaStream? _mediaStream;
  static final List<web.Blob> _recordedChunks = [];
  static Timer? _timer;
  static int _seconds = 0;
  static bool _isPaused = false;
  static Function(RecordingResult?)? _onComplete;

  static void show(
    BuildContext context, {
    required web.MediaStream mediaStream,
    required RecordingConfig recordingConfig,
    required RecordingIndicatorConfig indicatorConfig,
    required ControlButtonConfig controlConfig,
    required Function(RecordingResult?)? onComplete,
  }) {
    _mediaStream = mediaStream;
    _recordedChunks.clear();
    _seconds = 0;
    _isPaused = false;
    _onComplete = onComplete;

    final mimeType = _getSupportedMimeType();
    _RecordingLogger.info('Using MIME type: $mimeType');

    final options = <String, JSAny?>{
      'mimeType': mimeType.toJS,
      'videoBitsPerSecond': recordingConfig.videoBitsPerSecond.toJS,
    }.jsify() as web.MediaRecorderOptions;

    _mediaRecorder = web.MediaRecorder(mediaStream, options);

    _mediaRecorder!.addEventListener(
        'dataavailable',
        ((web.Event event) {
          final blobEvent = event as web.BlobEvent;
          final data = blobEvent.data;
          if (data != null && data.size > 0) {
            _recordedChunks.add(data);
            _RecordingLogger.debug('Chunk recorded: ${data.size} bytes');
          }
        }.toJS));

    _mediaRecorder!.addEventListener(
        'stop',
        ((web.Event event) {
          _RecordingLogger.info('Recording stopped - processing...');
          _handleRecordingStop();
        }.toJS));

    _mediaRecorder!.start(1000);
    _RecordingLogger.info('Recording started');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _seconds++;
        _overlayEntry?.markNeedsBuild();
      }
    });

    final tracks = mediaStream.getTracks().toDart;
    if (tracks.isNotEmpty) {
      tracks.first.onended = ((web.Event event) {
        _RecordingLogger.info('Stream ended by user');
        _stopRecording();
      }.toJS);
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _RecordingIndicator(
        seconds: _seconds,
        isPaused: _isPaused,
        indicatorConfig: indicatorConfig,
        controlConfig: controlConfig,
        onPause: _togglePause,
        onStop: _stopRecording,
        onCancel: _cancelRecording,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static String _getSupportedMimeType() {
    final types = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm;codecs=h264,opus',
      'video/webm',
    ];

    for (var type in types) {
      if (web.MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }
    return 'video/webm';
  }

  static void _togglePause() {
    if (_mediaRecorder == null) return;

    if (_isPaused) {
      _mediaRecorder!.resume();
      _RecordingLogger.info('Recording resumed');
    } else {
      _mediaRecorder!.pause();
      _RecordingLogger.info('Recording paused');
    }

    _isPaused = !_isPaused;
    _overlayEntry?.markNeedsBuild();
  }

  static void _stopRecording() {
    _RecordingLogger.info('Stopping recording...');
    _timer?.cancel();

    if (_mediaRecorder?.state != 'inactive') {
      _mediaRecorder?.stop();
    }

    final tracks = _mediaStream?.getTracks().toDart ?? [];
    for (var track in tracks) {
      track.stop();
      _RecordingLogger.debug('Track stopped: ${track.kind}');
    }
  }

  static void _cancelRecording() {
    _RecordingLogger.info('Recording cancelled by user');
    _stopRecording();
    _recordedChunks.clear();
    hide();
    _onComplete?.call(null);
  }

  static void _handleRecordingStop() {
    _processRecording().then((result) {
      hide();
      _onComplete?.call(result);
    }).catchError((error) {
      _RecordingLogger.error('Error handling recording stop', error: error);
      hide();
      _onComplete?.call(null);
    });
  }

  static Future<RecordingResult?> _processRecording() async {
    try {
      _RecordingLogger.info('Processing ${_recordedChunks.length} chunks...');

      if (_recordedChunks.isEmpty) {
        _RecordingLogger.warning('No chunks recorded');
        return null;
      }

      final blobParts = _recordedChunks.map((b) => b as JSAny).toList().toJS;
      final blob = web.Blob(
        blobParts,
        web.BlobPropertyBag(type: 'video/webm'),
      );
      _RecordingLogger.debug('Blob created: ${blob.size} bytes');

      final blobUrl = web.URL.createObjectURL(blob);
      _RecordingLogger.debug('Blob URL created');

      final reader = web.FileReader();
      reader.readAsArrayBuffer(blob);

      final completer = Completer<void>();
      reader.onloadend = ((web.Event event) {
        completer.complete();
      }.toJS);
      await completer.future;

      final result = reader.result;
      final buffer = (result as JSArrayBuffer).toDart;
      final Uint8List fileBytes = buffer.asUint8List();
      final String fileName =
          'screen_recording_${DateTime.now().millisecondsSinceEpoch}.webm';

      _RecordingLogger.info(
          'Video processed: ${(fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');

      return RecordingResult(
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: 'video/webm',
        blobUrl: blobUrl,
        durationSeconds: _seconds,
      );
    } catch (e, stackTrace) {
      _RecordingLogger.error(
        'Error processing video',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static void hide() {
    _timer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _mediaRecorder = null;
    _mediaStream = null;
  }
}

// ============================================================================
// UI WIDGETS
// ============================================================================

class _RecordingIndicator extends StatelessWidget {
  final int seconds;
  final bool isPaused;
  final RecordingIndicatorConfig indicatorConfig;
  final ControlButtonConfig controlConfig;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  const _RecordingIndicator({
    required this.seconds,
    required this.isPaused,
    required this.indicatorConfig,
    required this.controlConfig,
    required this.onPause,
    required this.onStop,
    required this.onCancel,
  });

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildPositionedIndicator(Size screenSize, Widget child) {
    if (indicatorConfig.customOffset != null) {
      final offset = indicatorConfig.customOffset!;
      return Positioned(
        left: offset.dx,
        top: offset.dy,
        child: child,
      );
    }

    final alignment = indicatorConfig.position;
    const padding = 20.0;

    if (alignment == Alignment.topRight) {
      return Positioned(top: padding, right: padding, child: child);
    } else if (alignment == Alignment.topLeft) {
      return Positioned(top: padding, left: padding, child: child);
    } else if (alignment == Alignment.bottomRight) {
      return Positioned(bottom: padding, right: padding, child: child);
    } else if (alignment == Alignment.bottomLeft) {
      return Positioned(bottom: padding, left: padding, child: child);
    } else if (alignment == Alignment.topCenter) {
      return Positioned(
          top: padding, left: screenSize.width / 2 - 100, child: child);
    } else if (alignment == Alignment.bottomCenter) {
      return Positioned(
          bottom: padding, left: screenSize.width / 2 - 100, child: child);
    }

    return Positioned(top: padding, right: padding, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return _buildPositionedIndicator(
      screenSize,
      Material(
        color: Colors.transparent,
        child: Container(
          padding: indicatorConfig.padding,
          decoration: BoxDecoration(
            color: indicatorConfig.backgroundColor,
            borderRadius: BorderRadius.circular(indicatorConfig.borderRadius),
            border: Border.all(
              color: isPaused
                  ? indicatorConfig.pausedColor
                  : indicatorConfig.recordingColor,
              width: indicatorConfig.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isPaused
                          ? indicatorConfig.pausedColor
                          : indicatorConfig.recordingColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPaused ? 'PAUSED' : 'REC',
                    style: indicatorConfig.statusTextStyle ??
                        const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(seconds),
                    style: indicatorConfig.timeTextStyle ??
                        const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: controlConfig.spacing + 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniButton(
                    icon: isPaused
                        ? (controlConfig.playIcon ?? Icons.play_arrow)
                        : (controlConfig.pauseIcon ?? Icons.pause),
                    color: controlConfig.pauseColor,
                    size: controlConfig.buttonSize,
                    iconSize: controlConfig.iconSize,
                    onTap: onPause,
                  ),
                  SizedBox(width: controlConfig.spacing),
                  _MiniButton(
                    icon: controlConfig.stopIcon ?? Icons.stop,
                    color: controlConfig.stopColor,
                    size: controlConfig.buttonSize,
                    iconSize: controlConfig.iconSize,
                    onTap: onStop,
                  ),
                  SizedBox(width: controlConfig.spacing),
                  _MiniButton(
                    icon: controlConfig.cancelIcon ?? Icons.close,
                    color: controlConfig.cancelColor,
                    size: controlConfig.buttonSize,
                    iconSize: controlConfig.iconSize,
                    onTap: onCancel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _MiniButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}

// ============================================================================
// PREVIEW DIALOG
// ============================================================================

class RecordingPreviewDialog extends StatefulWidget {
  final RecordingResult result;

  const RecordingPreviewDialog({
    super.key,
    required this.result,
  });

  @override
  State<RecordingPreviewDialog> createState() => _RecordingPreviewDialogState();
}

class _RecordingPreviewDialogState extends State<RecordingPreviewDialog> {
  late String _videoViewType;

  @override
  void initState() {
    super.initState();
    _videoViewType = 'video-preview-${DateTime.now().millisecondsSinceEpoch}';

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _videoViewType,
      (int viewId) {
        final videoElement = web.HTMLVideoElement()
          ..src = widget.result.blobUrl
          ..controls = true
          ..autoplay = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.border = 'none';
        return videoElement;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview Recording',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: HtmlElementView(viewType: _videoViewType),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Duration: ${widget.result.durationSeconds}s',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.file_present, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Size: ${(widget.result.fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Discard',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Recording'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}