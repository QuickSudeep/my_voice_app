import 'package:flutter/foundation.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
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
    try {
      await FlutterPhoneDirectCaller.callNumber(phone.trim());
    } catch (e) {
      debugPrint('SOS direct call error: $e');
    }
  }

  void stopSiren() {
    _isSirenPlaying = false;
    notifyListeners();
  }
}
