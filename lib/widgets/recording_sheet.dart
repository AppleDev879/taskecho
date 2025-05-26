import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:interview_todos/providers/todo_provider.dart';
import 'package:interview_todos/services/audio_recorder_service.dart';
import 'package:interview_todos/services/todo_parser_service.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestMicPermissionAndShowModal(BuildContext context) async {
  PermissionStatus status = await Permission.microphone.status;
  debugPrint('Microphone permission status: $status');
  if (!status.isGranted) {
    debugPrint('Requesting microphone permission...');
    status = await Permission.microphone.request();
    debugPrint('Microphone permission status after request: $status');
  }

  if (!context.mounted) return;

  if (status == PermissionStatus.granted) {
    showRecordingModal(context);
  } else if (status == PermissionStatus.denied) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission is required to record audio.')),
    );
  } else if (status == PermissionStatus.permanentlyDenied) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enable microphone permission in settings.')),
    );
  }
}

void showRecordingModal(BuildContext rootContext) {
  showModalBottomSheet(
    context: rootContext,
    isDismissible: true,
    backgroundColor: Colors.black87,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return RecordingSheet();
    },
  );
}

enum UploadStatus { idle, loading, success, error }

class RecordingSheet extends ConsumerStatefulWidget {
  final Future<void> Function(File audioFile)? onRecordingComplete;

  const RecordingSheet({super.key, this.onRecordingComplete});

  @override
  ConsumerState<RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends ConsumerState<RecordingSheet> with SingleTickerProviderStateMixin {
  late final AudioRecorderService _recorderService;
  bool _isRecording = false;
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  // Local upload state variables
  UploadStatus _uploadStatus = UploadStatus.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recorderService = AudioRecorderService();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _waveAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorderService.initialize();
      _toggleRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize recorder: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // Ensure we don't block the UI while disposing
    _recorderService.dispose().catchError((e) {
      debugPrint('Error disposing recorder: $e');
    });
    super.dispose();
  }

  Future<void> _uploadRecording(File audioFile) async {
    setState(() {
      _uploadStatus = UploadStatus.loading;
      _errorMessage = null;
    });

    // Use a local client that we can close
    final client = http.Client();
    try {
      final todoParser = TodoParserService(client: client);
      final todoItems = await todoParser.parseAudio(audioFile);

      if (!mounted) return;
      
      setState(() {
        _uploadStatus = UploadStatus.success;
      });

      // Add todos to the list
      ref.read(todoListProvider.notifier).addTodosFromOpenAI(responses: todoItems);

      // Optionally call the onRecordingComplete callback
      if (widget.onRecordingComplete != null) {
        await widget.onRecordingComplete!(audioFile);
      }

      // Close the sheet automatically after success
      if (mounted) Navigator.of(context).pop(todoItems);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadStatus = UploadStatus.error;
          _errorMessage = e.toString();
        });
      }
      rethrow;
    } finally {
      // Always clean up resources
      client.close();
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp audio file: $e');
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      try {
        await _recorderService.startRecording();
        if (!mounted) return;
        
        setState(() {
          _isRecording = true;
        });
        _controller.repeat(reverse: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start recording: ${e.toString()}')),
          );
        }
        return;
      }
    } else {
      try {
        final file = await _recorderService.stopRecording();
        if (!mounted) return;
        
        _controller.reset();
        setState(() {
          _isRecording = false;
        });

        if (await file.exists()) {
          await _uploadRecording(file);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop recording: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _toggleRecording,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (_, __) => Container(
                          width: 120 * _waveAnimation.value,
                          height: 120 * _waveAnimation.value,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                      ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                      child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_uploadStatus == UploadStatus.loading) const CircularProgressIndicator(),

              if (_uploadStatus == UploadStatus.error)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorMessage ?? 'Unknown error', style: const TextStyle(color: Colors.redAccent)),
                ),

              if (_uploadStatus == UploadStatus.success)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
