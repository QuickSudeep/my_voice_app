import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/voice_service.dart';
import '../services/settings_service.dart';
import '../services/emergency_service.dart';
import '../services/music_service.dart';
import '../services/contact_service.dart';
import '../models/contact_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceService>().init();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _haptic({bool heavy = false}) {
    heavy ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  }

  Future<void> _handleMicTap() async {
    final voice    = context.read<VoiceService>();
    final settings = context.read<SettingsService>();
    final music    = context.read<MusicService>();
    _haptic(heavy: !voice.isRecording);

    // Auto-stop music when mic is tapped
    if (music.isPlaying) {
      await music.stop();
    }
    
    // Auto-stop any active AI speaking when mic is tapped
    await voice.stopAudio();

    if (!voice.isRecording && !voice.isPaused) {
      await voice.startRecording(
        autoStop:       settings.autoStopOnSilence,
        threshold:      settings.silenceThreshold,
        silenceDuration: settings.silenceDuration,
        fastApiUrl:     settings.fastApiUrl,
      );
    } else {
      await voice.stopRecording(fastApiUrl: settings.fastApiUrl);
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
            tooltip: 'Reminders',
            icon: const Icon(Icons.notifications_active_rounded, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/reminders'),
          ),
          IconButton(
            tooltip: 'Contacts',
            icon: const Icon(Icons.contacts_rounded, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/contacts'),
          ),
          IconButton(
            tooltip: 'Recordings',
            icon: const Icon(Icons.history_rounded, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/recordings'),
          ),
          IconButton(
            tooltip: 'Music',
            icon: const Icon(Icons.music_note_rounded, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/music'),
          ),
          IconButton(
            tooltip: 'Admin',
            icon: const Icon(Icons.admin_panel_settings_rounded, size: 30),
            onPressed: () => Navigator.pushNamed(context, '/admin'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE3F2FD), Color(0xFFF5F7FA), Color(0xFFE8EAF6)],
              ),
            ),
          ),
          SafeArea(
            child: Consumer<VoiceService>(
              builder: (context, voice, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final maxH       = constraints.maxHeight;
                    final btnSize    = (maxH * 0.28).clamp(140.0, 200.0);
                    final maxPulse   = (maxH * 0.04).clamp(0.0, 24.0);

                    return Column(
                      children: [
                        // ── Elderly Name Banner ──────────────────────────
                        _ElderlyBanner(),

                        // ── Status / Response Card ───────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: _GlassCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  voice.statusMessage,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0D47A1),
                                    height: 1.4,
                                  ),
                                ),
                                if (voice.recordingDuration.inSeconds > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _formatDuration(voice.recordingDuration),
                                      style: GoogleFonts.outfit(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                // Response text from server
                                if (voice.lastResponseText != null) ...[
                                  const Divider(height: 20),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('🤖 ', style: TextStyle(fontSize: 18)),
                                      Expanded(
                                        child: Text(
                                          voice.lastResponseText!,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // ── Mic Button ──────────────────────────────────
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: _handleMicTap,
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final pulse = voice.isRecording
                                      ? _pulseController.value * maxPulse
                                      : 0.0;
                                  final size = btnSize + pulse;
                                  return Container(
                                    width: size, height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: voice.isRecording
                                            ? [Colors.redAccent, Colors.red[900]!]
                                            : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (voice.isRecording ? Colors.red : Colors.blue)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 28 + pulse,
                                          spreadRadius: 4 + pulse / 3,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      voice.isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      size: btnSize * 0.42,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // ── Quick Dial Row ───────────────────────────────
                        _QuickDialRow(),

                        // ── Action Cards ─────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _ActionGrid(haptic: _haptic),
                        ),
                      ],
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

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}

// ─── Elderly Name Banner ──────────────────────────────────────────────────────

class _ElderlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = context.read<SettingsService>().elderlyName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF0D47A1),
            child: Icon(Icons.person_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('नमस्ते! 🙏', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
              Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Quick Dial Row ───────────────────────────────────────────────────────────

class _QuickDialRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ContactService>(
      builder: (context, cs, _) {
        final emergency = cs.emergencyContacts.take(3).toList();
        if (emergency.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/contacts'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.red.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_call, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'आपतकालीन सम्पर्क थप्नुहोस् (Add Emergency Contacts)',
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.red[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: emergency.map((c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _QuickDialButton(contact: c),
              ),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _QuickDialButton extends StatelessWidget {
  final Contact contact;
  const _QuickDialButton({required this.contact});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.heavyImpact();
        context.read<ContactService>().callContact(contact);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(contact.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(height: 4),
            Text(
              contact.name.split(' ').first,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const Icon(Icons.call_rounded, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Action Grid ──────────────────────────────────────────────────────────────

class _ActionGrid extends StatelessWidget {
  final void Function({bool heavy}) haptic;
  const _ActionGrid({required this.haptic});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _ActionCard(
              label: 'औषधी\nReminders',
              icon: Icons.medication_rounded,
              color: const Color(0xFF00897B),
              onTap: () { haptic(); Navigator.pushNamed(context, '/reminders'); },
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionCard(
              label: 'कल गर्नुहोस्\nContacts',
              icon: Icons.contacts_rounded,
              color: const Color(0xFF1E88E5),
              onTap: () { haptic(); Navigator.pushNamed(context, '/contacts'); },
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionCard(
              label: 'मद्दत\nSOS',
              icon: Icons.sos_rounded,
              color: const Color(0xFFC62828),
              onTap: () { haptic(heavy: true); _showSOSDialog(context); },
            )),
          ],
        ),
      ],
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🆘 आपतकाल! (Emergency!)', textAlign: TextAlign.center),
        content: const Text(
          'के तपाईंलाई अहिले मद्दत चाहिन्छ?\n(Do you need help right now?)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('होइन (No)', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.call_rounded),
            label: const Text('हुन्छ (YES)', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<EmergencyService>().triggerSOS(
                contactService: context.read<ContactService>(),
                settingsService: context.read<SettingsService>(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 14, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glass Card ───────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
