import 'dart:convert';

enum ServerAction { playAudio, setReminder, makeCall, showMessage, playMusic }

extension ServerActionExt on ServerAction {
  static ServerAction fromString(String? s) {
    switch (s) {
      case 'set_reminder': return ServerAction.setReminder;
      case 'make_call':    return ServerAction.makeCall;
      case 'play_audio':   return ServerAction.playAudio;
      case 'play_music':   return ServerAction.playMusic;
      default:             return ServerAction.showMessage;
    }
  }
}

class ReminderData {
  final String title;
  final String body;
  final int hour;
  final int minute;
  final String type;   // matches ReminderType.key
  final String repeat; // matches RepeatType.key

  const ReminderData({
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.type = 'custom',
    this.repeat = 'daily',
  });

  factory ReminderData.fromJson(Map<String, dynamic> json) => ReminderData(
    title: json['title'] as String? ?? 'Reminder',
    body: json['body'] as String? ?? '',
    hour: json['hour'] as int? ?? 8,
    minute: json['minute'] as int? ?? 0,
    type: json['type'] as String? ?? 'custom',
    repeat: json['repeat'] as String? ?? 'daily',
  );
}

class ServerResponse {
  final ServerAction action;
  final String text;
  final String? audioBase64; // base64-encoded audio (optional)
  final String? phone;       // for make_call action
  final String? contactName; // local name lookup for make_call
  final String? songName;    // for play_music action
  final ReminderData? reminderData; // for set_reminder action

  const ServerResponse({
    required this.action,
    required this.text,
    this.audioBase64,
    this.phone,
    this.contactName,
    this.songName,
    this.reminderData,
  });

  factory ServerResponse.fromJson(Map<String, dynamic> json) {
    final action = ServerActionExt.fromString(json['action'] as String?);
    final data = json['data'] as Map<String, dynamic>?;

    return ServerResponse(
      action: action,
      text: json['text'] as String? ?? '',
      audioBase64: json['audio'] as String?,
      phone: data?['phone'] as String?,
      contactName: data?['contact_name'] as String?,
      songName: data?['song_name'] as String?,
      reminderData: data?['reminder'] != null
          ? ReminderData.fromJson(data!['reminder'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Try to parse raw bytes as a JSON ServerResponse.
  /// Returns null if the bytes are not valid JSON.
  static ServerResponse? tryParseBytes(List<int> bytes) {
    try {
      final str = utf8.decode(bytes);
      final map = jsonDecode(str) as Map<String, dynamic>;
      return ServerResponse.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
