import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import '../models/contact_model.dart';

class ContactService extends ChangeNotifier {
  static const _storageKey = 'contacts_v1';

  List<Contact> _contacts = [];
  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<Contact> get emergencyContacts =>
      _contacts.where((c) => c.isEmergency).toList();

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadFromPrefs();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addContact(Contact contact) async {
    _contacts = [..._contacts, contact];
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> updateContact(Contact updated) async {
    _contacts = [
      for (final c in _contacts) c.id == updated.id ? updated : c
    ];
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    _contacts = _contacts.where((c) => c.id != id).toList();
    await _saveToPrefs();
    notifyListeners();
  }

  // ─── Calling ──────────────────────────────────────────────────────────────

  Future<bool> callContact(Contact contact) async {
    return callNumber(contact.phone);
  }

  Future<bool> callNumber(String phone) async {
    try {
      final res = await FlutterPhoneDirectCaller.callNumber(phone.trim());
      return res ?? false;
    } catch (e) {
      debugPrint('Direct call error: $e');
    }
    return false;
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _contacts.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_storageKey, json);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    _contacts = jsonList.map((s) {
      try {
        return Contact.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Contact>().toList();
    debugPrint('Loaded ${_contacts.length} contacts from prefs');
    notifyListeners();
  }

  /// Unique ID generator
  String newId() => DateTime.now().millisecondsSinceEpoch.toString();
}
