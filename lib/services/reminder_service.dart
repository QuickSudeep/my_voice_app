import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/reminder_model.dart';

class ReminderService extends ChangeNotifier {
  static const _storageKey = 'reminders_v2';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => List.unmodifiable(_reminders);

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    await _loadFromPrefs();
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addReminder(Reminder reminder) async {
    _reminders = [..._reminders, reminder];
    await _saveToPrefs();
    if (reminder.isActive) await _schedule(reminder);
    notifyListeners();
  }

  Future<void> updateReminder(Reminder updated) async {
    _reminders = [
      for (final r in _reminders) r.id == updated.id ? updated : r
    ];
    await _saveToPrefs();
    await _notifications.cancel(updated.id);
    if (updated.isActive) await _schedule(updated);
    notifyListeners();
  }

  Future<void> deleteReminder(int id) async {
    _reminders = _reminders.where((r) => r.id != id).toList();
    await _saveToPrefs();
    await _notifications.cancel(id);
    notifyListeners();
  }

  Future<void> toggleReminder(int id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final updated = _reminders[idx].copyWith(isActive: !_reminders[idx].isActive);
    await updateReminder(updated);
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    _reminders = [for (final r in _reminders) r.copyWith(isActive: false)];
    await _saveToPrefs();
    notifyListeners();
  }

  /// Generate a new unique ID (max existing + 1)
  int newId() {
    if (_reminders.isEmpty) return 1;
    return _reminders.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ─── Legacy compat (used by HomeScreen medicine quick-action) ─────────────

  Future<void> scheduleMedicineReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) {
    final reminder = Reminder(
      id: id,
      title: title,
      body: body,
      hour: time.hour,
      minute: time.minute,
      type: ReminderType.medicine,
      repeat: RepeatType.daily,
    );
    return addReminder(reminder);
  }

  Future<void> cancelReminder(int id) => deleteReminder(id);

  // ─── Scheduling ───────────────────────────────────────────────────────────

  Future<void> _schedule(Reminder r) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'saathi_reminders',
        'Saathi Reminders',
        channelDescription: 'Saathi voice assistant reminders',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        styleInformation: BigTextStyleInformation(r.body),
      ),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, r.hour, r.minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    switch (r.repeat) {
      case RepeatType.once:
        await _notifications.zonedSchedule(
          r.id, r.title, r.body, scheduledTime, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      case RepeatType.daily:
        await _notifications.zonedSchedule(
          r.id, r.title, r.body, scheduledTime, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      case RepeatType.weekdays:
        await _notifications.zonedSchedule(
          r.id, r.title, r.body, _nextWeekday(now, r.hour, r.minute), details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      case RepeatType.weekends:
        await _notifications.zonedSchedule(
          r.id, r.title, r.body, _nextWeekend(now, r.hour, r.minute), details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
    }
    debugPrint('Scheduled reminder #${r.id} at ${r.formattedTime} [${r.repeat.key}]');
  }

  tz.TZDateTime _nextWeekday(tz.TZDateTime from, int hour, int minute) {
    var dt = tz.TZDateTime(tz.local, from.year, from.month, from.day, hour, minute);
    while (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday || dt.isBefore(from)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  tz.TZDateTime _nextWeekend(tz.TZDateTime from, int hour, int minute) {
    var dt = tz.TZDateTime(tz.local, from.year, from.month, from.day, hour, minute);
    while (dt.weekday != DateTime.saturday && dt.weekday != DateTime.sunday || dt.isBefore(from)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  // ─── Persistence ──────────────────────────────────────────────────────────

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _reminders.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_storageKey, json);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    _reminders = jsonList.map((s) {
      try {
        return Reminder.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<Reminder>().toList();
    debugPrint('Loaded ${_reminders.length} reminders from prefs');
    notifyListeners();
  }
}
