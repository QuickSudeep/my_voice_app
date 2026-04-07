import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/recordings_screen.dart';
import 'services/voice_service.dart';
import 'services/settings_service.dart';
import 'services/emergency_service.dart';
import 'services/reminder_service.dart';

import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final settingsService = SettingsService();
  await settingsService.init();

  final reminderService = ReminderService();
  await reminderService.init();

  runApp(NepaliVoiceAssistantApp(
    settingsService: settingsService,
    reminderService: reminderService,
  ));
}

class NepaliVoiceAssistantApp extends StatelessWidget {
  final SettingsService settingsService;
  final ReminderService reminderService;

  const NepaliVoiceAssistantApp({
    Key? key,
    required this.settingsService,
    required this.reminderService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider.value(value: reminderService),
        Provider.value(value: settingsService),
      ],
      child: MaterialApp(
        title: 'साथी (Saathi)',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5), // Premium Blue
            primary: const Color(0xFF0D47A1),
            secondary: const Color(0xFFFFA000), // High contrast Amber
            surface: const Color(0xFFF5F7FA),
          ),
          textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
            displayLarge: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
              letterSpacing: -1.0,
            ),
            headlineMedium: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            bodyLarge: TextStyle(
              fontSize: 24,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            bodyMedium: TextStyle(
              fontSize: 20,
              color: Colors.black54,
              height: 1.4,
            ),
          )),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D47A1),
            ),
            iconTheme: const IconThemeData(color: Color(0xFF0D47A1), size: 32),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 4,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            clipBehavior: Clip.antiAlias,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/admin': (context) => const AdminScreen(),
          '/recordings': (context) => const RecordingsScreen(),
        },
      ),
    );
  }
}
