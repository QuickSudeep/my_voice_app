import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

enum RecordingState {
  idle,
  recording,
  paused,
  processing,
  error,
}

class VoiceService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle;
  String? _currentFilePath;
  String _statusMessage =
      'नमस्ते (Namaste)\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
  String? _errorMessage;
  Duration _recordingDuration = Duration.zero;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  int _silenceCounter = 0;
  final _player = AudioPlayer();
  String? _currentApiUrl;

  RecordingState get state => _state;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get currentFilePath => _currentFilePath;
  Duration get recordingDuration => _recordingDuration;
  bool get isRecording => _state == RecordingState.recording;
  bool get isPaused => _state == RecordingState.paused;

  /// Initialize the voice service
  Future<void> init() async {
    try {
      final dir = await _recordingsDir;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      debugPrint("Recordings directory: ${dir.path}");
    } catch (e) {
      debugPrint("Init error: $e");
    }
  }

  /// Check and request microphone permission
  Future<bool> checkPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.microphone.status;

      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }

      if (status.isPermanentlyDenied) {
        _setError(
            'Microphone permission permanently denied. Please enable it in settings.');
        return false;
      }

      return status.isGranted;
    }

    // On desktop platforms, assume permission is granted
    return true;
  }

  /// Start recording
  Future<String?> startRecording({
    bool autoStop = false,
    double threshold = -45.0,
    int silenceDuration = 2,
    String? fastApiUrl,
  }) async {
    _currentApiUrl = fastApiUrl;
    try {
      // Check permission first
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        _setError('Microphone permission not granted');
        return null;
      }

      // Check if already recording
      if (_state == RecordingState.recording) {
        debugPrint("Already recording");
        return _currentFilePath;
      }


      final dir = await _recordingsDir;
      final fileName = Platform.isWindows || Platform.isLinux
          ? 'recording_${const Uuid().v4()}.wav'
          : 'recording_${const Uuid().v4()}.m4a';
      final outputPath = p.join(dir.path, fileName);
      _currentFilePath = outputPath;

      // Configure recording - use WAV for Windows/Linux, AAC for mobile
      final config = RecordConfig(
        encoder: Platform.isWindows || Platform.isLinux
            ? AudioEncoder.wav
            : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100, // Standard sample rate
        numChannels: 1,
      );

      // Start recording
      await _recorder.start(config, path: outputPath);

      _state = RecordingState.recording;
      _statusMessage = 'सुन्दै छु...\n(Listening...)';
      _errorMessage = null;
      _recordingDuration = Duration.zero;
      notifyListeners();

      // Start duration tracking
      _startDurationTracking();

      // Start amplitude monitoring for auto-stop
      if (autoStop) {
        _startAmplitudeMonitoring(threshold, silenceDuration);
      }

      debugPrint("Recording started: $outputPath");
      return outputPath;
    } catch (e) {
      _setError('Failed to start recording: $e');
      debugPrint("Start recording error: $e");
      return null;
    }
  }

  /// Stop recording
  Future<String?> stopRecording({String? fastApiUrl}) async {
    try {
      if (_state != RecordingState.recording &&
          _state != RecordingState.paused) {
        debugPrint("Not currently recording");
        return null;
      }

      _state = RecordingState.processing;
      _statusMessage = 'प्रशोधन गर्दै...\n(Processing...)';
      notifyListeners();

      // Stop monitoring
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      // Stop recording
      final path = await _recorder.stop();

      _state = RecordingState.idle;
      _statusMessage = 'रेकर्डिङ सुरक्षित भयो\n(Recording saved)';
      _errorMessage = null;
      notifyListeners();

      debugPrint("Recording stopped: $path");

      // Reset duration
      _recordingDuration = Duration.zero;

      if (path != null) {
        // Upload audio to server and play back the response
        _uploadAndPlay(path, fastApiUrl);
      }

      return path ?? _currentFilePath;
    } catch (e) {
      _setError('Failed to stop recording: $e');
      debugPrint("Stop recording error: $e");
      return null;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    try {
      if (_state != RecordingState.recording) return;

      await _recorder.pause();
      _state = RecordingState.paused;
      _statusMessage = 'रोकिएको\n(Paused)';
      notifyListeners();
    } catch (e) {
      _setError('Failed to pause recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    try {
      if (_state != RecordingState.paused) return;

      await _recorder.resume();
      _state = RecordingState.recording;
      _statusMessage = 'सुन्दै छु...\n(Listening...)';
      notifyListeners();
    } catch (e) {
      _setError('Failed to resume recording: $e');
    }
  }

  /// Cancel recording (stop and delete file)
  Future<void> cancelRecording() async {
    try {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      await _recorder.stop();

      if (_currentFilePath != null) {
        final file = File(_currentFilePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _state = RecordingState.idle;
      _statusMessage = 'रद्द गरियो\n(Cancelled)';
      _currentFilePath = null;
      _recordingDuration = Duration.zero;
      notifyListeners();
    } catch (e) {
      _setError('Failed to cancel recording: $e');
    }
  }

  /// Get all recordings
  Future<List<FileSystemEntity>> getRecordings() async {
    try {
      final dir = await _recordingsDir;
      if (!await dir.exists()) return [];

      final recordings = dir.listSync()
        ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return recordings.where((f) => f is File).toList();
    } catch (e) {
      debugPrint("Error getting recordings: $e");
      return [];
    }
  }

  /// Delete a recording
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting recording: $e");
      return false;
    }
  }

  /// Get recording file size
  Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  /// Set error state
  void _setError(String message) {
    _state = RecordingState.error;
    _errorMessage = message;
    _statusMessage = 'त्रुटि\n(Error)';
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_state == RecordingState.error) {
      _state = RecordingState.idle;
      _statusMessage =
          'नमस्ते (Namaste)\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
      notifyListeners();
    }
  }

  /// Track recording duration
  void _startDurationTracking() {
    Future.doWhile(() async {
      if (_state == RecordingState.recording) {
        await Future.delayed(const Duration(seconds: 1));
        _recordingDuration = _recordingDuration + const Duration(seconds: 1);
        notifyListeners();
        return true;
      }
      return false;
    });
  }

  /// Monitor amplitude for silence detection
  void _startAmplitudeMonitoring(double threshold, int silenceDuration) {
    _silenceCounter = 0;
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 500))
        .listen((amp) {
      if (_state == RecordingState.recording) {
        if (amp.current < threshold) {
          _silenceCounter++;
          debugPrint("Silence detected: $_silenceCounter/ ${silenceDuration * 2}");
          if (_silenceCounter >= silenceDuration * 2) {
            debugPrint("Auto-stopping due to silence");
            stopRecording(fastApiUrl: _currentApiUrl);
          }
        } else {
          _silenceCounter = 0;
        }
      }
    });
  }

  /// Directory for recordings (Requests)
  Future<Directory> get _recordingsDir async {
    Directory base;
    if (Platform.isAndroid || Platform.isIOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = Directory.current;
    }
    final dir = Directory(p.join(base.path, 'VoiceApp', 'Requests'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Upload audio to server and play the response
  Future<void> _uploadAndPlay(String audioFilePath, String? url) async {
    if (url == null || url.isEmpty) {
      debugPrint("No server URL configured — skipping upload.");
      _statusMessage = 'नमस्ते (Namaste)\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
      notifyListeners();
      return;
    }

    try {
      debugPrint("Uploading audio to: $url");
      _statusMessage = 'सर्भरमा पठाउँदै...\n(Sending to server...)';
      notifyListeners();

      final file = File(audioFilePath);
      if (!await file.exists()) {
        _setError('Recording file not found: $audioFilePath');
        return;
      }

      // Build multipart request
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(
        'audio',         // field name the server expects
        audioFilePath,
        filename: p.basename(audioFilePath),
      ));

      _statusMessage = 'प्रशोधन गर्दै...\n(Processing on server...)';
      notifyListeners();

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Server did not respond in 60s'),
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        _setError('Server error ${streamedResponse.statusCode}: $body');
        return;
      }

      // Read response audio bytes
      final responseBytes = await streamedResponse.stream.toBytes();
      if (responseBytes.isEmpty) {
        _setError('Server returned empty audio response');
        return;
      }

      debugPrint("Received ${responseBytes.length} bytes of audio from server");

      // Save to a temp file so just_audio can play it
      final tempDir = await getTemporaryDirectory();
      final contentType = streamedResponse.headers['content-type'] ?? '';
      final ext = _extensionFromContentType(contentType);
      final tempFile = File(p.join(tempDir.path, 'response_audio$ext'));
      await tempFile.writeAsBytes(responseBytes);

      debugPrint("Saved response audio to: ${tempFile.path}");

      // Play the response
      _statusMessage = 'जवाफ बज्दै छ...\n(Playing response...)';
      notifyListeners();

      await _player.stop();
      await _player.setAudioSource(AudioSource.file(tempFile.path));
      await _player.setVolume(1.0);
      await _player.play();

      // Wait for playback to complete
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed,
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () => ProcessingState.idle,
      );

      debugPrint("Playback complete");
    } on TimeoutException catch (e) {
      _setError('Timeout: ${e.message}');
      return;
    } catch (e) {
      debugPrint("Upload/play error: $e");
      _setError('Failed to get response: $e');
      return;
    }

    _statusMessage = 'नमस्ते (Namaste)\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
    notifyListeners();
  }

  /// Determine audio file extension from Content-Type header
  String _extensionFromContentType(String contentType) {
    if (contentType.contains('mpeg') || contentType.contains('mp3')) return '.mp3';
    if (contentType.contains('wav')) return '.wav';
    if (contentType.contains('ogg')) return '.ogg';
    if (contentType.contains('aac')) return '.aac';
    if (contentType.contains('mp4') || contentType.contains('m4a')) return '.m4a';
    return '.audio'; // fallback — just_audio will try to infer format
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
