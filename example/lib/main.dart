import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter_web_record/flutter_web_record.dart';
// Import your screen recorder file here
// import 'your_screen_recorder.dart';

void main() {
  runApp(const ScreenRecorderTestApp());
}

class ScreenRecorderTestApp extends StatelessWidget {
  const ScreenRecorderTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Recorder Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestHomePage(),
    );
  }
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key});

  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  List<RecordingResult> _recordings = [];
  String _status = 'Ready to record';

  void _updateStatus(String status) {
    setState(() {
      _status = status;
    });
    // print('📱 Status: $status');
  }

  Future<void> _testBasicRecording() async {
    _updateStatus('Starting basic recording...');

    try {
      final result = await ScreenRecorder.startRecording(
        context,
        onRecordingComplete: (result) {
          _updateStatus('✅ Basic recording complete!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar('Recording saved: ${result.fileName}');
        },
        onRecordingCancelled: () {
          _updateStatus('❌ Recording cancelled');
        },
      );

      if (result == null) {
        _updateStatus('⚠️ No result returned');
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testWithPreview() async {
    _updateStatus('Starting recording with preview...');

    try {
      await ScreenRecorder.startRecording(
        context,
        showPreview: true,
        onRecordingComplete: (result) {
          _updateStatus('✅ Recording with preview complete!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar('Preview confirmed and saved!');
        },
        onRecordingCancelled: () {
          _updateStatus('❌ Recording cancelled or discarded');
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testCustomStyling() async {
    _updateStatus('Starting recording with custom styling...');

    try {
      await ScreenRecorder.startRecording(
        context,
        indicatorConfig: RecordingIndicatorConfig(
          recordingColor: Colors.purple,
          pausedColor: Colors.amber,
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          borderWidth: 3.0,
          borderRadius: 20.0,
          position: Alignment.topLeft,
          timeTextStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        controlConfig: ControlButtonConfig(
          pauseColor: Colors.amber,
          stopColor: Colors.purple,
          cancelColor: Colors.red,
          buttonSize: 40.0,
          iconSize: 24.0,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ Custom styled recording complete!');
          setState(() {
            _recordings.add(result);
          });
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testHighQuality() async {
    _updateStatus('Starting high quality recording...');

    try {
      await ScreenRecorder.startRecording(
        context,
        recordingConfig: RecordingConfig(
          idealWidth: 2560,
          idealHeight: 1440,
          idealFrameRate: 60,
          videoBitsPerSecond: 8000000,
          captureAudio: true,
          showCursor: true,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ High quality recording complete!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar(
              'HQ: ${(result.fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testNoAudio() async {
    _updateStatus('Starting recording without audio...');

    try {
      await ScreenRecorder.startRecording(
        context,
        recordingConfig: const RecordingConfig(
          audioCaptureMode: AudioCaptureMode.none,
          showCursor: false,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ Silent recording complete!');
          setState(() {
            _recordings.add(result);
          });
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testSystemAudio() async {
    _updateStatus('Starting recording with system audio...');

    try {
      await ScreenRecorder.startRecording(
        context,
        recordingConfig: const RecordingConfig(
          audioCaptureMode: AudioCaptureMode.system,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ System audio recording complete!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar('System audio captured!');
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testMicrophoneAudio() async {
    _updateStatus('Starting recording with microphone...');

    try {
      await ScreenRecorder.startRecording(
        context,
        recordingConfig: const RecordingConfig(
          audioCaptureMode: AudioCaptureMode.microphone,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ Microphone recording complete!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar('Microphone audio captured!');
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testBothAudio() async {
    _updateStatus('Starting recording with system + microphone...');

    try {
      await ScreenRecorder.startRecording(
        context,
        recordingConfig: const RecordingConfig(
          audioCaptureMode: AudioCaptureMode.both,
        ),
        onRecordingComplete: (result) {
          _updateStatus('✅ Both audio sources recorded!');
          setState(() {
            _recordings.add(result);
          });
          _showSuccessSnackbar('System + Mic captured!');
        },
      );
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _clearRecordings() {
    setState(() {
      _recordings.clear();
      _status = 'Ready to record';
    });
  }

  List<Widget> _buildTestWidgets() {
    return [
      _buildTestButton(
        'Test 1: Basic Recording',
        'Test default recording with no customization',
        Icons.videocam,
        Colors.blue,
        _testBasicRecording,
      ),
      _buildTestButton(
        'Test 2: With Preview',
        'Test recording with preview dialog',
        Icons.preview,
        Colors.green,
        _testWithPreview,
      ),
      _buildTestButton(
        'Test 3: Custom Styling',
        'Test custom colors, sizes, and positions',
        Icons.palette,
        Colors.purple,
        _testCustomStyling,
      ),
      _buildTestButton(
        'Test 4: High Quality',
        'Test 1440p @ 60fps recording',
        Icons.hd,
        Colors.orange,
        _testHighQuality,
      ),
      _buildTestButton(
        'Test 5: No Audio',
        'Test recording without audio and cursor',
        Icons.volume_off,
        Colors.red,
        _testNoAudio,
      ),
      _buildTestButton(
        'Test 6: System Audio',
        'Record audio playing on your computer',
        Icons.volume_up,
        Colors.teal,
        _testSystemAudio,
      ),
      _buildTestButton(
        'Test 7: Microphone',
        'Record only microphone audio',
        Icons.mic,
        Colors.indigo,
        _testMicrophoneAudio,
      ),
      _buildTestButton(
        'Test 8: System + Microphone',
        'Record both system audio and microphone',
        Icons.surround_sound,
        Colors.deepPurple,
        _testBothAudio,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final testWidgets = _buildTestWidgets();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Recorder Test Suite'),
        actions: [
          if (_recordings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all recordings',
              onPressed: _clearRecordings,
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Test Buttons
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Test Cases',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid for test buttons: 2 per row, smaller boxes
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio:
                        4.5, // Increased to make boxes shorter and more compact
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: testWidgets.length,
                  itemBuilder: (context, index) => testWidgets[index],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Recordings List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recordings (${_recordings.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_recordings.isNotEmpty)
                      Text(
                        'Total: ${_getTotalSize()} MB',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_recordings.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No recordings yet.\nTry recording something!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._recordings.asMap().entries.map((entry) {
                    final index = entry.key;
                    final recording = entry.value;
                    return _buildRecordingCard(index, recording);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(
              12), // Reduced padding for smaller appearance
          child: Row(
            children: [
              Container(
                width: 40, // Slightly smaller icon container
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24), // Smaller icon
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15, // Slightly smaller title
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12, // Smaller description font
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow, size: 20), // Smaller play icon
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingCard(int index, RecordingResult recording) {
    final sizeInMB =
        (recording.fileBytes.length / 1024 / 1024).toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text('${index + 1}'),
        ),
        title: Text(recording.fileName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duration: ${recording.durationSeconds}s'),
            Text('Size: $sizeInMB MB'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Colors.green),
              tooltip: 'Play video',
              onPressed: () => _showVideoPlayer(recording),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Show info',
              onPressed: () => _showRecordingInfo(recording),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
              onPressed: () {
                setState(() {
                  _recordings.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(RecordingResult recording) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(recording: recording),
    );
  }

  void _showRecordingInfo(RecordingResult recording) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('File Name:', recording.fileName),
            _buildInfoRow('Duration:', '${recording.durationSeconds} seconds'),
            _buildInfoRow('Size:',
                '${(recording.fileBytes.length / 1024 / 1024).toStringAsFixed(2)} MB'),
            _buildInfoRow('MIME Type:', recording.mimeType),
            _buildInfoRow('Bytes:', '${recording.fileBytes.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getTotalSize() {
    final totalBytes = _recordings.fold<int>(
      0,
      (sum, recording) => sum + recording.fileBytes.length,
    );
    return (totalBytes / 1024 / 1024).toStringAsFixed(2);
  }
}

// ============================================================================
// VIDEO PLAYER DIALOG
// ============================================================================

class VideoPlayerDialog extends StatefulWidget {
  final RecordingResult recording;

  const VideoPlayerDialog({super.key, required this.recording});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late String _videoViewType;

  @override
  void initState() {
    super.initState();
    // Generate unique view type for this video element
    _videoViewType = 'video-player-${DateTime.now().millisecondsSinceEpoch}';

    // Import dart:ui as ui and dart:html as html at the top of the file
    // Register the video element view factory
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _videoViewType,
      (int viewId) {
        final videoElement = html.VideoElement()
          ..src = widget.recording.blobUrl
          ..controls = true
          ..autoplay = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.border = 'none'
          ..style.backgroundColor = 'black';
        return videoElement;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeInMB =
        (widget.recording.fileBytes.length / 1024 / 1024).toStringAsFixed(2);

    return Dialog(
      backgroundColor: Colors.black,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recording.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.recording.durationSeconds}s • $sizeInMB MB',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Video Player
            Expanded(
              child: Container(
                color: Colors.black,
                child: HtmlElementView(viewType: _videoViewType),
              ),
            ),

            // Footer with controls
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Copy URL to clipboard or download
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video URL: Available for download'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Copy Link'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
