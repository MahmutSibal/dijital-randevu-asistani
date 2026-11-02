import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'slot_picker.dart';

/// Moves an appointment to another free slot with the same doctor. Pops `true` when done.
class RescheduleScreen extends StatefulWidget {
  const RescheduleScreen({super.key, required this.appointment});

  /// AppointmentDto as JSON.
  final Map<String, dynamic> appointment;

  @override
  State<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends State<RescheduleScreen> {
  PickedSlot? _slot;
  bool _saving = false;

  Future<void> _save() async {
    final api = SessionScope.read(context).api;
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => api.put(
        '/api/appointments/${widget.appointment['id']}/reschedule',
        {'newAppointmentDate': _slot!.iso},
      ),
      success: 'Randevunuz ertelendi.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Scaffold(
      appBar: AppBar(title: const Text('Randevuyu Ertele')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          InfoTile(
            icon: Icons.event_rounded,
            color: AppColors.warning,
            title: a['doctorName'] as String? ?? '',
            subtitle:
                '${a['departmentName']}\nŞu anki saat: ${formatDateTime(a['appointmentDateUtc'] as String)}',
          ),
          const SizedBox(height: 20),
          const Text(
            'Yeni gün ve saat',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SlotPicker(
            doctorId: a['doctorId'] as int,
            onChanged: (s) => setState(() => _slot = s),
          ),
          const SizedBox(height: 24),
          if (_slot != null)
            _saving
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Yeni Saati Onayla (${_slot!.label})',
                    icon: Icons.update_rounded,
                    onPressed: _save,
                  ),
        ],
      ),
    );
  }
}
