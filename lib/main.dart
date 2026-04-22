import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/recordings_screen.dart';
import 'screens/reminders_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/music_screen.dart';
import 'services/voice_service.dart';
import 'services/settings_service.dart';
import 'services/emergency_service.dart';
import 'services/reminder_service.dart';
import 'services/contact_service.dart';
import 'services/tts_service.dart';
import 'services/music_service.dart';
import 'models/reminder_model.dart';
import 'package:just_audio_background/just_audio_background.dart';

final GlobalKey<NavigatorState> mainNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.saathi.music.channel',
      androidNotificationChannelName: 'साथी Music',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground.init failed (non-fatal): $e');
  }

  // Initialize services
  final settingsService = SettingsService();
  await settingsService.init();

  final ttsService = TtsService();
  await ttsService.init();

  final reminderService = ReminderService();
  try {
    await reminderService.init();
  } catch (e) {
    debugPrint('ReminderService.init failed (non-fatal): $e');
  }

  final contactService = ContactService();
  await contactService.init();

  final musicService = MusicService();
  try {
    await musicService.init();
  } catch (e) {
    debugPrint('MusicService.init failed (non-fatal): $e');
  }

  runApp(NepaliVoiceAssistantApp(
    settingsService: settingsService,
    ttsService:      ttsService,
    reminderService: reminderService,
    contactService:  contactService,
    musicService:    musicService,
  ));
}

class NepaliVoiceAssistantApp extends StatelessWidget {
  final SettingsService settingsService;
  final TtsService      ttsService;
  final ReminderService reminderService;
  final ContactService  contactService;
  final MusicService    musicService;

