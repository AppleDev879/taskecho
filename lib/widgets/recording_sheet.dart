import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:interview_todos/models/openai_response.dart';
import 'package:interview_todos/providers/todo_provider.dart';
import 'package:path/path.dart' show basename;
import 'package:permission_handler/permission_handler.dart';

Future<void> requestMicPermissionAndShowModal(BuildContext context) async {
  final status = await Permission.microphone.request();
  debugPrint('Microphone permission status: $status');

  if (!context.mounted) return;

  if (status.isGranted) {
    showRecordingModal(context);
  } else if (status.isDenied) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Microphone permission is required to record audio.')));
  } else if (status.isPermanentlyDenied) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Please enable microphone permission in settings.')));
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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  // Local upload state variables
  UploadStatus _uploadStatus = UploadStatus.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);

    _waveAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _toggleRecording();
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _uploadRecording(File audioFile) async {
    setState(() {
      _uploadStatus = UploadStatus.loading;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('https://interviewapi.abarrett.io/parse-todo');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audioFile.path,
            filename: basename(audioFile.path),
            contentType: MediaType('audio', 'm4a'),
          ),
        )
        ..headers['Authorization'] = 'Bearer REMOVED'
        ..fields['userDateTime'] = DateTime.now().toIso8601String();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final items = jsonResponse['todos'] as List<dynamic>;
        final todoItems = items.map((item) => OpenAIResponse.fromJson(item)).toList();

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
      } else {
        setState(() {
          _uploadStatus = UploadStatus.error;
          _errorMessage = 'Failed with status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _uploadStatus = UploadStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final micStatus = await Permission.microphone.request();
      if (!mounted) return;
      if (!micStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied')));
        return;
      }

      await _recorder.openRecorder();
      await _recorder.startRecorder(toFile: 'recording.m4a', codec: Codec.aacMP4);

      setState(() {
        _isRecording = true;
      });
      _controller.repeat(reverse: true);
    } else {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      _controller.stop();

      if (path != null) {
        final file = File(path);
        await _uploadRecording(file);
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
