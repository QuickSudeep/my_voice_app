import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/reminder_model.dart';

/// Called when a reminder becomes due (fires in-app timer).
typedef OnReminderDue = void Function(Reminder reminder);

class ReminderService extends ChangeNotifier with WidgetsBindingObserver {
  static const _storageKey = 'reminders_v2';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  List<Reminder> _reminders = [];
  List<Reminder> get reminders => List.unmodifiable(_reminders);

  /// Wired by main.dart — called whenever a reminder becomes due in-app.
  OnReminderDue? onReminderDue;
  
  /// Wired by main.dart — called when the user taps "Stop Alarm" on the notification.
  OnReminderDue? onStopAlarmTapped;

  // Notification ID for the live (active) alarm notification.
  static const int _activeAlarmNotifId = 999;

  Timer? _checkTimer;

  /// Tracks the last "HH:mm" string at which each reminder ID was announced,
  /// so we don't fire the same reminder twice within the same minute.
  final Map<int, String> _lastFiredKey = {};

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    await _loadFromPrefs();
    _startReminderChecker();
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDueReminders();
    }
  }

  // ─── In-App Reminder Checker ──────────────────────────────────────────────

  /// Starts a [Timer] that fires every 5 seconds and checks whether any
  /// active reminder is due at the current clock minute.
  void _startReminderChecker() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkDueReminders();
    });
    // Also check immediately so a reminder set for "right now" isn't missed.
    _checkDueReminders();
  }

  void _checkDueReminders() {
    final now = DateTime.now();

    for (final r in _reminders) {
      if (!r.isActive) continue;

      final dueTimeToday = DateTime(now.year, now.month, now.day, r.hour, r.minute);
      final diffSeconds = now.difference(dueTimeToday).inSeconds;

      // Allow a 2-minute grace period if app was delayed in doze mode
      // This strict seconds calculation prevents the -59 early seconds truncation bug.
      if (diffSeconds >= 0 && diffSeconds <= 120) {
        final dayKey = '${now.day}_${r.hour}:${r.minute}';
        if (_lastFiredKey[r.id] == dayKey) continue; // already announced today
        
        _lastFiredKey[r.id] = dayKey;
        debugPrint('ReminderService: due → #${r.id} "${r.title}" (diff: $diffSeconds secs)');
        onReminderDue?.call(r);
      }
    }
  }

  /// Called when the user taps a delivered local notification.
  void _onNotificationTapped(NotificationResponse response) {
    final id = response.id;
    if (id == null) return;
    try {
      final reminder = _reminders.firstWhere((r) => r.id == id);
      debugPrint('ReminderService: notification tapped → #${reminder.id}');
      onReminderDue?.call(reminder);

      if (response.actionId == 'stop_alarm_action') {
        onStopAlarmTapped?.call(reminder);
      }
    } catch (_) {
      // Reminder may have been deleted — ignore.
    }
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

  // ─── Active Alarm Notification (shown immediately when alarm fires) ─────────

  /// Posts a persistent heads-up notification visible on lock screen / outside
  /// the app. Includes a native "Stop Alarm" action button.
  Future<void> showActiveAlarmNotification(Reminder r) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'saathi_active_alarm',
        'Active Alarm',
        channelDescription: 'Shows while a Saathi reminder is actively ringing',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        ongoing: true,               // cannot be swiped away
        autoCancel: false,
        styleInformation: BigTextStyleInformation(
          r.body.isNotEmpty ? r.body : r.title,
          htmlFormatBigText: false,
        ),
        actions: const [
          AndroidNotificationAction(
            'stop_alarm_action',
            'Stop Alarm 🛑',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );
    await _notifications.show(
      _activeAlarmNotifId,
      '⏰ ${r.title}',
      r.body.isNotEmpty ? r.body : 'Tap to open',
      details,
    );
  }

  /// Cancels the active alarm heads-up notification.
  Future<void> dismissActiveAlarmNotification() async {
    await _notifications.cancel(_activeAlarmNotifId);
  }

  // ─── Scheduling ───────────────────────────────────────────────────────────

  Future<void> _schedule(Reminder r) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'saathi_reminders_max',
        'Saathi Reminders',
        channelDescription: 'Saathi voice assistant reminders',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        styleInformation: BigTextStyleInformation(r.body),
        actions: const [
          AndroidNotificationAction(
            'stop_alarm_action',
            'Stop Alarm 🛑',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, r.hour, r.minute,
    );
    if (scheduledTime.isBefore(now)) {
      if (now.hour == r.hour && now.minute == r.minute) {
        // If alarm was set for literally the current minute, schedule for 2 seconds from now 
        // to avoid "past time" crash in zonedSchedule natively.
        scheduledTime = now.add(const Duration(seconds: 2));
      } else {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    }

    switch (r.repeat) {
      case RepeatType.once:
        await _safeZonedSchedule(r.id, r.title, r.body, scheduledTime, details);
      case RepeatType.daily:
        await _safeZonedSchedule(
          r.id, r.title, r.body, scheduledTime, details,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      case RepeatType.weekdays:
        await _safeZonedSchedule(
          r.id, r.title, r.body, _nextWeekday(now, r.hour, r.minute), details,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      case RepeatType.weekends:
        await _safeZonedSchedule(
          r.id, r.title, r.body, _nextWeekend(now, r.hour, r.minute), details,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
    }
    debugPrint('Scheduled reminder #${r.id} at ${r.formattedTime} [${r.repeat.key}]');
  }

  Future<void> _safeZonedSchedule(
    int id, String title, String body, tz.TZDateTime dt, NotificationDetails details,
    {DateTimeComponents? matchDateTimeComponents}
  ) async {
    try {
      await _notifications.zonedSchedule(
        id, title, body, dt, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('Exact scheduling failed, trying inexact fallback: $e');
      try {
        await _notifications.zonedSchedule(
          id, title, body, dt, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (e2) {
        debugPrint('Completely failed to schedule notification: $e2');
      }
    }
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
