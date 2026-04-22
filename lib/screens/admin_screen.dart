import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/reminder_service.dart';
import '../services/contact_service.dart';
import '../services/voice_service.dart';
import '../models/reminder_model.dart';
import '../models/contact_model.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _unlocked = false;
  final _pinCtrl = TextEditingController();
  String _pinError = '';

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _tryUnlock() {
    final settings = context.read<SettingsService>();
    if (_pinCtrl.text == settings.adminPin) {
      setState(() { _unlocked = true; _pinError = ''; });
    } else {
      setState(() { _pinError = 'PIN गलत छ (Wrong PIN)'; });
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) return _PinGate(ctrl: _pinCtrl, error: _pinError, onSubmit: _tryUnlock);
    return const _AdminPanel();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIN Gate
// ═══════════════════════════════════════════════════════════════════════════════

class _PinGate extends StatelessWidget {
  final TextEditingController ctrl;
  final String error;
  final VoidCallback onSubmit;

  const _PinGate({required this.ctrl, required this.error, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 72, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text('Admin Panel', style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Caregiver Access Only', style: GoogleFonts.outfit(fontSize: 16, color: Colors.white60)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    Text('PIN प्रविष्ट गर्नुस्', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
                    const SizedBox(height: 20),
                    TextField(
                      controller: ctrl,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 12),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '• • • •',
                        hintStyle: const TextStyle(fontSize: 24, letterSpacing: 12, color: Colors.black26),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                        ),
                        errorText: error.isNotEmpty ? error : null,
                        filled: true,
                        fillColor: const Color(0xFFF0F4FF),
                      ),
                      onSubmitted: (_) => onSubmit(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: onSubmit,
                        child: Text('प्रवेश गर्नुस् (Enter)', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('← फिर्ता जानुस् (Back)', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Admin Panel (tabbed)
// ═══════════════════════════════════════════════════════════════════════════════

class _AdminPanel extends StatefulWidget {
  const _AdminPanel();

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.amber,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
            Tab(icon: Icon(Icons.alarm_rounded), text: 'Reminders'),
            Tab(icon: Icon(Icons.contacts_rounded), text: 'Contacts'),
            Tab(icon: Icon(Icons.info_rounded), text: 'About'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SettingsTab(),
          _RemindersTab(),
          _ContactsTab(),
          _AboutTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late TextEditingController _urlCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _emergencyCtrl;
  late TextEditingController _pinCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _urlCtrl       = TextEditingController(text: s.fastApiUrl);
    _nameCtrl      = TextEditingController(text: s.elderlyName);
    _emergencyCtrl = TextEditingController(text: s.emergencyNumber);
    _pinCtrl       = TextEditingController(text: s.adminPin);
  }

  @override
  void dispose() {
    _urlCtrl.dispose(); _nameCtrl.dispose();
    _emergencyCtrl.dispose(); _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsService>();
    final voice    = context.read<VoiceService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Elderly Profile ────────────────────────────────────────────────
        _SectionCard(
          title: '👤 Elderly Person',
          children: [
            _StyledTextField(ctrl: _nameCtrl, label: 'नाम (Name)', icon: Icons.person_rounded,
              onChanged: (v) => settings.setElderlyName(v)),
            const SizedBox(height: 12),
            _StyledTextField(ctrl: _emergencyCtrl, label: 'Default Emergency Number', icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              onChanged: (v) => settings.setEmergencyNumber(v)),
          ],
        ),

        // ── API Settings ───────────────────────────────────────────────────
        _SectionCard(
          title: '🌐 Server Settings',
          children: [
            _StyledTextField(ctrl: _urlCtrl, label: 'FastAPI Server URL', icon: Icons.cloud_rounded,
              onChanged: (v) => settings.setFastApiUrl(v)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wifi_tethering_rounded),
                label: const Text('Test Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _testConnection(context, settings),
              ),
            ),
          ],
        ),

        // ── Reminder Settings ──────────────────────────────────────────────
        _SectionCard(
          title: '⏰ Reminder Defaults',
          children: [
            Text('Default Reminder Mode', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings.reminderMode,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF0F4FF),
              ),
              items: const [
                DropdownMenuItem(value: 'alarm', child: Text('Regular Alarm (Looping Title)')),
                DropdownMenuItem(value: 'voiceConfirmation', child: Text('Voice Interactive (Confirm Reply)')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await settings.setReminderMode(v);
                  setState(() {});
                }
              },
            ),
          ],
        ),

        // ── Recording Settings ─────────────────────────────────────────────
        _SectionCard(
          title: '🎙️ Recording',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Auto-Stop on Silence', style: GoogleFonts.outfit(fontSize: 16)),
              subtitle: Text('Stop when you stop speaking', style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45)),
              value: settings.autoStopOnSilence,
              activeThumbColor: const Color(0xFF0D47A1),
              onChanged: (v) async { await settings.setAutoStopOnSilence(v); setState(() {}); },
            ),
            if (settings.autoStopOnSilence) ...[
              _SliderRow(
                label: 'Silence Threshold',
                value: settings.silenceThreshold,
                min: -60, max: -20, divisions: 40,
                displayText: '${settings.silenceThreshold.toInt()} dB',
                onChanged: (v) async { await settings.setSilenceThreshold(v); setState(() {}); },
              ),
              _SliderRow(
                label: 'Silence Duration',
                value: settings.silenceDuration.toDouble(),
                min: 1, max: 10, divisions: 9,
                displayText: '${settings.silenceDuration}s',
                onChanged: (v) async { await settings.setSilenceDuration(v.toInt()); setState(() {}); },
              ),
            ],
          ],
        ),

        // ── Storage ────────────────────────────────────────────────────────
        _SectionCard(
          title: '💾 Storage',
          children: [
            FutureBuilder<List<dynamic>>(
              future: voice.getRecordings(),
              builder: (ctx, snap) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_rounded, color: Color(0xFF0D47A1)),
                title: Text('Total Recordings', style: GoogleFonts.outfit(fontSize: 16)),
                trailing: Text('${snap.data?.length ?? 0}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: Color(0xFF0D47A1)),
              title: Text('View Recordings', style: GoogleFonts.outfit(fontSize: 16)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/recordings'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: Text('Clear All Recordings', style: GoogleFonts.outfit(fontSize: 16, color: Colors.red)),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () => _clearRecordings(context, voice),
            ),
          ],
        ),

        // ── Security ───────────────────────────────────────────────────────
        _SectionCard(
          title: '🔒 Security',
          children: [
            _StyledTextField(
              ctrl: _pinCtrl,
              label: 'Admin PIN',
              icon: Icons.lock_rounded,
              obscureText: true,
              keyboardType: TextInputType.number,
              onChanged: (v) { if (v.length >= 4) settings.setAdminPin(v); },
            ),
            const SizedBox(height: 4),
            Text('Minimum 4 digits', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38)),
          ],
        ),

        // Reset
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restore_rounded, color: Colors.orange),
            label: Text('Reset All Settings', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _resetSettings(context, settings),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _testConnection(BuildContext context, SettingsService settings) async {
    final url = settings.fastApiUrl;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Testing: $url ...'), duration: const Duration(seconds: 2)),
    );
    // TODO: actual ping
  }

  Future<void> _clearRecordings(BuildContext context, VoiceService voice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Recordings'),
        content: const Text('Permanently delete all recordings?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final recordings = await voice.getRecordings();
      for (final r in recordings) { await voice.deleteRecording(r.path); }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All recordings deleted')));
        setState(() {});
      }
    }
  }

  Future<void> _resetSettings(BuildContext context, SettingsService settings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Reset all settings to defaults?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed == true) {
      await settings.resetToDefaults();
      if (mounted) setState(() {});
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reminders Tab  (embeds RemindersScreen body content)
// ═══════════════════════════════════════════════════════════════════════════════

class _RemindersTab extends StatelessWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer<ReminderService>(
          builder: (context, service, _) {
            final reminders = service.reminders;
            if (reminders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⏰', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text('कुनै रिमाइन्डर छैन', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black45)),
                    Text('(Tap + to add one)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black38)),
                  ],
                ),
              );
            }
            final groups = <ReminderType, List<Reminder>>{};
            for (final r in reminders) { groups.putIfAbsent(r.type, () => []).add(r); }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                for (final entry in groups.entries) ...[
                  Row(children: [
                    Text(entry.key.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(entry.key.label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
                  ]),
                  const SizedBox(height: 8),
                  for (final r in entry.value)
                    _AdminReminderTile(reminder: r, service: service),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'admin_reminder_fab',
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_alarm_rounded),
            label: Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            onPressed: () => _showReminderForm(context),
          ),
        ),
      ],
    );
  }

  void _showReminderForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderForm(
        service: context.read<ReminderService>(),
      ),
    );
  }
}

