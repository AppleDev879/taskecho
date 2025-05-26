import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:interview_todos/providers/todo_provider.dart';
import 'package:interview_todos/services/audio_recorder_service.dart';
import 'package:interview_todos/services/todo_parser_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shows a dialog to request microphone permission and displays the recording UI.
///
/// This is a convenience function that checks the current microphone permission status
/// and shows the appropriate UI. If permission is granted, it shows the recording
/// sheet. If permission is denied, it shows a snackbar with instructions.
///
/// The [context] parameter is used to show the recording modal and must not be null.
/// It should be the BuildContext of the widget that is triggering the recording.

/// Requests microphone permission and shows the recording modal if granted.
///
/// This function handles the entire permission flow:
/// 1. Checks current permission status
/// 2. Requests permission if not already granted
/// 3. Shows appropriate UI based on the permission result
/// 4. Handles the case where the permission was permanently denied
///
/// The [context] parameter is used to show the recording modal and must not be null.
Future<void> requestMicPermissionAndShowModal(BuildContext context) async {
  // Check current permission status
  PermissionStatus status = await Permission.microphone.status;
  debugPrint('Microphone permission status: $status');
  
  // Request permission if not already granted
  if (!status.isGranted) {
    debugPrint('Requesting microphone permission...');
    status = await Permission.microphone.request();
    debugPrint('Microphone permission status after request: $status');
  }

  // Return if the widget was disposed while waiting for permission
  if (!context.mounted) return;

  // Handle the permission result
  if (status == PermissionStatus.granted) {
    showRecordingModal(context);
  } else if (status == PermissionStatus.denied) {
    // Show a message that the user needs to grant permission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Microphone permission is required to record audio.')),
    );
  } else if (status == PermissionStatus.permanentlyDenied) {
    // Guide the user to app settings to enable the permission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enable microphone permission in settings.'),
        duration: Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OPEN SETTINGS',
          onPressed: openAppSettings,
        ),
      ),
    );
  }
}

/// Displays the recording modal bottom sheet.
///
/// This function creates and shows a modal bottom sheet that contains the
/// [RecordingSheet] widget. The modal has a semi-transparent black background
/// and rounded top corners for a modern look.
///
/// The [rootContext] parameter is used to show the modal and must not be null.
void showRecordingModal(BuildContext rootContext) {
  showModalBottomSheet(
    context: rootContext,
    isDismissible: true,
    backgroundColor: Colors.black87,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    enableDrag: true,
    builder: (context) {
      return const RecordingSheet();
    },
  );
}

/// Represents the current status of an audio upload operation.
enum UploadStatus {
  /// No upload in progress
  idle,
  
  /// Upload is in progress
  loading,
  
  /// Upload completed successfully
  success,
  
  /// Upload failed with an error
  error,
}

/// A bottom sheet widget that allows users to record audio and process it.
///
/// This widget provides a user interface for recording audio, displaying recording
/// state with animations, and handling the upload/processing of the recorded audio.
/// It uses [AudioRecorderService] for recording functionality and communicates
/// with the parent widget through the [onRecordingComplete] callback.
class RecordingSheet extends ConsumerStatefulWidget {
  /// Callback that's called when recording is completed and processed.
  ///
  /// This callback receives the recorded audio file as a parameter.
  final Future<void> Function(File audioFile)? onRecordingComplete;

  /// Creates a [RecordingSheet] widget.
  ///
  /// The [key] parameter is passed to the superclass.
  /// The [onRecordingComplete] callback is optional and will be called
  /// when the recording is successfully processed.
  const RecordingSheet({
    super.key,
    this.onRecordingComplete,
  });

  @override
  ConsumerState<RecordingSheet> createState() => _RecordingSheetState();
}

/// The state for the [RecordingSheet] widget.
///
/// This class manages the recording state, animations, and handles the recording
/// lifecycle. It communicates with the [AudioRecorderService] to perform
/// actual audio recording operations.
class _RecordingSheetState extends ConsumerState<RecordingSheet> with SingleTickerProviderStateMixin {
  /// Service responsible for handling audio recording functionality.
  late final AudioRecorderService _recorderService;
  
  /// Whether a recording is currently in progress.
  bool _isRecording = false;
  
  /// Controller for managing the recording animation.
  late AnimationController _controller;
  
  /// Animation that creates a pulsing effect for the recording button.
  late Animation<double> _waveAnimation;

  /// The current status of the audio upload/processing operation.
  UploadStatus _uploadStatus = UploadStatus.idle;
  
  /// Error message to display if the upload/processing fails.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initialize the audio recorder service
    _recorderService = AudioRecorderService();
    
