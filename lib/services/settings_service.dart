import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyAutoSave = 'auto_save';
  static const String _keyShowDuration = 'show_duration';
  static const String _keyMaxRecordingDuration = 'max_recording_duration';
  static const String _keyAudioQuality = 'audio_quality';
  static const String _keyAutoStopOnSilence = 'auto_stop_on_silence';
  static const String _keySilenceThreshold = 'silence_threshold';
  static const String _keySilenceDuration = 'silence_duration';
  static const String _keyFastApiUrl = 'fast_api_url';

  SharedPreferences? _prefs;

  // Settings
  bool _autoSave = true;
  bool _showDuration = true;
  int _maxRecordingDuration = 300; // 5 minutes in seconds
  String _audioQuality = 'medium'; // low, medium, high
  bool _autoStopOnSilence = false;
  double _silenceThreshold = -45.0; // In dB (0 is loudest, -60 is very quiet)
  int _silenceDuration = 2; // Seconds of silence before auto-stop
  String _fastApiUrl = 'http://localhost:8000/process-audio/';

  bool get autoSave => _autoSave;
  bool get showDuration => _showDuration;
  int get maxRecordingDuration => _maxRecordingDuration;
  String get audioQuality => _audioQuality;
  bool get autoStopOnSilence => _autoStopOnSilence;
  double get silenceThreshold => _silenceThreshold;
  int get silenceDuration => _silenceDuration;
  String get fastApiUrl => _fastApiUrl;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    _autoSave = _prefs?.getBool(_keyAutoSave) ?? true;
    _showDuration = _prefs?.getBool(_keyShowDuration) ?? true;
    _maxRecordingDuration = _prefs?.getInt(_keyMaxRecordingDuration) ?? 300;
    _audioQuality = _prefs?.getString(_keyAudioQuality) ?? 'medium';
    _autoStopOnSilence = _prefs?.getBool(_keyAutoStopOnSilence) ?? false;
    _silenceThreshold = _prefs?.getDouble(_keySilenceThreshold) ?? -45.0;
    _silenceDuration = _prefs?.getInt(_keySilenceDuration) ?? 2;
    _fastApiUrl = _prefs?.getString(_keyFastApiUrl) ?? 'http://localhost:8000/process-audio/';
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    await _prefs?.setBool(_keyAutoSave, value);
  }

  Future<void> setShowDuration(bool value) async {
    _showDuration = value;
    await _prefs?.setBool(_keyShowDuration, value);
  }

  Future<void> setMaxRecordingDuration(int seconds) async {
    _maxRecordingDuration = seconds;
    await _prefs?.setInt(_keyMaxRecordingDuration, seconds);
  }

  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    await _prefs?.setString(_keyAudioQuality, quality);
  }

  Future<void> setAutoStopOnSilence(bool value) async {
    _autoStopOnSilence = value;
    await _prefs?.setBool(_keyAutoStopOnSilence, value);
  }

  Future<void> setSilenceThreshold(double value) async {
    _silenceThreshold = value;
    await _prefs?.setDouble(_keySilenceThreshold, value);
  }

  Future<void> setSilenceDuration(int seconds) async {
    _silenceDuration = seconds;
    await _prefs?.setInt(_keySilenceDuration, seconds);
  }

  Future<void> setFastApiUrl(String url) async {
    _fastApiUrl = url;
    await _prefs?.setString(_keyFastApiUrl, url);
  }

  Future<void> resetToDefaults() async {
    await setAutoSave(true);
    await setShowDuration(true);
    await setMaxRecordingDuration(300);
    await setAudioQuality('medium');
    await setAutoStopOnSilence(false);
    await setSilenceThreshold(-45.0);
    await setSilenceDuration(2);
    await setFastApiUrl('http://localhost:8000/process-audio/');
  }
}