class _AdminReminderTile extends StatelessWidget {
  final Reminder reminder;
  final ReminderService service;

  const _AdminReminderTile({required this.reminder, required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: reminder.isActive ? const Color(0xFF0D47A1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(reminder.formattedTime,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold,
              color: reminder.isActive ? Colors.white : Colors.grey),
          ),
        ),
        title: Text(reminder.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        subtitle: Text('${reminder.type.emoji} ${reminder.repeat.label}', style: GoogleFonts.outfit(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: reminder.isActive,
              onChanged: (_) => service.toggleReminder(reminder.id),
              activeThumbColor: const Color(0xFF0D47A1),
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
              onPressed: () => service.deleteReminder(reminder.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Contacts Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _ContactsTab extends StatelessWidget {
  const _ContactsTab();

  static const List<String> _relations = [
    'छोरा (Son)', 'छोरी (Daughter)', 'श्रीमान् (Husband)',
    'श्रीमती (Wife)', 'भाइ (Brother)', 'दिदी (Sister)',
    'डाक्टर (Doctor)', 'छिमेकी (Neighbor)', 'साथी (Friend)', 'अन्य (Other)',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Consumer<ContactService>(
          builder: (context, service, _) {
            final all = service.contacts;
            if (all.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📞', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text('कुनै सम्पर्क छैन', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black45)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: all.length,
              itemBuilder: (ctx, i) {
                final c = all[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: c.isEmergency ? Colors.red[700] : const Color(0xFF0D47A1),
                      child: Text(c.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(c.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    subtitle: Text('${c.relation}  •  ${c.phone}', style: GoogleFonts.outfit(fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.isEmergency) const Icon(Icons.sos_rounded, color: Colors.red, size: 18),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                          onPressed: () => service.deleteContact(c.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'admin_contact_fab',
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_rounded),
            label: Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            onPressed: () => _showContactForm(context),
          ),
        ),
      ],
    );
  }

  void _showContactForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactForm(
        service: context.read<ContactService>(),
        relations: _relations,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// About Tab
// ═══════════════════════════════════════════════════════════════════════════════

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
              ),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.hearing_rounded, size: 64, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Center(child: Text('साथी (Saathi)', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1)))),
        Center(child: Text('Nepali Voice Assistant for Elderly', style: GoogleFonts.outfit(fontSize: 16, color: Colors.black45))),
        const SizedBox(height: 32),
        _AboutRow(label: 'Version', value: '2.0.0'),
        _AboutRow(label: 'Features', value: 'Voice • Reminders • Contacts • SOS'),
        _AboutRow(label: 'Language', value: 'Nepali + English'),
        _AboutRow(label: 'Server Protocol', value: 'JSON + Raw Audio'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Server Response Format', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0D47A1))),
              const SizedBox(height: 8),
              Text(
                '{\n  "action": "set_reminder | make_call | play_audio",\n  "text": "Response text",\n  "audio": "<base64 mp3>",\n  "data": {\n    "phone": "9841000000",\n    "reminder": {...}\n  }\n}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label, value;
  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 16, color: Colors.black54)),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared form widgets (referenced from RemindersTab / ContactsTab)
// ═══════════════════════════════════════════════════════════════════════════════

class _ReminderForm extends StatefulWidget {
  final ReminderService service;
  final Reminder? existing;
  const _ReminderForm({required this.service, this.existing});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late TimeOfDay _time;
  late ReminderType _type;
  late RepeatType _repeat;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _bodyCtrl  = TextEditingController(text: e?.body ?? '');
    _time      = e != null ? TimeOfDay(hour: e.hour, minute: e.minute) : TimeOfDay.now();
    _type      = e?.type ?? ReminderType.medicine;
    _repeat    = e?.repeat ?? RepeatType.daily;
  }

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime() async {
    final p = await showTimePicker(context: context, initialTime: _time);
    if (p != null) setState(() => _time = p);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final r = Reminder(
      id: widget.existing?.id ?? widget.service.newId(),
      title: _titleCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      hour: _time.hour, minute: _time.minute,
      type: _type, repeat: _repeat,
    );
    widget.existing != null
        ? await widget.service.updateReminder(r)
        : await widget.service.addReminder(r);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Reminder' : 'New Reminder',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, decoration: _dec('Title *', Icons.title_rounded), style: GoogleFonts.outfit(fontSize: 17)),
            const SizedBox(height: 12),
            TextField(controller: _bodyCtrl, decoration: _dec('Description', Icons.notes_rounded), maxLines: 2, style: GoogleFonts.outfit(fontSize: 15)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: Colors.blue.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(14), color: const Color(0xFFF0F4FF)),
                child: Row(children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Text('Time: ${_time.format(context)}', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Type', style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: ReminderType.values.map((t) =>
              GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _type == t ? const Color(0xFF0D47A1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${t.emoji} ${t.name}', style: GoogleFonts.outfit(fontSize: 13, color: _type == t ? Colors.white : Colors.black87, fontWeight: _type == t ? FontWeight.bold : FontWeight.normal)),
                ),
              ),
            ).toList()),
            const SizedBox(height: 12),
            Text('Repeat', style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45)),
            const SizedBox(height: 8),
            Row(children: RepeatType.values.map((r) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _repeat = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _repeat == r ? const Color(0xFF0D47A1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(r.name, textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 12, color: _repeat == r ? Colors.white : Colors.black87, fontWeight: _repeat == r ? FontWeight.bold : FontWeight.normal)),
                ),
              ),
            )).toList()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(widget.existing != null ? 'Save' : 'Add Reminder', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: GoogleFonts.outfit(fontSize: 13),
    prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
    filled: true, fillColor: const Color(0xFFF8F9FF),
  );
}

class _ContactForm extends StatefulWidget {
  final ContactService service;
  final Contact? existing;
  final List<String> relations;
  const _ContactForm({required this.service, this.existing, required this.relations});

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late String _relation;
  late bool _isEmergency;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl    = TextEditingController(text: e?.name ?? '');
    _phoneCtrl   = TextEditingController(text: e?.phone ?? '');
    _relation    = e?.relation ?? widget.relations.first;
    _isEmergency = e?.isEmergency ?? false;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    final c = Contact(
      id: widget.existing?.id ?? widget.service.newId(),
      name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(),
      relation: _relation, isEmergency: _isEmergency,
    );
    widget.existing != null
        ? await widget.service.updateContact(c)
        : await widget.service.addContact(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Text(widget.existing != null ? 'Edit Contact' : 'New Contact',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words,
              decoration: _dec('Full Name *', Icons.person_rounded), style: GoogleFonts.outfit(fontSize: 17)),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
              decoration: _dec('Phone Number *', Icons.phone_rounded), style: GoogleFonts.outfit(fontSize: 17)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: widget.relations.contains(_relation) ? _relation : widget.relations.first,
              decoration: InputDecoration(
                labelText: 'Relation', labelStyle: GoogleFonts.outfit(fontSize: 13),
                prefixIcon: const Icon(Icons.group_rounded, color: Color(0xFF0D47A1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: const Color(0xFFF8F9FF),
              ),
              items: widget.relations.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.outfit(fontSize: 15)))).toList(),
              onChanged: (v) => setState(() => _relation = v ?? widget.relations.first),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('🆘 Emergency Contact', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              value: _isEmergency,
              activeThumbColor: Colors.red,
              onChanged: (v) => setState(() => _isEmergency = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Text(widget.existing != null ? 'Save' : 'Add Contact', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: GoogleFonts.outfit(fontSize: 13),
    prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
    filled: true, fillColor: const Color(0xFFF8F9FF),
  );
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.07), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _StyledTextField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.outfit(fontSize: 16),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final int divisions;
  final String displayText;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label, required this.value,
    required this.min, required this.max, required this.divisions,
    required this.displayText, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 14)),
            Text(displayText, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
          ],
        ),
        Slider(value: value, min: min, max: max, divisions: divisions, activeColor: const Color(0xFF0D47A1), onChanged: onChanged),
      ],
    );
  }
}
