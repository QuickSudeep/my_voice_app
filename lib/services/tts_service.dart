import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Cross-platform text-to-speech service.
/// Prefers Nepali (ne-NP), falls back to Hindi (hi-IN), then English (en-US).
class TtsService {
  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.45);   // slower — easier for elderly
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      await _setLanguage();

      // On Android request audio focus so reminder cuts through other audio
      if (!kIsWeb && Platform.isAndroid) {
        await _tts.setQueueMode(1); // flush queue — always speak latest
      }

      _tts.setErrorHandler((msg) {
        debugPrint('TtsService error: $msg');
      });

      _initialized = true;
      debugPrint('TtsService: initialized');
    } catch (e) {
      debugPrint('TtsService init error: $e');
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Speak [text] aloud, interrupting any currently playing speech.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (!_initialized) await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TtsService speak error: $e');
    }
  }

  /// Stop any in-progress speech immediately.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TtsService stop error: $e');
    }
  }

  // ─── Language selection ────────────────────────────────────────────────────

  Future<void> _setLanguage() async {
    try {
      final raw = await _tts.getLanguages;
      final available = (raw as List?)
          ?.map((l) => l.toString().toLowerCase())
          .toList() ?? [];

      if (available.any((l) => l.startsWith('ne'))) {
        await _tts.setLanguage('ne-NP');
        debugPrint('TtsService: language set to ne-NP');
      } else if (available.any((l) => l.startsWith('hi'))) {
        await _tts.setLanguage('hi-IN');
        debugPrint('TtsService: language set to hi-IN (Nepali unavailable)');
      } else {
        await _tts.setLanguage('en-US');
        debugPrint('TtsService: language set to en-US (fallback)');
      }
    } catch (e) {
      // If language listing fails just leave the engine default
      debugPrint('TtsService: language detection failed ($e), using engine default');
    }
  }
}
