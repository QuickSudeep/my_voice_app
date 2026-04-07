import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_service.dart';
import '../services/settings_service.dart';
import '../services/emergency_service.dart';
import '../services/reminder_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceService>().init();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerVibration({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _handleMicTap() async {
    final voiceService = context.read<VoiceService>();
    _triggerVibration(heavy: !voiceService.isRecording);

    if (!voiceService.isRecording && !voiceService.isPaused) {
      final settings = context.read<SettingsService>();
      await voiceService.startRecording(
        autoStop: settings.autoStopOnSilence,
        threshold: settings.silenceThreshold,
        silenceDuration: settings.silenceDuration,
        fastApiUrl: settings.fastApiUrl,
      );
    } else {
      final settings = context.read<SettingsService>();
      await voiceService.stopRecording(fastApiUrl: settings.fastApiUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('साथी', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 32),
            onPressed: () => Navigator.pushNamed(context, '/recordings'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 32),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFF5F7FA), Color(0xFFE1F5FE)],
              ),
            ),
          ),

          SafeArea(
            child: Consumer<VoiceService>(
              builder: (context, voiceService, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Cap mic button at 45% of available height to prevent overflow
                    final maxBtnSize = constraints.maxHeight * 0.45;
                    final baseBtnSize = maxBtnSize.clamp(160.0, 240.0);
                    // Pulse shrinks on small screens
                    final maxPulse = (constraints.maxHeight * 0.04).clamp(0.0, 30.0);
                    // Action card height scales too
                    final cardHeight = (constraints.maxHeight * 0.18).clamp(110.0, 150.0);

                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Status Card
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                              child: _GlassCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      voiceService.statusMessage,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        fontSize: 20,
                                      ),
                                    ),
                                    if (voiceService.recordingDuration.inSeconds > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          _formatDuration(voiceService.recordingDuration),
                                          style: GoogleFonts.outfit(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Main Mic Button
                            GestureDetector(
                              onTap: _handleMicTap,
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, _) {
                                  final pulse = voiceService.isRecording
                                      ? _controller.value * maxPulse
                                      : 0.0;
                                  final btnSize = baseBtnSize + pulse;
                                  return Container(
                                    width: btnSize,
                                    height: btnSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: voiceService.isRecording
                                            ? [Colors.redAccent, Colors.red[900]!]
                                            : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (voiceService.isRecording
                                                  ? Colors.red
                                                  : Colors.blue)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 24 + pulse,
                                          spreadRadius: 6 + pulse / 3,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      voiceService.isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      size: baseBtnSize * 0.45,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Quick Action Grid
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _ActionCard(
                                      label: 'औषधी',
                                      icon: Icons.medication_rounded,
                                      color: Colors.teal,
                                      height: cardHeight,
                                      onTap: () {
                                        _triggerVibration();
                                        _showMedicineReminderDialog(context);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _ActionCard(
                                      label: 'मद्दत (SOS)',
                                      icon: Icons.sos_rounded,
                                      color: Colors.red[700]!,
                                      height: cardHeight,
                                      onTap: () {
                                        _triggerVibration(heavy: true);
                                        _showSOSConfirmDialog(context);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSOSConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('मद्दत चाहिन्छ? (Need Help?)'),
        content: const Text('तपाईं आपतकालीन कल गर्न चाहनुहुन्छ?\n(Do you want to make an emergency call?)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('होइन (No)', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              context.read<EmergencyService>().triggerSOS();
            },
            child: const Text('हुन्छ (Yes)', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
  }

  void _showMedicineReminderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('औषधीको समय मिलाउनुहोस्\n(Set Medicine Time)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('अहिलेको लागि, ८ बजेको रिमाइन्डर सेट गरौं।\n(For now, let\'s set an 8 PM reminder.)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द गर्नुहोस् (Cancel)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ReminderService>().scheduleMedicineReminder(
                id: 1,
                title: 'औषधी खाने समय',
                body: 'तपाईंको औषधी खाने समय भयो।',
                time: const TimeOfDay(hour: 20, minute: 0),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('रिमाइन्डर सेट भयो (Reminder Set)')),
              );
            },
            child: const Text('सेट गर्नुहोस् (Set)'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double height;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