    // Set up the animation controller with a duration of 800ms
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this, // Use this State as the TickerProvider
    );

    // Create a pulsing animation that scales between 1.0 and 1.4
    _waveAnimation = Tween<double>(
      begin: 1.0,
      end: 1.4,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Initialize the recorder and start recording
    _initRecorder();
  }

  /// Initializes the audio recorder and starts recording.
  ///
  /// This method is called during initialization to set up the audio recorder.
  /// If initialization is successful, it automatically starts a new recording.
  /// If an error occurs, it shows an error message to the user.
  Future<void> _initRecorder() async {
    try {
      // Initialize the audio recorder
      await _recorderService.initialize();
      
      // Start recording immediately after initialization
      _toggleRecording();
    } catch (e) {
      // Only show error if the widget is still in the widget tree
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize recorder: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Stop any ongoing animations
    _controller.dispose();
    
    // Clean up the recorder service
    // Using catchError to prevent unhandled exceptions in the dispose method
    _recorderService.dispose().catchError((e) {
      debugPrint('Error disposing recorder: $e');
    });
    
    // Call the parent's dispose method
    super.dispose();
  }

  /// Handles the upload and processing of a recorded audio file.
  ///
  /// This method:
  /// 1. Sets the upload status to loading
  /// 2. Processes the audio file using [TodoParserService]
  /// 3. Updates the UI based on the result
  /// 4. Cleans up resources when done
  ///
  /// The [audioFile] parameter is the recorded audio file to process.
  Future<void> _uploadRecording(File audioFile) async {
    // Update UI to show loading state
    setState(() {
      _uploadStatus = UploadStatus.loading;
      _errorMessage = null;
    });

    // Create a new HTTP client for this request
    final client = http.Client();
    try {
      // Parse the audio file to extract todos
      final todoParser = TodoParserService(client: client);
      final todoItems = await todoParser.parseAudio(audioFile);

      // If the widget was disposed during the async operation, bail out
      if (!mounted) return;
      
      // Update UI to show success
      setState(() {
        _uploadStatus = UploadStatus.success;
      });

      // Add the parsed todos to the list
      ref.read(todoListProvider.notifier).addTodosFromOpenAI(responses: todoItems);

      // Notify parent widget if callback is provided
      if (widget.onRecordingComplete != null) {
        await widget.onRecordingComplete!(audioFile);
      }

      // Close the sheet if still mounted
      if (mounted) Navigator.of(context).pop(todoItems);
    } catch (e) {
      // Update UI to show error
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
        // Delete the temporary audio file
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp audio file: $e');
      }
    }
  }

  /// Toggles the recording state between recording and stopped.
  ///
  /// This method handles both starting and stopping the recording:
  /// - When starting: Initializes the recording and starts the animation
  /// - When stopping: Stops the recording, resets the animation, and processes the file
  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      // Start recording
      try {
        await _recorderService.startRecording();
        
        // Check if the widget is still mounted after async operation
        if (!mounted) return;
        
        // Update UI to show recording state
        setState(() {
          _isRecording = true;
        });
        
        // Start the pulsing animation
        _controller.repeat(reverse: true);
      } catch (e) {
        // Show error if something went wrong
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start recording: ${e.toString()}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    } else {
      // Stop recording
      try {
        // Stop the recording and get the file
        final file = await _recorderService.stopRecording();
        
        // Check if the widget is still mounted after async operation
        if (!mounted) return;
        
        // Reset the animation
        _controller.reset();
        
        // Update UI to show stopped state
        setState(() {
          _isRecording = false;
        });

        // Process the recorded file if it exists
        if (await file.exists()) {
          await _uploadRecording(file);
        }
      } catch (e) {
        // Show error if something went wrong
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to stop recording: ${e.toString()}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  /// Builds the recording sheet UI.
  ///
  /// The UI consists of:
  /// - A large circular recording button with a pulsing animation when active
  /// - Status indicators for loading, success, and error states
  /// - Error messages when something goes wrong
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        // Fixed height to prevent UI jumping when state changes
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recording button with animation
              GestureDetector(
                onTap: _toggleRecording,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing animation background (only shown when recording)
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (_, __) => Container(
                          width: 120 * _waveAnimation.value,
                          height: 120 * _waveAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    // Main recording button
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : Colors.redAccent.withValues(alpha: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Status indicators
              if (_uploadStatus == UploadStatus.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Processing your recording...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

              if (_uploadStatus == UploadStatus.error)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage ?? 'An unknown error occurred',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_uploadStatus == UploadStatus.success)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Todo created successfully!',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Recording indicator
              if (_isRecording)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Recording... Tap to stop',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
