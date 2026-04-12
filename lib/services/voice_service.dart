import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../models/server_response.dart';
import '../models/reminder_model.dart';

enum RecordingState { idle, recording, paused, processing, error }

/// Callback invoked when the server requests a reminder/call action.
typedef OnSetReminder = Future<void> Function(Reminder reminder);
typedef OnMakeCall    = Future<void> Function(String phone);

class VoiceService extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();

  RecordingState _state           = RecordingState.idle;
  String?        _currentFilePath;
  String         _statusMessage   =
      'नमस्ते!\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
  String?        _errorMessage;
  String?        _lastResponseText;
  Duration       _recordingDuration = Duration.zero;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  int            _silenceCounter  = 0;
  String?        _currentApiUrl;

  // Callbacks wired by main.dart to cross-service actions
  OnSetReminder? onSetReminder;
  OnMakeCall?    onMakeCall;

  RecordingState get state             => _state;
  String         get statusMessage     => _statusMessage;
  String?        get errorMessage      => _errorMessage;
  String?        get currentFilePath   => _currentFilePath;
  Duration       get recordingDuration => _recordingDuration;
  bool           get isRecording       => _state == RecordingState.recording;
  bool           get isPaused          => _state == RecordingState.paused;
  String?        get lastResponseText  => _lastResponseText;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    try {
      final dir = await _recordingsDir;
      if (!await dir.exists()) await dir.create(recursive: true);
      debugPrint('Recordings dir: ${dir.path}');
    } catch (e) {
      debugPrint('VoiceService init error: $e');
    }
  }

  // ─── Permission ───────────────────────────────────────────────────────────

  Future<bool> checkPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.microphone.status;
      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
      if (status.isPermanentlyDenied) {
        _setError('Microphone permission permanently denied.');
        return false;
      }
      return status.isGranted;
    }
    return true; // Desktop
  }

  // ─── Recording ────────────────────────────────────────────────────────────

  Future<String?> startRecording({
    bool   autoStop       = false,
    double threshold      = -45.0,
    int    silenceDuration = 2,
    String? fastApiUrl,
  }) async {
    _currentApiUrl = fastApiUrl;
    try {
      final hasPermission = await checkPermission();
      if (!hasPermission) { _setError('Microphone permission not granted'); return null; }
      if (_state == RecordingState.recording) return _currentFilePath;

      final dir      = await _recordingsDir;
      final ext      = (Platform.isWindows || Platform.isLinux) ? 'wav' : 'm4a';
      final fileName = 'recording_${const Uuid().v4()}.$ext';
      final outputPath = p.join(dir.path, fileName);
      _currentFilePath = outputPath;

      final config = RecordConfig(
        encoder: (Platform.isWindows || Platform.isLinux)
            ? AudioEncoder.wav
            : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      await _recorder.start(config, path: outputPath);
      _state            = RecordingState.recording;
      _statusMessage    = 'सुन्दै छु...\n(Listening...)';
      _lastResponseText = null;
      _errorMessage     = null;
      _recordingDuration = Duration.zero;
      notifyListeners();

      _startDurationTracking();
      if (autoStop) _startAmplitudeMonitoring(threshold, silenceDuration);

      debugPrint('Recording started: $outputPath');
      return outputPath;
    } catch (e) {
      _setError('Failed to start recording: $e');
      return null;
    }
  }

  Future<String?> stopRecording({String? fastApiUrl}) async {
    try {
      if (_state != RecordingState.recording && _state != RecordingState.paused) return null;

      _state         = RecordingState.processing;
      _statusMessage = 'प्रशोधन गर्दै...\n(Processing...)';
      notifyListeners();

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      final path = await _recorder.stop();
      _state             = RecordingState.idle;
      _statusMessage     = 'पठाउँदै...\n(Sending...)';
      _errorMessage      = null;
      _recordingDuration = Duration.zero;
      notifyListeners();

      if (path != null) {
        _uploadAndPlay(path, fastApiUrl ?? _currentApiUrl);
      }

      return path ?? _currentFilePath;
    } catch (e) {
      _setError('Failed to stop recording: $e');
      return null;
    }
  }

  Future<void> pauseRecording() async {
    try {
      if (_state != RecordingState.recording) return;
      await _recorder.pause();
      _state         = RecordingState.paused;
      _statusMessage = 'रोकिएको\n(Paused)';
      notifyListeners();
    } catch (e) { _setError('Failed to pause: $e'); }
  }

  Future<void> resumeRecording() async {
    try {
      if (_state != RecordingState.paused) return;
      await _recorder.resume();
      _state         = RecordingState.recording;
      _statusMessage = 'सुन्दै छु...\n(Listening...)';
      notifyListeners();
    } catch (e) { _setError('Failed to resume: $e'); }
  }

  Future<void> cancelRecording() async {
    try {
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      await _recorder.stop();
      if (_currentFilePath != null) {
        final f = File(_currentFilePath!);
        if (await f.exists()) await f.delete();
      }
      _state             = RecordingState.idle;
      _statusMessage     = 'रद्द गरियो\n(Cancelled)';
      _currentFilePath   = null;
      _recordingDuration = Duration.zero;
      notifyListeners();
    } catch (e) { _setError('Failed to cancel: $e'); }
  }

  // ─── File helpers ─────────────────────────────────────────────────────────

  Future<List<FileSystemEntity>> getRecordings() async {
    try {
      final dir = await _recordingsDir;
      if (!await dir.exists()) return [];
      return dir.listSync()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) { return []; }
  }

  Future<bool> deleteRecording(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) { await f.delete(); notifyListeners(); return true; }
      return false;
    } catch (e) { return false; }
  }

  Future<int> getFileSize(String path) async {
    try { return await File(path).length(); } catch (e) { return 0; }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  void _setError(String message) {
    _state         = RecordingState.error;
    _errorMessage  = message;
    _statusMessage = 'त्रुटि\n(Error)';
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == RecordingState.error) {
      _state         = RecordingState.idle;
      _statusMessage = 'नमस्ते!\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
      notifyListeners();
    }
  }

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

  void _startAmplitudeMonitoring(double threshold, int silenceDuration) {
    _silenceCounter = 0;
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 500))
        .listen((amp) {
      if (_state == RecordingState.recording) {
        if (amp.current < threshold) {
          _silenceCounter++;
          if (_silenceCounter >= silenceDuration * 2) {
            stopRecording(fastApiUrl: _currentApiUrl);
          }
        } else {
          _silenceCounter = 0;
        }
      }
    });
  }

  Future<Directory> get _recordingsDir async {
    Directory base;
    if (Platform.isAndroid || Platform.isIOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = Directory.current;
    }
    final dir = Directory(p.join(base.path, 'VoiceApp', 'Requests'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─── Upload & Smart Response Handling ────────────────────────────────────

  Future<void> _uploadAndPlay(String audioFilePath, String? url) async {
    if (url == null || url.isEmpty) {
      _statusMessage = 'नमस्ते!\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
      notifyListeners();
      return;
    }

    try {
      debugPrint('Uploading to: $url');
      _statusMessage = 'सर्भरमा पठाउँदै...\n(Sending to server...)';
      notifyListeners();

      final file = File(audioFilePath);
      if (!await file.exists()) { _setError('Recording not found'); return; }

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(
        'audio', audioFilePath, filename: p.basename(audioFilePath),
      ));

      _statusMessage = 'प्रशोधन गर्दै...\n(Processing on server...)';
      notifyListeners();

      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Server timeout after 60s'),
      );

      if (streamed.statusCode != 200) {
        final body = await streamed.stream.bytesToString();
        _setError('Server error ${streamed.statusCode}: $body');
        return;
      }

      final responseBytes = await streamed.stream.toBytes();
      if (responseBytes.isEmpty) { _setError('Empty server response'); return; }

      final contentType = streamed.headers['content-type'] ?? '';
      debugPrint('Response content-type: $contentType  bytes: ${responseBytes.length}');

      // ── Try parsing as JSON first ──────────────────────────────────────
      if (contentType.contains('json') || _looksLikeJson(responseBytes)) {
        final parsed = ServerResponse.tryParseBytes(responseBytes);
        if (parsed != null) {
          await _handleServerResponse(parsed);
          return;
        }
      }

      // ── Fallback: treat as raw audio ───────────────────────────────────
      await _playAudioBytes(responseBytes, contentType);
    } on TimeoutException catch (e) {
      _setError('Timeout: ${e.message}');
    } catch (e) {
      debugPrint('Upload/play error: $e');
      _setError('Failed to get response: $e');
    }
  }

  /// Main dispatcher for structured server responses
  Future<void> _handleServerResponse(ServerResponse response) async {
    // Always show the text the server sent
    _lastResponseText = response.text.isNotEmpty ? response.text : null;
    _statusMessage    = response.text.isNotEmpty
        ? response.text
        : 'जवाफ आयो\n(Response received)';
    notifyListeners();

    switch (response.action) {
      // ── Play Audio ────────────────────────────────────────────────────
      case ServerAction.playAudio:
        if (response.audioBase64 != null) {
          final bytes = base64Decode(response.audioBase64!);
          await _playAudioBytes(bytes, 'audio/mpeg');
        }

      // ── Set Reminder ──────────────────────────────────────────────────
      case ServerAction.setReminder:
        final rd = response.reminderData;
        if (rd != null && onSetReminder != null) {
          final reminder = Reminder(
            id:     DateTime.now().millisecondsSinceEpoch % 100000,
            title:  rd.title,
            body:   rd.body,
            hour:   rd.hour,
            minute: rd.minute,
            type:   ReminderTypeExt.fromKey(rd.type),
            repeat: RepeatTypeExt.fromKey(rd.repeat),
          );
          await onSetReminder!(reminder);
          debugPrint('Reminder set via server: ${reminder.title} at ${reminder.formattedTime}');
        }
        // Also play audio confirmation if supplied
        if (response.audioBase64 != null) {
          final bytes = base64Decode(response.audioBase64!);
          await _playAudioBytes(bytes, 'audio/mpeg');
        }

      // ── Make Call ─────────────────────────────────────────────────────
      case ServerAction.makeCall:
        if (response.phone != null && onMakeCall != null) {
          await onMakeCall!(response.phone!);
          debugPrint('Call triggered via server: ${response.phone}');
        }
        if (response.audioBase64 != null) {
          final bytes = base64Decode(response.audioBase64!);
          await _playAudioBytes(bytes, 'audio/mpeg');
        }

      // ── Show Message (text only) ──────────────────────────────────────
      case ServerAction.showMessage:
        if (response.audioBase64 != null) {
          final bytes = base64Decode(response.audioBase64!);
          await _playAudioBytes(bytes, 'audio/mpeg');
        }
    }

    _statusMessage = 'नमस्ते!\nबोल्नको लागि छुनुहोस्\n(Tap to speak)';
    notifyListeners();
  }

  Future<void> _playAudioBytes(List<int> bytes, String contentType) async {
    try {
      final tempDir  = await getTemporaryDirectory();
      final ext      = _extensionFromContentType(contentType);
      final tempFile = File(p.join(tempDir.path, 'response_audio$ext'));
      await tempFile.writeAsBytes(bytes);

      _statusMessage = 'जवाफ बज्दै छ...\n(Playing response...)';
      notifyListeners();

      await _player.stop();
      await _player.setAudioSource(AudioSource.file(tempFile.path));
      await _player.setVolume(1.0);
      await _player.play();

      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed)
          .timeout(const Duration(minutes: 5), onTimeout: () => ProcessingState.idle);

      debugPrint('Playback complete');
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  bool _looksLikeJson(List<int> bytes) {
    if (bytes.isEmpty) return false;
    final first = bytes.first;
    return first == 0x7B; // '{'
  }

  String _extensionFromContentType(String contentType) {
    if (contentType.contains('mpeg') || contentType.contains('mp3')) return '.mp3';
    if (contentType.contains('wav'))  return '.wav';
    if (contentType.contains('ogg'))  return '.ogg';
    if (contentType.contains('aac'))  return '.aac';
    if (contentType.contains('mp4') || contentType.contains('m4a')) return '.m4a';
    return '.audio';
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
