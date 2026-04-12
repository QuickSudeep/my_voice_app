import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact_service.dart';
import 'settings_service.dart';

class EmergencyService extends ChangeNotifier {
  bool _isSirenPlaying = false;
  bool get isSirenPlaying => _isSirenPlaying;

  /// Trigger full SOS: call the first emergency contact or the fallback number.
  Future<void> triggerSOS({
    ContactService? contactService,
    SettingsService? settingsService,
  }) async {
    _isSirenPlaying = true;
    notifyListeners();

    // Prefer the first emergency contact, fall back to settings number
    String? phone;
    if (contactService != null && contactService.emergencyContacts.isNotEmpty) {
      phone = contactService.emergencyContacts.first.phone;
    }
    phone ??= settingsService?.emergencyNumber ?? '100';

    debugPrint('SOS triggered — calling $phone');
    await _callNumber(phone);
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:${phone.trim()}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('Cannot launch dialer for $phone');
      }
    } catch (e) {
      debugPrint('SOS call error: $e');
    }
  }

  void stopSiren() {
    _isSirenPlaying = false;
    notifyListeners();
  }
}
