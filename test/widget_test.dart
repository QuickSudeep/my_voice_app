import 'package:flutter_test/flutter_test.dart';
import 'package:my_voice_assistant_app/main.dart';
import 'package:my_voice_assistant_app/services/settings_service.dart';
import 'package:my_voice_assistant_app/services/reminder_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final settingsService = SettingsService();
    final reminderService = ReminderService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(NepaliVoiceAssistantApp(
      settingsService: settingsService,
      reminderService: reminderService,
    ));

    // Verify that the title is present
    expect(find.text('साथी'), findsOneWidget);
  });
}
