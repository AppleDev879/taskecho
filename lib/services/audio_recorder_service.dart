import 'dart:async';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _recorder.openRecorder();
      _isInitialized = true;
    }
  }

  Future<void> dispose() async {
    if (_isInitialized) {
      await _recorder.closeRecorder();
      _isInitialized = false;
    }
  }

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  Future<String?> startRecording() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final tempDir = Directory.systemTemp;
    final filePath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.startRecorder(toFile: filePath, codec: Codec.aacMP4);
    return filePath;
  }

  Future<File> stopRecording() async {
    final path = await _recorder.stopRecorder();
    if (path == null) {
      throw Exception('Failed to stop recording');
    }
    return File(path);
  }

  bool get isRecording => _recorder.isRecording;
}
