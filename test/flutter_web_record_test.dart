@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_record/flutter_web_record.dart';
import 'dart:typed_data';

void main() {
  group('RecordingConfig', () {
    test('has correct default values', () {
      const config = RecordingConfig(
        idealWidth: 1920,
        idealHeight: 1080,
        idealFrameRate: 30,
        videoBitsPerSecond: 5000000,
        captureAudio: true,
        showCursor: true,
        audioCaptureMode: AudioCaptureMode.system,
      );

      expect(config.idealWidth, 1920);
      expect(config.idealHeight, 1080);
      expect(config.idealFrameRate, 30);
      expect(config.captureAudio, true);
      expect(config.showCursor, true);
    });

    test('can create custom config', () {
      const config = RecordingConfig(
        idealWidth: 1280,
        idealHeight: 720,
        idealFrameRate: 60,
        captureAudio: false,
      );

      expect(config.idealWidth, 1280);
      expect(config.idealHeight, 720);
      expect(config.idealFrameRate, 60);
      expect(config.captureAudio, false);
    });
  });

  group('AudioCaptureMode', () {
    test('has all modes available', () {
      expect(AudioCaptureMode.values, [
        AudioCaptureMode.system,
        AudioCaptureMode.microphone,
        AudioCaptureMode.both,
        AudioCaptureMode.none,
      ]);
    });
  });

  group('RecordingIndicatorConfig', () {
    test('has correct default values', () {
      const config = RecordingIndicatorConfig();

      expect(config.recordingColor, Colors.red);
      expect(config.pausedColor, Colors.orange);
      expect(config.backgroundColor, Colors.black87);
      expect(config.borderWidth, 2.0);
      expect(config.borderRadius, 12.0);
    });
  });

  group('ControlButtonConfig', () {
    test('has correct default values', () {
      const config = ControlButtonConfig();

      expect(config.pauseColor, Colors.orange);
      expect(config.stopColor, Colors.red);
      expect(config.cancelColor, Colors.grey);
      expect(config.buttonSize, 32.0);
      expect(config.iconSize, 18.0);
    });
  });

  group('RecordingResult', () {
    test('creates valid result', () {
      final result = RecordingResult(
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'test.webm',
        mimeType: 'video/webm',
        blobUrl: 'blob:test',
        durationSeconds: 10,
      );

      expect(result.fileName, 'test.webm');
      expect(result.mimeType, 'video/webm');
      expect(result.durationSeconds, 10);
      expect(result.fileBytes.length, 3);
    });

    test('toMap returns correct structure', () {
      final result = RecordingResult(
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'test.webm',
        mimeType: 'video/webm',
        blobUrl: 'blob:test',
        durationSeconds: 10,
      );

      final map = result.toMap();

      expect(map['fileName'], 'test.webm');
      expect(map['mimeType'], 'video/webm');
      expect(map['duration'], 10);
      expect(map['url'], 'blob:test');
      expect(map.containsKey('fileBytes'), true);
    });
  });
}
