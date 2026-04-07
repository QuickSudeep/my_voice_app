import 'package:url_launcher/url_launcher.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class EmergencyService extends ChangeNotifier {
  final _player = AudioPlayer();
  bool _isSirenPlaying = false;
  String _emergencyNumber = '100'; // Default Nepal Police number

  bool get isSirenPlaying => _isSirenPlaying;

  Future<void> triggerSOS() async {
    // 1. Play loud siren (optional, can be stopped)
    await _playSiren();
    
    // 2. Launch phone call
    final Uri callUri = Uri.parse('tel:$_emergencyNumber');
    if (await systemCanLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  Future<void> _playSiren() async {
    try {
      // For now, we use a placeholder or a very high frequency tone if possible
      // Since we don't have an asset yet, we'll just log it.
      // In a real app, we'd bundle a 'siren.mp3'
      debugPrint("Siren triggered!");
      _isSirenPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error playing siren: $e");
    }
  }

  void stopSiren() {
    _isSirenPlaying = false;
    _player.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

// Helper to check if url can be launched (added explicitly since some versions of url_launcher need it)
extension UrlLauncherHelper on Object {
  Future<bool> systemCanLaunchUrl(Uri url) => canLaunchUrl(url);
}