  const NepaliVoiceAssistantApp({
    Key? key,
    required this.settingsService,
    required this.ttsService,
    required this.reminderService,
    required this.contactService,
    required this.musicService,
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
        ChangeNotifierProvider.value(value: musicService),
        Provider.value(value: settingsService),
        Provider.value(value: ttsService),
      ],
      child: _AppCallbackWirer(
        child: MaterialApp(
          navigatorKey: mainNavigatorKey,
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
            '/music':      (context) => const MusicScreen(),
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
    final voice     = context.read<VoiceService>();
    final reminders = context.read<ReminderService>();
    final contacts  = context.read<ContactService>();
    final music     = context.read<MusicService>();
    final tts       = context.read<TtsService>();

    int? activeReminderId;
    void Function()? cancelActiveAlarmLoop;

    voice.onSetReminder = (reminder) => reminders.addReminder(reminder);
    voice.onMakeCall    = (phone, contactName) async {
      if (phone != null && phone.trim().isNotEmpty) {
        await contacts.callNumber(phone);
        return;
      }
      if (contactName != null && contactName.trim().isNotEmpty) {
        final query = contactName.toLowerCase().trim();
        for (final c in contacts.contacts) {
          if (c.name.toLowerCase().contains(query)) {
            debugPrint('Local match found: ${c.name} -> ${c.phone}');
            await contacts.callContact(c);
            return;
          }
        }
        debugPrint('No local contact matched: $contactName');
      }
    };
    voice.onPlayMusic = (songName) async {
       if (songName != null && songName.trim().isNotEmpty) {
           final found = await music.playSongByName(songName);
           // If they asked for a song but it wasn't a real match against the filenames,
           // just play the first song as a generic fallback.
           if (!found && music.songs.isNotEmpty) {
               await music.playSong(0);
           }
       } else if (music.songs.isNotEmpty) {
           await music.playSong(0); // default to first if no name
       }
    };

    reminders.onStopAlarmTapped = (reminder) {
      if (activeReminderId == reminder.id && cancelActiveAlarmLoop != null) {
        cancelActiveAlarmLoop!();
      }
    };

    // When a reminder becomes due, handle based on mode
    reminders.onReminderDue = (reminder) async {
      if (activeReminderId == reminder.id) return;
      activeReminderId = reminder.id;

      // Auto-stop music when a reminder fires
      if (music.isPlaying) {
        await music.stop();
      }

      final settings = context.read<SettingsService>();
      
      // Show persistent heads-up notification visible on lock screen / outside app.
      // This MUST be called for both modes (voice confirmation & normal)
      reminders.showActiveAlarmNotification(reminder);

      bool isCancelled = false;
      final startTime = DateTime.now();

      cancelActiveAlarmLoop = () {
        isCancelled = true;
        activeReminderId = null;
        tts.stop();
        reminders.dismissActiveAlarmNotification();
        if (mainNavigatorKey.currentContext != null && Navigator.canPop(mainNavigatorKey.currentContext!)) {
           Navigator.pop(mainNavigatorKey.currentContext!);
        }
      };

      if (settings.reminderMode == 'voiceConfirmation') {
        final url = settings.fastApiUrl;
        if (mainNavigatorKey.currentContext != null) {
          showDialog(
            context: mainNavigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (ctx) {
              return PopScope(
                canPop: false,
                child: _VoiceConfirmationDialog(
                  reminder: reminder,
                  fastApiUrl: url,
                  tts: tts,
                  onDismiss: () {
                    if (cancelActiveAlarmLoop != null) cancelActiveAlarmLoop!();
                  },
                  onMicTapped: () {
                    isCancelled = true;
                    tts.stop();
                  },
                ),
              );
            },
          );
        }

        final text = reminder.body.isNotEmpty ? reminder.body : reminder.title;
        void playVoiceLoop() async {
          while (!isCancelled) {
            if (DateTime.now().difference(startTime).inMinutes >= 5) {
               if (cancelActiveAlarmLoop != null) cancelActiveAlarmLoop!();
               break;
            }
            await tts.speak(text);
            if (isCancelled) break;
            await Future.delayed(const Duration(seconds: 2));
          }
        }
        playVoiceLoop();
        return;
      }

      // Fallback or Normal Alarm
      final text = reminder.body.isNotEmpty ? reminder.body : reminder.title;

      if (mainNavigatorKey.currentContext != null) {
        showDialog(
          context: mainNavigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (ctx) {
            return PopScope(
              canPop: false,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('⏰ रिमाइन्डर (Reminder)', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reminder.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                  if (reminder.body.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(reminder.body, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
                  ]
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: const Icon(Icons.stop_circle_rounded, color: Colors.white),
                  label: const Text('Stop Alarm', style: TextStyle(color: Colors.white, fontSize: 18)),
                  onPressed: cancelActiveAlarmLoop,
                )
              ],
            ));
          }
        );
      }

      void playLoop() async {
        while (!isCancelled) {
          if (DateTime.now().difference(startTime).inMinutes >= 2) {
             // Timeout after 2 minutes
             if (cancelActiveAlarmLoop != null) {
                cancelActiveAlarmLoop!();
             }
             break;
          }
          await tts.speak(text);
          if (isCancelled) break;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      playLoop();
    };
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Voice Confirmation Dialog ────────────────────────────────────────────────

class _VoiceConfirmationDialog extends StatefulWidget {
  final Reminder reminder;
  final String fastApiUrl;
  final TtsService tts;
  final VoidCallback onDismiss;
  final VoidCallback onMicTapped;

  const _VoiceConfirmationDialog({
    required this.reminder,
    required this.fastApiUrl,
    required this.tts,
    required this.onDismiss,
    required this.onMicTapped,
  });

  @override
  State<_VoiceConfirmationDialog> createState() => _VoiceConfirmationDialogState();
}

class _VoiceConfirmationDialogState extends State<_VoiceConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  bool _recording = false;
  bool _hasConfirmed = false;   // only auto-dismiss AFTER a recording finishes
  String _statusText = 'माइकमा थिच्नुस् र बोल्नुस्\n(Tap mic to confirm)';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<VoiceService>().addListener(_onVoiceStateChange);
    });
  }

  void _onVoiceStateChange() {
    if (!mounted) return;
    final voice = context.read<VoiceService>();
    setState(() {
      _recording = voice.isConfirming;
      if (voice.isConfirming) {
        _statusText = 'सुन्दैछु...\n(Listening — tap again to stop & send)';
        _pulseCtrl.repeat(reverse: true);
      } else if (voice.state == RecordingState.processing) {
        _statusText = 'पठाउँदैछ...\n(Sending confirmation...)';
        _pulseCtrl.stop();
      } else if (voice.state == RecordingState.idle && _hasConfirmed) {
        // Upload done — dismiss
        _statusText = 'मान्यता पठाइयो ✔️\n(Confirmation sent!)';
        _pulseCtrl.stop();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  Future<void> _handleMicTap() async {
    final voice    = context.read<VoiceService>();
    final settings = context.read<SettingsService>();

    if (!voice.isConfirming) {
      widget.onMicTapped();
      _hasConfirmed = true;
      await voice.startConfirmationRecording(
        reminderId:      widget.reminder.id.toString(),
        baseUrl:         widget.fastApiUrl,
        autoStop:        settings.autoStopOnSilence,
        threshold:       settings.silenceThreshold,
        silenceDuration: settings.silenceDuration,
      );
    } else {
      // Manually stop and send
      await voice.stopConfirmationRecording();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try { context.read<VoiceService>().removeListener(_onVoiceStateChange); } catch (_) {}
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, 8))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(widget.reminder.type.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.reminder.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.reminder.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.reminder.body,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 17),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),

            // Mic / Stop button
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) {
                final scale = 1.0 + (_recording ? _pulseCtrl.value * 0.15 : 0.0);
                return Transform.scale(scale: scale, child: child);
              },
              child: GestureDetector(
                onTap: _handleMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? Colors.red : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: (_recording ? Colors.red : Colors.white).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
                    color: _recording ? Colors.white : const Color(0xFF0D47A1),
                    size: 44,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),
            Text(
              _statusText,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Skip button
            TextButton(
              onPressed: () {
                widget.onDismiss();
              },
              child: Text(
                'छोड्नुहोस् (Skip)',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

