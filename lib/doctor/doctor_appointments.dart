import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// A doctor's appointment (DoctorAppointmentDto) in local time.
class DoctorAppointment {
  DoctorAppointment(Map<String, dynamic> json)
    : id = json['id'] as String,
      start = DateTime.parse(json['startAtUtc'] as String).toLocal(),
      end = DateTime.parse(json['endAtUtc'] as String).toLocal(),
      status = json['status'] as String,
      patientName = (json['patientName'] as String?)?.trim().isNotEmpty == true
          ? json['patientName'] as String
          : json['patientEmail'] as String? ?? '',
      forDependent = json['forDependent'] == true;

  final String id;
  final DateTime start;
  final DateTime end;
  final String status;
  final String patientName;
  final bool forDependent;

  bool get isOpen => status == 'Pending' || status == 'Approved';
  bool get isToday => DateUtils.isSameDay(start, DateTime.now());
}

Future<List<DoctorAppointment>> loadDoctorAppointments(ApiClient api) async {
  final items = (await api.get('/api/doctor/appointments/my') as List)
      .map((j) => DoctorAppointment(j as Map<String, dynamic>))
      .toList();
  items.sort((a, b) => a.start.compareTo(b.start));
  return items;
}

String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
const _weekdays = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// "27 Ekim Pazartesi"
String longDay(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${_weekdays[d.weekday - 1]}';

/// Approve / complete / no-show buttons for an open appointment. Calls [onChanged] after a change.
class AppointmentActions extends StatelessWidget {
  const AppointmentActions({
    super.key,
    required this.appointment,
    required this.onChanged,
  });

  final DoctorAppointment appointment;
  final VoidCallback onChanged;

  Future<void> _act(BuildContext context, String action, String done) async {
    final api = SessionScope.read(context).api;
    final ok = await runWithFeedback(
      context,
      () => api.put('/api/doctor/appointments/${appointment.id}/$action'),
      success: done,
    );
    if (ok) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (appointment.status == 'Pending') {
      return FilledButton.icon(
        icon: const Icon(Icons.check_rounded),
        label: const Text('Onayla'),
        onPressed: () => _act(context, 'approve', 'Randevu onaylandı.'),
      );
    }
    if (appointment.status != 'Approved') return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('Tamamlandı'),
          onPressed: () => _act(context, 'complete', 'Muayene tamamlandı.'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('Gelmedi'),
          onPressed: () =>
              _act(context, 'no-show', 'Hasta gelmedi olarak işaretlendi.'),
        ),
      ],
    );
  }
}

/// Bottom sheet with who the patient is and their health profile.
Future<void> showPatientInfo(
  BuildContext context,
  DoctorAppointment appointment,
  VoidCallback onChanged,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _PatientInfoSheet(appointment: appointment, onChanged: onChanged),
  );
}

const _relations = {
  'Child': 'Çocuğu',
  'Mother': 'Annesi',
  'Father': 'Babası',
  'Sister': 'Kız kardeşi',
  'Brother': 'Erkek kardeşi',
};

class _PatientInfoSheet extends StatelessWidget {
  const _PatientInfoSheet({required this.appointment, required this.onChanged});

  final DoctorAppointment appointment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.read(context).api;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder(
        future: api.get('/api/doctor/appointments/${appointment.id}/patient'),
        builder: (context, snapshot) {
          final p = snapshot.data as Map<String, dynamic>?;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      appointment.patientName.isEmpty
                          ? '?'
                          : appointment.patientName.characters.first
                                .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${longDay(appointment.start)} · ${hhmm(appointment.start)}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(appointment.status),
                ],
              ),
              const SizedBox(height: 16),
              AppointmentActions(
                appointment: appointment,
                onChanged: () {
                  Navigator.pop(context);
                  onChanged();
                },
              ),
              const SizedBox(height: 20),
              if (snapshot.hasError)
                Text(
                  '${snapshot.error}',
                  style: const TextStyle(color: AppColors.danger),
                )
              else if (p == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._details(p),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _details(Map<String, dynamic> p) {
    final parsed = DateTime.tryParse(p['birthDate'] as String? ?? '');
    final birth = parsed != null && parsed.year > 1900 ? parsed : null;
    final age = birth == null ? null : _age(birth);
    Widget row(IconData icon, Color color, String label, String? value) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(icon, color: color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (value == null || value.isEmpty)
                          ? 'Belirtilmemiş'
                          : value,
                      style: const TextStyle(fontSize: 15, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return [
      if (p['forDependent'] == true)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFA78BFA).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${p['accountHolderName']} adlı hastanın ${_relations[p['dependentRelation']]?.toLowerCase() ?? 'yakını'} için alınmış randevu. '
            'Sağlık profili hesap sahibine ait olduğu için gösterilmiyor.',
            style: const TextStyle(color: Color(0xFFC4B5FD), height: 1.4),
          ),
        ),
      row(
        Icons.cake_rounded,
        AppColors.cyan,
        'Doğum tarihi',
        birth == null
            ? null
            : '${birth.day.toString().padLeft(2, '0')}.${birth.month.toString().padLeft(2, '0')}.${birth.year}  ($age yaş)',
      ),
      row(
        Icons.phone_rounded,
        AppColors.success,
        'Telefon',
        p['phone'] as String?,
      ),
      if (p['forDependent'] != true) ...[
        const SizedBox(height: 6),
        const Text(
          'SAĞLIK PROFİLİ',
          style: TextStyle(color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        row(
          Icons.bloodtype_rounded,
          AppColors.danger,
          'Kan grubu',
          p['bloodType'] as String?,
        ),
        row(
          Icons.warning_amber_rounded,
          AppColors.warning,
          'Alerjiler',
          p['allergies'] as String?,
        ),
        row(
          Icons.monitor_heart_rounded,
          const Color(0xFFFF7043),
          'Kronik hastalıklar',
          p['chronicDiseases'] as String?,
        ),
        row(
          Icons.medication_rounded,
          AppColors.primary,
          'Kullandığı ilaçlar',
          p['medications'] as String?,
        ),
        row(
          Icons.contact_emergency_rounded,
          const Color(0xFFA78BFA),
          'Acil durumda aranacak kişi',
          [
            p['emergencyContactName'],
            p['emergencyContactPhone'],
          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
        ),
      ],
    ];
  }

  static int _age(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }
}
