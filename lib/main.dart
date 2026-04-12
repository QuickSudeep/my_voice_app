import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/recordings_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/contacts_screen.dart';
import 'services/voice_service.dart';
import 'services/settings_service.dart';
import 'services/emergency_service.dart';
import 'services/reminder_service.dart';
import 'services/contact_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final settingsService = SettingsService();
  await settingsService.init();

  final reminderService = ReminderService();
  await reminderService.init();

  final contactService = ContactService();
  await contactService.init();

  runApp(NepaliVoiceAssistantApp(
    settingsService: settingsService,
    reminderService: reminderService,
    contactService:  contactService,
  ));
}

class NepaliVoiceAssistantApp extends StatelessWidget {
  final SettingsService settingsService;
  final ReminderService reminderService;
  final ContactService  contactService;

  const NepaliVoiceAssistantApp({
    Key? key,
    required this.settingsService,
    required this.reminderService,
    required this.contactService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) {
            final voice = VoiceService();
            // Wire cross-service callbacks AFTER providers are mounted
            // (done lazily in HomeScreen.initState via WidgetsBinding callback)
            return voice;
          },
        ),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider.value(value: reminderService),
        ChangeNotifierProvider.value(value: contactService),
        Provider.value(value: settingsService),
      ],
      child: _AppCallbackWirer(
        child: MaterialApp(
          title: 'साथी (Saathi)',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          initialRoute: '/',
          routes: {
            '/':           (context) => const HomeScreen(),
            '/admin':      (context) => const AdminScreen(),
            '/recordings': (context) => const RecordingsScreen(),
            '/reminders':  (context) => const RemindersScreen(),
            '/contacts':   (context) => const ContactsScreen(),
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1E88E5),
        primary:   const Color(0xFF0D47A1),
        secondary: const Color(0xFFFFA000),
        surface:   const Color(0xFFF5F7FA),
      ),
      textTheme: GoogleFonts.outfitTextTheme(const TextTheme(
        displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), letterSpacing: -1.0),
        headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
        bodyLarge: TextStyle(fontSize: 24, color: Colors.black87, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontSize: 20, color: Colors.black54, height: 1.4),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1)),
        iconTheme: const IconThemeData(color: Color(0xFF0D47A1), size: 28),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}

/// Wires VoiceService callbacks to ReminderService & ContactService
/// once the provider tree is available.
class _AppCallbackWirer extends StatefulWidget {
  final Widget child;
  const _AppCallbackWirer({required this.child});

  @override
  State<_AppCallbackWirer> createState() => _AppCallbackWirerState();
}

class _AppCallbackWirerState extends State<_AppCallbackWirer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireCallbacks());
  }

  void _wireCallbacks() {
    final voice    = context.read<VoiceService>();
    final reminders = context.read<ReminderService>();
    final contacts  = context.read<ContactService>();

    voice.onSetReminder = (reminder) => reminders.addReminder(reminder);
    voice.onMakeCall    = (phone)    => contacts.callNumber(phone);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
