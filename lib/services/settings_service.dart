import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyAutoSave             = 'auto_save';
  static const String _keyShowDuration         = 'show_duration';
  static const String _keyMaxRecordingDuration = 'max_recording_duration';
  static const String _keyAudioQuality         = 'audio_quality';
  static const String _keyAutoStopOnSilence    = 'auto_stop_on_silence';
  static const String _keySilenceThreshold     = 'silence_threshold';
  static const String _keySilenceDuration      = 'silence_duration';
  static const String _keyFastApiUrl           = 'fast_api_url';
  static const String _keyAdminPin             = 'admin_pin';
  static const String _keyElderlyName          = 'elderly_name';
  static const String _keyEmergencyNumber      = 'emergency_number';
  static const String _keyReminderMode         = 'reminder_mode';

  SharedPreferences? _prefs;

  bool   _autoSave             = true;
  bool   _showDuration         = true;
  int    _maxRecordingDuration = 300;
  String _audioQuality         = 'medium';
  bool   _autoStopOnSilence    = false;
  double _silenceThreshold     = -45.0;
  int    _silenceDuration      = 2;
  String _fastApiUrl           = 'http://192.168.1.100:8000/process-audio/';
  String _adminPin             = '1234';
  String _elderlyName          = 'बाजे / बज्यै';
  String _emergencyNumber      = '100';
  String _reminderMode         = 'alarm'; // 'alarm' or 'voiceConfirmation'

  bool   get autoSave             => _autoSave;
  bool   get showDuration         => _showDuration;
  int    get maxRecordingDuration => _maxRecordingDuration;
  String get audioQuality         => _audioQuality;
  bool   get autoStopOnSilence    => _autoStopOnSilence;
  double get silenceThreshold     => _silenceThreshold;
  int    get silenceDuration      => _silenceDuration;
  String get fastApiUrl           => _fastApiUrl;
  String get adminPin             => _adminPin;
  String get elderlyName          => _elderlyName;
  String get emergencyNumber      => _emergencyNumber;
  String get reminderMode         => _reminderMode;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    _autoSave             = _prefs?.getBool(_keyAutoSave)              ?? true;
    _showDuration         = _prefs?.getBool(_keyShowDuration)          ?? true;
    _maxRecordingDuration = _prefs?.getInt(_keyMaxRecordingDuration)   ?? 300;
    _audioQuality         = _prefs?.getString(_keyAudioQuality)        ?? 'medium';
    _autoStopOnSilence    = _prefs?.getBool(_keyAutoStopOnSilence)     ?? false;
    _silenceThreshold     = _prefs?.getDouble(_keySilenceThreshold)    ?? -45.0;
    _silenceDuration      = _prefs?.getInt(_keySilenceDuration)        ?? 2;
    _fastApiUrl           = _prefs?.getString(_keyFastApiUrl)          ?? 'http://192.168.1.100:8000/process-audio/';
    _adminPin             = _prefs?.getString(_keyAdminPin)            ?? '1234';
    _elderlyName          = _prefs?.getString(_keyElderlyName)         ?? 'बाजे / बज्यै';
    _emergencyNumber      = _prefs?.getString(_keyEmergencyNumber)     ?? '100';
    _reminderMode         = _prefs?.getString(_keyReminderMode)        ?? 'alarm';
  }

  Future<void> setAutoSave(bool v)              async { _autoSave = v;             await _prefs?.setBool(_keyAutoSave, v); }
  Future<void> setShowDuration(bool v)          async { _showDuration = v;         await _prefs?.setBool(_keyShowDuration, v); }
  Future<void> setMaxRecordingDuration(int s)   async { _maxRecordingDuration = s; await _prefs?.setInt(_keyMaxRecordingDuration, s); }
  Future<void> setAudioQuality(String q)        async { _audioQuality = q;         await _prefs?.setString(_keyAudioQuality, q); }
  Future<void> setAutoStopOnSilence(bool v)     async { _autoStopOnSilence = v;    await _prefs?.setBool(_keyAutoStopOnSilence, v); }
  Future<void> setSilenceThreshold(double v)    async { _silenceThreshold = v;     await _prefs?.setDouble(_keySilenceThreshold, v); }
  Future<void> setSilenceDuration(int s)        async { _silenceDuration = s;      await _prefs?.setInt(_keySilenceDuration, s); }
  Future<void> setFastApiUrl(String url)        async { _fastApiUrl = url;         await _prefs?.setString(_keyFastApiUrl, url); }
  Future<void> setAdminPin(String pin)          async { _adminPin = pin;           await _prefs?.setString(_keyAdminPin, pin); }
  Future<void> setElderlyName(String name)      async { _elderlyName = name;       await _prefs?.setString(_keyElderlyName, name); }
  Future<void> setEmergencyNumber(String num)   async { _emergencyNumber = num;    await _prefs?.setString(_keyEmergencyNumber, num); }
  Future<void> setReminderMode(String mode)     async { _reminderMode = mode;      await _prefs?.setString(_keyReminderMode, mode); }

  Future<void> resetToDefaults() async {
    await setAutoSave(true);
    await setShowDuration(true);
    await setMaxRecordingDuration(300);
    await setAudioQuality('medium');
    await setAutoStopOnSilence(false);
    await setSilenceThreshold(-45.0);
    await setSilenceDuration(2);
    await setFastApiUrl('http://192.168.1.100:8000/process-audio/');
    await setAdminPin('1234');
    await setElderlyName('बाजे / बज्यै');
    await setEmergencyNumber('100');
    await setReminderMode('alarm');
  }
}
