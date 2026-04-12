import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/contact_service.dart';
import '../models/contact_model.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  static const List<String> _relations = [
    'छोरा (Son)', 'छोरी (Daughter)', 'श्रीमान् (Husband)',
    'श्रीमती (Wife)', 'भाइ (Brother)', 'दिदी (Sister)',
    'डाक्टर (Doctor)', 'छिमेकी (Neighbor)', 'साथी (Friend)', 'अन्य (Other)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: Text('सम्पर्कहरू', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<ContactService>(
        builder: (context, service, _) {
          final all       = service.contacts;
          final emergency = all.where((c) => c.isEmergency).toList();
          final regular   = all.where((c) => !c.isEmergency).toList();

          if (all.isEmpty) {
            return _EmptyContacts(
              onAdd: () => _showContactForm(context, service),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (emergency.isNotEmpty) ...[
                _SectionHeader(label: '🆘 आपतकालीन सम्पर्क (Emergency)', color: Colors.red[700]!),
                const SizedBox(height: 8),
                ...emergency.map((c) => _ContactCard(
                  contact: c,
                  onCall:   () => service.callContact(c),
                  onEdit:   () => _showContactForm(context, service, existing: c),
                  onDelete: () => _confirmDelete(context, service, c),
                )),
                const SizedBox(height: 16),
              ],
              if (regular.isNotEmpty) ...[
                _SectionHeader(label: '👥 सम्पर्क सूची (Contacts)', color: const Color(0xFF0D47A1)),
                const SizedBox(height: 8),
                ...regular.map((c) => _ContactCard(
                  contact: c,
                  onCall:   () => service.callContact(c),
                  onEdit:   () => _showContactForm(context, service, existing: c),
                  onDelete: () => _confirmDelete(context, service, c),
                )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: Text('सम्पर्क थप्नुस्', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        onPressed: () => _showContactForm(context, context.read<ContactService>()),
      ),
    );
  }

  Future<void> _showContactForm(
    BuildContext context,
    ContactService service, {
    Contact? existing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactForm(service: service, existing: existing, relations: _relations),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ContactService service,
    Contact c,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('सम्पर्क मेटाउने?'),
        content: Text('"${c.name}" मेटाउन निश्चित हुनुहुन्छ?'),
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
    if (confirmed == true) await service.deleteContact(c.id);
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: color));
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyContacts extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyContacts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📞', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text('कुनै सम्पर्क छैन', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black54)),
          Text('(No contacts yet)', style: GoogleFonts.outfit(fontSize: 16, color: Colors.black38)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('पहिलो सम्पर्क थप्नुस्'),
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

// ─── Contact Card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEmergency = contact.isEmergency;
    final avatarColor = isEmergency ? Colors.red[700]! : const Color(0xFF0D47A1);

    return Dismissible(
      key: Key('contact_${contact.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 30),
      ),
      confirmDismiss: (_) async { onDelete(); return false; },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: avatarColor.withValues(alpha: 0.1),
              blurRadius: 10, offset: const Offset(0, 4),
            ),
          ],
          border: isEmergency
              ? Border.all(color: Colors.red.withValues(alpha: 0.3))
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: avatarColor,
            child: Text(
              contact.initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          title: Text(
            contact.name,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contact.relation.isNotEmpty)
                Text(contact.relation, style: GoogleFonts.outfit(fontSize: 13, color: Colors.black45)),
              Text(contact.phone, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
              if (isEmergency)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('🆘 Emergency', style: GoogleFonts.outfit(fontSize: 11, color: Colors.red[700])),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                onPressed: onEdit,
              ),
              GestureDetector(
                onTap: () { HapticFeedback.heavyImpact(); onCall(); },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEmergency
                          ? [Colors.red[400]!, Colors.red[700]!]
                          : [const Color(0xFF1E88E5), const Color(0xFF0D47A1)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withValues(alpha: 0.3),
                        blurRadius: 8, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Contact Form (bottom sheet) ──────────────────────────────────────────────

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
  late String  _selectedRelation;
  late bool    _isEmergency;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl        = TextEditingController(text: e?.name ?? '');
    _phoneCtrl       = TextEditingController(text: e?.phone ?? '');
    _selectedRelation = e?.relation ?? widget.relations.first;
    _isEmergency     = e?.isEmergency ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('नाम र फोन नम्बर आवश्यक छ')),
      );
      return;
    }

    final contact = Contact(
      id:          widget.existing?.id ?? widget.service.newId(),
      name:        name,
      phone:       phone,
      relation:    _selectedRelation,
      isEmergency: _isEmergency,
    );

    if (widget.existing != null) {
      await widget.service.updateContact(contact);
    } else {
      await widget.service.addContact(contact);
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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'सम्पर्क सम्पादन' : 'नयाँ सम्पर्क',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 20),

            // Name
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.outfit(fontSize: 18),
              decoration: _dec('नाम (Full Name) *', Icons.person_rounded),
            ),
            const SizedBox(height: 14),

            // Phone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.outfit(fontSize: 18),
              decoration: _dec('फोन नम्बर (Phone) *', Icons.smartphone_rounded),
            ),
            const SizedBox(height: 14),

            // Relation
            Text('सम्बन्ध (Relation)', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: widget.relations.contains(_selectedRelation) ? _selectedRelation : widget.relations.first,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                ),
                filled: true, fillColor: const Color(0xFFF8F9FF),
              ),
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
              items: widget.relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _selectedRelation = v ?? widget.relations.first),
            ),
            const SizedBox(height: 14),

            // Emergency toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isEmergency ? Colors.red.withValues(alpha: 0.08) : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isEmergency ? Colors.red.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Text('🆘', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('आपतकालीन सम्पर्क', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('(Show as emergency contact)', style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isEmergency,
                    onChanged: (v) => setState(() => _isEmergency = v),
                    activeThumbColor: Colors.red,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(isEdit ? Icons.save_rounded : Icons.person_add_rounded),
                label: Text(
                  isEdit ? 'सुरक्षित (Save)' : 'थप्नुस् (Add)',
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

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
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
