import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service that handles audio recording functionality.
///
/// This service provides a high-level API for recording audio, managing the
/// recording state, and handling necessary permissions. It wraps the
/// FlutterSoundRecorder with additional error handling and state management.
class AudioRecorderService {
  /// The underlying FlutterSoundRecorder instance.
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  
  /// Tracks whether the recorder has been initialized.
  bool _isInitialized = false;
  
  /// Tracks whether the service has been disposed.
  bool _isDisposed = false;

  /// Initializes the audio recorder.
  ///
  /// This must be called before starting a recording. It's safe to call
  /// multiple times. If the recorder is already initialized, this is a no-op.
  ///
  /// Throws [StateError] if the service has been disposed.
  /// Throws [Exception] if initialization fails.
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed AudioRecorderService');
    }
    
    if (!_isInitialized) {
      try {
        await _recorder.openRecorder();
        _isInitialized = true;
      } catch (e) {
        _isInitialized = false;
        rethrow;
      }
    }
  }

  /// Releases all resources used by the audio recorder.
  ///
  /// This method should be called when the recorder is no longer needed.
  /// After calling this method, the service cannot be used anymore.
  ///
  /// This method is idempotent and safe to call multiple times.
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      if (_isInitialized) {
        // Stop any ongoing recording
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
        await _recorder.closeRecorder();
        _isInitialized = false;
      }
    } catch (e) {
      // Don't throw from dispose, but log the error
      debugPrint('Error disposing AudioRecorderService: $e');
    } finally {
      _isDisposed = true;
    }
  }

  /// Checks if the app has microphone permission.
  ///
  /// Returns `true` if the app has been granted microphone permission,
  /// `false` otherwise.
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Starts a new audio recording.
  ///
  /// Creates a new audio file in the system's temporary directory and starts
  /// recording to it. The file will be in AAC format with M4A container.
  ///
  /// Returns the path to the recording file if successful.
  ///
  /// Throws [StateError] if the service has been disposed.
  /// Throws [Exception] if the microphone permission is not granted or if
  /// starting the recording fails.
  Future<String> startRecording() async {
    if (_isDisposed) {
      throw StateError('Cannot start recording on a disposed AudioRecorderService');
    }
    
    if (!_isInitialized) {
      await initialize();
    }
    
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    try {
      final tempDir = Directory.systemTemp;
      final filePath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacMP4,
      );
      return filePath;
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  /// Stops the current recording.
  ///
  /// Returns a [File] object representing the recorded audio.
  ///
  /// Throws [StateError] if no recording is in progress.
  /// Throws [Exception] if stopping the recording fails.
  Future<File> stopRecording() async {
    if (_isDisposed) {
      throw StateError('Cannot stop recording on a disposed AudioRecorderService');
    }
    
    if (!_recorder.isRecording) {
      throw StateError('No recording in progress');
    }
    
    try {
      final path = await _recorder.stopRecorder();
      if (path == null) {
        throw Exception('Failed to stop recording: No file path returned');
      }
      return File(path);
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  /// Whether the recorder is currently recording.
  ///
  /// Returns `true` if a recording is in progress, `false` otherwise.
  bool get isRecording => !_isDisposed && _recorder.isRecording;
  
  /// Whether the service has been disposed.
  bool get isDisposed => _isDisposed;
}
