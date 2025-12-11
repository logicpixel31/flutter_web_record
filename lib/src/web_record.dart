import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    // Call user callback if provided
    _callback?.call(message,
        level: level, error: error, stackTrace: stackTrace);

    // Also log to developer console if enabled (only in debug mode)
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
        return 500; // Level.FINE
      case RecordingLogLevel.info:
        return 800; // Level.INFO
      case RecordingLogLevel.warning:
        return 900; // Level.WARNING
      case RecordingLogLevel.error:
        return 1000; // Level.SEVERE
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

/// Configuration for the recording indicator UI
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

/// Configuration for control buttons
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

/// Configuration for video recording settings
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

/// Audio capture mode options
enum AudioCaptureMode {
  /// Capture system audio (what you hear from your computer)
  system,

  /// Capture microphone audio
  microphone,

  /// Capture both system and microphone audio
  both,

  /// No audio capture
  none,
}

/// Result returned after recording
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

/// Main screen recorder that manages the recording process

class ScreenRecorder {
  /// Start screen recording with optional configurations
  static Future<RecordingResult?> startRecording(
    BuildContext context, {
    RecordingConfig recordingConfig = const RecordingConfig(),
    RecordingIndicatorConfig? indicatorConfig,
    ControlButtonConfig? controlConfig,
    bool showPreview = false,
    Function(RecordingResult)? onRecordingComplete,
    VoidCallback? onRecordingCancelled,
    RecordingLogCallback? onLog, // NEW: User callback for logs
    bool enableLogging = true, // NEW: Enable/disable logging
  }) async {
    // Configure logger with user callback
    _RecordingLogger.configure(
      callback: onLog,
      useDevLog: enableLogging,
    );

    try {
      _RecordingLogger.info('Starting screen recording request...');

      // Get media stream
      final mediaStream = await _getMediaStream(recordingConfig);

      if (mediaStream == null || mediaStream.getTracks().isEmpty) {
        _RecordingLogger.warning('User cancelled screen selection');
        onRecordingCancelled?.call();
        return null;
      }

      _RecordingLogger.info('Media stream obtained successfully');
      _RecordingLogger.debug(
          'Video tracks: ${mediaStream.getVideoTracks().length}');
      _RecordingLogger.debug(
          'Audio tracks: ${mediaStream.getAudioTracks().length}');

      // Show recording overlay
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

  static Future<html.MediaStream?> _getMediaStream(
      RecordingConfig config) async {
    try {
      _RecordingLogger.debug('Requesting display media with constraints');

      final navigator = html.window.navigator;

      if (!js_util.hasProperty(navigator, 'mediaDevices')) {
        _RecordingLogger.error('MediaDevices API not available');
        return null;
      }

      final audioConstraints = _getAudioConstraints(config.audioCaptureMode);

      final constraints = {
        'video': {
          'cursor': config.showCursor ? 'always' : 'never',
          'width': {'ideal': config.idealWidth},
          'height': {'ideal': config.idealHeight},
          'frameRate': {'ideal': config.idealFrameRate},
        },
        'audio': audioConstraints,
      };

      _RecordingLogger.debug('Audio mode: ${config.audioCaptureMode.name}');

      final streamPromise = js_util.callMethod(navigator.mediaDevices!,
          'getDisplayMedia', [js_util.jsify(constraints)]);

      final stream = await js_util.promiseToFuture(streamPromise);
      final mediaStream = stream as html.MediaStream;

      _RecordingLogger.info('Media stream obtained successfully');
      _RecordingLogger.debug(
          'Video tracks: ${mediaStream.getVideoTracks().length}');
      _RecordingLogger.debug(
          'Audio tracks: ${mediaStream.getAudioTracks().length}');

      // Add microphone if needed
      if (config.audioCaptureMode == AudioCaptureMode.microphone ||
          config.audioCaptureMode == AudioCaptureMode.both) {
        _RecordingLogger.debug('Requesting microphone access');
        final micStream = await _getMicrophoneStream();
        if (micStream != null) {
          final micTracks = micStream.getAudioTracks();
          for (var track in micTracks) {
            mediaStream.addTrack(track);
          }
          _RecordingLogger.info('Microphone tracks added: ${micTracks.length}');
        } else {
          _RecordingLogger.warning('Could not access microphone');
        }
      }

      return mediaStream;
    } catch (e, stackTrace) {
      _RecordingLogger.error(
        'Error getting media stream',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static dynamic _getAudioConstraints(AudioCaptureMode mode) {
    switch (mode) {
      case AudioCaptureMode.system:
        return {
          'echoCancellation': false,
          'noiseSuppression': false,
          'autoGainControl': false,
        };
      case AudioCaptureMode.microphone:
        return false;
      case AudioCaptureMode.both:
        return {
          'echoCancellation': false,
          'noiseSuppression': false,
          'autoGainControl': false,
        };
      case AudioCaptureMode.none:
        return false;
    }
  }

  static Future<html.MediaStream?> _getMicrophoneStream() async {
    try {
      final navigator = html.window.navigator;

      final constraints = js_util.jsify({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });

      final streamPromise = js_util
          .callMethod(navigator.mediaDevices!, 'getUserMedia', [constraints]);

      final stream = await js_util.promiseToFuture(streamPromise);
      return stream as html.MediaStream;
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
  static html.MediaRecorder? _mediaRecorder;
  static html.MediaStream? _mediaStream;
  static final List<html.Blob> _recordedChunks = [];
  static Timer? _timer;
  static int _seconds = 0;
  static bool _isPaused = false;
  static Function(RecordingResult?)? _onComplete;

  static void show(
    BuildContext context, {
    required html.MediaStream mediaStream,
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

    _mediaRecorder = html.MediaRecorder(mediaStream, {
      'mimeType': mimeType,
      'videoBitsPerSecond': recordingConfig.videoBitsPerSecond,
    });

    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final html.BlobEvent blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _recordedChunks.add(blobEvent.data!);
        _RecordingLogger.debug('Chunk recorded: ${blobEvent.data!.size} bytes');
      }
    });

    _mediaRecorder!.addEventListener('stop', (event) async {
      _RecordingLogger.info('Recording stopped - processing...');
      final result = await _processRecording();
      hide();
      _onComplete?.call(result);
    });

    _mediaRecorder!.start(1000);
    _RecordingLogger.info('Recording started');

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        _seconds++;
        _overlayEntry?.markNeedsBuild();
      }
    });

    mediaStream.getTracks().first.onEnded.listen((event) {
      _RecordingLogger.info('Stream ended by user');
      _stopRecording();
    });

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
      if (html.MediaRecorder.isTypeSupported(type)) {
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

    if (_mediaRecorder != null && _mediaRecorder!.state != 'inactive') {
      _mediaRecorder!.stop();
    }

    _mediaStream?.getTracks().forEach((track) {
      track.stop();
      _RecordingLogger.debug('Track stopped: ${track.kind}');
    });
  }

  static void _cancelRecording() {
    _RecordingLogger.info('Recording cancelled by user');
    _stopRecording();
    _recordedChunks.clear();
    hide();
    _onComplete?.call(null);
  }

  static Future<RecordingResult?> _processRecording() async {
    try {
      _RecordingLogger.info('Processing ${_recordedChunks.length} chunks...');

      if (_recordedChunks.isEmpty) {
        _RecordingLogger.warning('No chunks recorded');
        return null;
      }

      final blob = html.Blob(_recordedChunks, 'video/webm');
      _RecordingLogger.debug('Blob created: ${blob.size} bytes');

      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      _RecordingLogger.debug('Blob URL created');

      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      await reader.onLoadEnd.first;

      final Uint8List fileBytes = reader.result as Uint8List;
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

    // Use alignment-based positioning to avoid cutoff
    if (alignment == Alignment.topRight) {
      return Positioned(
        top: padding,
        right: padding,
        child: child,
      );
    } else if (alignment == Alignment.topLeft) {
      return Positioned(
        top: padding,
        left: padding,
        child: child,
      );
    } else if (alignment == Alignment.bottomRight) {
      return Positioned(
        bottom: padding,
        right: padding,
        child: child,
      );
    } else if (alignment == Alignment.bottomLeft) {
      return Positioned(
        bottom: padding,
        left: padding,
        child: child,
      );
    } else if (alignment == Alignment.topCenter) {
      return Positioned(
        top: padding,
        left: screenSize.width / 2 - 100, // Approximate centering
        child: child,
      );
    } else if (alignment == Alignment.bottomCenter) {
      return Positioned(
        bottom: padding,
        left: screenSize.width / 2 - 100, // Approximate centering
        child: child,
      );
    }

    // Default to top right
    return Positioned(
      top: padding,
      right: padding,
      child: child,
    );
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
                        const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
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
    // Generate unique view type for this video element
    _videoViewType = 'video-preview-${DateTime.now().millisecondsSinceEpoch}';

    // Register the video element view factory
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _videoViewType,
      (int viewId) {
        final videoElement = html.VideoElement()
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
