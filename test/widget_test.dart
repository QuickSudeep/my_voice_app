import 'package:flutter_test/flutter_test.dart';
import 'package:my_voice_assistant_app/main.dart';
import 'package:my_voice_assistant_app/services/settings_service.dart';
import 'package:my_voice_assistant_app/services/reminder_service.dart';
import 'package:my_voice_assistant_app/services/contact_service.dart';
import 'package:my_voice_assistant_app/services/tts_service.dart';
import 'package:my_voice_assistant_app/services/music_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final settingsService = SettingsService();
    final reminderService = ReminderService();
    final contactService  = ContactService();
    final ttsService      = TtsService();
    final musicService    = MusicService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(NepaliVoiceAssistantApp(
      settingsService: settingsService,
      ttsService:      ttsService,
      reminderService: reminderService,
      contactService: contactService,
      musicService:   musicService,
    ));

    // Verify that the title is present
    expect(find.text('साथी'), findsOneWidget);
  });
}
