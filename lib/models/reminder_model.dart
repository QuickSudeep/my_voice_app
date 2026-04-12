import 'package:flutter/material.dart';

enum ReminderType { medicine, prayer, meal, exercise, water, custom }
enum RepeatType { once, daily, weekdays, weekends }

extension ReminderTypeExt on ReminderType {
  String get label {
    switch (this) {
      case ReminderType.medicine: return 'औषधी (Medicine)';
      case ReminderType.prayer:   return 'पूजा (Prayer)';
      case ReminderType.meal:     return 'खाना (Meal)';
      case ReminderType.exercise: return 'व्यायाम (Exercise)';
      case ReminderType.water:    return 'पानी (Water)';
      case ReminderType.custom:   return 'अन्य (Custom)';
    }
  }

  String get emoji {
    switch (this) {
      case ReminderType.medicine: return '💊';
      case ReminderType.prayer:   return '🙏';
      case ReminderType.meal:     return '🍚';
      case ReminderType.exercise: return '🏃';
      case ReminderType.water:    return '💧';
      case ReminderType.custom:   return '⏰';
    }
  }

  String get key => name;
  static ReminderType fromKey(String key) =>
      ReminderType.values.firstWhere((e) => e.name == key, orElse: () => ReminderType.custom);
}

extension RepeatTypeExt on RepeatType {
  String get label {
    switch (this) {
      case RepeatType.once:     return 'एकपटक (Once)';
      case RepeatType.daily:    return 'दैनिक (Daily)';
      case RepeatType.weekdays: return 'सोमबार–शुक्रबार (Weekdays)';
      case RepeatType.weekends: return 'शनि–आइतबार (Weekends)';
    }
  }

  String get key => name;
  static RepeatType fromKey(String key) =>
      RepeatType.values.firstWhere((e) => e.name == key, orElse: () => RepeatType.daily);
}

class Reminder {
  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;
  final ReminderType type;
  final RepeatType repeat;
  final bool isActive;

  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    required this.type,
    required this.repeat,
    this.isActive = true,
  });

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get formattedTime {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? body,
    int? hour,
    int? minute,
    ReminderType? type,
    RepeatType? repeat,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      type: type ?? this.type,
      repeat: repeat ?? this.repeat,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'hour': hour,
    'minute': minute,
    'type': type.key,
    'repeat': repeat.key,
    'isActive': isActive,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    type: ReminderTypeExt.fromKey(json['type'] as String? ?? 'custom'),
    repeat: RepeatTypeExt.fromKey(json['repeat'] as String? ?? 'daily'),
    isActive: json['isActive'] as bool? ?? true,
  );
}
