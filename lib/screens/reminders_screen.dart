import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/reminder_service.dart';
import '../models/reminder_model.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text('रिमाइन्डरहरू', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ReminderService>(
        builder: (context, service, _) {
          final reminders = service.reminders;
          if (reminders.isEmpty) {
            return _EmptyState(
              onAdd: () => _showAddEditDialog(context, service),
            );
          }
          // Group by type
          final groups = <ReminderType, List<Reminder>>{};
          for (final r in reminders) {
            groups.putIfAbsent(r.type, () => []).add(r);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in groups.entries) ...[
                _GroupHeader(type: entry.key),
                const SizedBox(height: 8),
                for (final r in entry.value)
                  _ReminderCard(
                    reminder: r,
                    onToggle: () => service.toggleReminder(r.id),
                    onEdit:   () => _showAddEditDialog(context, service, existing: r),
                    onDelete: () => _confirmDelete(context, service, r),
                  ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm_rounded),
        label: Text('रिमाइन्डर थप्नुस्', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditDialog(context, context.read<ReminderService>()),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  Future<void> _showAddEditDialog(
    BuildContext context,
    ReminderService service, {
    Reminder? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderForm(
        service: service,
        existing: existing,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReminderService service,
    Reminder r,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('रिमाइन्डर मेटाउने?'),
        content: Text('"${r.title}" मेटाउन निश्चित हुनुहुन्छ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('मेटाउनुस्'),
          ),
        ],
      ),
    );
    if (confirmed == true) await service.deleteReminder(r.id);
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⏰', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text('कुनै रिमाइन्डर छैन', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text('(No reminders yet)', style: GoogleFonts.outfit(fontSize: 16, color: Colors.black38)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_alarm_rounded),
            label: const Text('पहिलो रिमाइन्डर थप्नुस्'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ─── Group Header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final ReminderType type;
  const _GroupHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(type.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text(type.label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1))),
      ],
    );
  }
}

// ─── Reminder Card ────────────────────────────────────────────────────────────

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = reminder.isActive;
    return Dismissible(
      key: Key('reminder_${reminder.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 30),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // handled in onDelete
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
            border: Border.all(color: isActive ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              // Time badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF0D47A1) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reminder.formattedTime,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (reminder.body.isNotEmpty)
                      Text(
                        reminder.body,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reminder.repeat.label,
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF1565C0)),
                      ),
                    ),
                  ],
                ),
              ),
              // Active switch
              Switch(
                value: isActive,
                onChanged: (_) => onToggle(),
                activeThumbColor: const Color(0xFF0D47A1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reminder Form (Bottom Sheet) ─────────────────────────────────────────────

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
  late TimeOfDay _selectedTime;
  late ReminderType _selectedType;
  late RepeatType _selectedRepeat;
  late ReminderMode _selectedMode;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl    = TextEditingController(text: e?.title ?? '');
    _bodyCtrl     = TextEditingController(text: e?.body ?? '');
    _selectedTime = e != null ? TimeOfDay(hour: e.hour, minute: e.minute) : TimeOfDay.now();
    _selectedType = e?.type   ?? ReminderType.medicine;
    _selectedRepeat = e?.repeat ?? RepeatType.daily;
    _selectedMode = e?.mode   ?? ReminderMode.alarm;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Colors.white,
            hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('शीर्षक आवश्यक छ (Title is required)')),
      );
      return;
    }
    final reminder = Reminder(
      id:     widget.existing?.id ?? widget.service.newId(),
      title:  title,
      body:   _bodyCtrl.text.trim(),
      hour:   _selectedTime.hour,
      minute: _selectedTime.minute,
      type:   _selectedType,
      repeat: _selectedRepeat,
      mode:   _selectedMode,
    );

    if (widget.existing != null) {
      await widget.service.updateReminder(reminder);
    } else {
      await widget.service.addReminder(reminder);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'रिमाइन्डर सम्पादन' : 'नयाँ रिमाइन्डर',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.outfit(fontSize: 18),
              decoration: _inputDecoration('शीर्षक (Title) *', Icons.title_rounded),
            ),
            const SizedBox(height: 14),

            // Body
            TextField(
              controller: _bodyCtrl,
              style: GoogleFonts.outfit(fontSize: 16),
              maxLines: 2,
              decoration: _inputDecoration('विवरण (Description)', Icons.notes_rounded),
            ),
            const SizedBox(height: 14),

            // Time Picker
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFF0F4FF),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF0D47A1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('समय: ${_selectedTime.format(context)}',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1)),
                      ),
                    ),
                    const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Type picker
            Text('प्रकार (Type)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ReminderType.values.map((t) => GestureDetector(
                onTap: () => setState(() => _selectedType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedType == t ? const Color(0xFF0D47A1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedType == t ? const Color(0xFF0D47A1) : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '${t.emoji} ${t.label}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: _selectedType == t ? Colors.white : Colors.black87,
                      fontWeight: _selectedType == t ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 14),

            // Repeat picker
            Text('दोहोराउने (Repeat)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: RepeatType.values.map((r) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRepeat = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedRepeat == r ? const Color(0xFF0D47A1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      r == RepeatType.once ? 'Once' :
                      r == RepeatType.daily ? 'Daily' :
                      r == RepeatType.weekdays ? 'Wkdays' : 'Wkend',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _selectedRepeat == r ? Colors.white : Colors.black87,
                        fontWeight: _selectedRepeat == r ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 14),

            // Mode picker
            Text('रिमाइन्डरको तरिका (Mode)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Row(
              children: ReminderMode.values.map((m) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedMode == m ? const Color(0xFF0D47A1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m == ReminderMode.alarm ? 'सामान्य अलार्म' : 'आवाज पुष्टि',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _selectedMode == m ? Colors.white : Colors.black87,
                        fontWeight: _selectedMode == m ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(isEdit ? Icons.save_rounded : Icons.add_alarm_rounded),
                label: Text(isEdit ? 'सुरक्षित गर्नुस् (Save)' : 'थप्नुस् (Add)',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.outfit(fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
    ),
    filled: true,
    fillColor: const Color(0xFFF8F9FF),
  );
}
