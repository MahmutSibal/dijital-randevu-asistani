import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];

/// The patient's blood type, allergies, chronic diseases, medications and emergency contact.
class HealthProfileScreen extends StatefulWidget {
  const HealthProfileScreen({super.key});

  @override
  State<HealthProfileScreen> createState() => _HealthProfileScreenState();
}

class _HealthProfileScreenState extends State<HealthProfileScreen> {
  late final ApiClient _api = SessionScope.read(context).api;
  final _allergies = TextEditingController();
  final _chronic = TextEditingController();
  final _medications = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String? _bloodType;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _allergies,
      _chronic,
      _medications,
      _contactName,
      _contactPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _api.get(
        '/api/patient/health-profile',
      ) as Map<String, dynamic>?;
      if (p != null) {
        final blood = p['bloodType'] as String?;
        _bloodType = _bloodTypes.contains(blood) ? blood : null;
        _allergies.text = p['allergies'] as String? ?? '';
        _chronic.text = p['chronicDiseases'] as String? ?? '';
        _medications.text = p['medications'] as String? ?? '';
        _contactName.text = p['emergencyContactName'] as String? ?? '';
        _contactPhone.text = p['emergencyContactPhone'] as String? ?? '';
      }
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    String? value(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => _api.put('/api/patient/health-profile', {
        'bloodType': _bloodType,
        'allergies': value(_allergies),
        'chronicDiseases': value(_chronic),
        'medications': value(_medications),
        'emergencyContactName': value(_contactName),
        'emergencyContactPhone': value(_contactPhone),
      }),
      success: 'Sağlık profiliniz kaydedildi.',
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _section(IconData icon, Color color, String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        TintedIcon(icon, color: color, size: 36),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController c,
    String label, {
    int lines = 1,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      minLines: lines,
      maxLines: lines + 2,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sağlık Profilim')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? MessageView(icon: Icons.cloud_off_rounded, text: _error!)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                const Text(
                  'Bu bilgiler randevularınızda doktorunuzun sizi daha iyi tanımasına yardımcı olur.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                _section(
                  Icons.bloodtype_rounded,
                  AppColors.danger,
                  'Kan Grubu',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in _bloodTypes)
                      ChoiceChip(
                        label: Text(b),
                        selected: _bloodType == b,
                        showCheckmark: false,
                        selectedColor: AppColors.danger.withValues(alpha: 0.3),
                        onSelected: (on) =>
                            setState(() => _bloodType = on ? b : null),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _section(
                  Icons.healing_rounded,
                  AppColors.warning,
                  'Sağlık Bilgileri',
                ),
                _field(_allergies, 'Alerjiler', lines: 2),
                _field(_chronic, 'Kronik hastalıklar', lines: 2),
                _field(_medications, 'Kullanılan ilaçlar', lines: 2),
                const SizedBox(height: 6),
                _section(
                  Icons.contact_phone_rounded,
                  AppColors.success,
                  'Acil Durumda Aranacak Kişi',
                ),
                _field(_contactName, 'Ad soyad'),
                _field(_contactPhone, 'Telefon', type: TextInputType.phone),
                const SizedBox(height: 12),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : GradientButton(
                        label: 'Kaydet',
                        icon: Icons.save_rounded,
                        onPressed: _save,
                      ),
              ],
            ),
    );
  }
}
