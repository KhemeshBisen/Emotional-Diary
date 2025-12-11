// lib/utils/audio_recorder.dart
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MyAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;
  bool _isRecording = false;

  Future<bool> _askMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start real audio recording
  Future<String?> startRecording() async {
    try {
      final hasPermission = await _askMicPermission();
      if (!hasPermission) {
        print('Microphone permission denied');
        return null;
      }

      // Check if already recording
      if (_isRecording) {
        print('Already recording');
        return null;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      _currentPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentPath!,
      );

      _isRecording = true;
      print('Recording started: $_currentPath');
      return _currentPath;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }

  /// Stop real audio recording and return the file
  Future<File?> stopRecording() async {
    try {
      if (!_isRecording || _currentPath == null) {
        print('Not recording or no path');
        return null;
      }

      // Stop recording
      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null) {
        print('Failed to stop recording');
        return null;
      }

      final file = File(path);
      if (!file.existsSync()) {
        print('Audio file does not exist: $path');
        return null;
      }

      final fileSize = await file.length();
      print('Recording stopped. File: $path, Size: $fileSize bytes');

      // Verify file has content (should be > 1000 bytes for real audio)
      if (fileSize < 1000) {
        print('Warning: Audio file is very small ($fileSize bytes)');
      }

      return file;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    _recorder.dispose();
  }
}
