import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'doctor_appointments.dart';

enum _Filter {
  upcoming('Yaklaşan'),
  pending('Onay bekleyen'),
  past('Geçmiş');

  const _Filter(this.label);
  final String label;
}

/// All of the doctor's appointments, filtered and grouped by day.
class DoctorAppointmentsTab extends StatefulWidget {
  const DoctorAppointmentsTab({super.key});

  @override
  State<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends State<DoctorAppointmentsTab> {
  late Future<List<DoctorAppointment>> _future = _load();
  _Filter _filter = _Filter.upcoming;

  Future<List<DoctorAppointment>> _load() =>
      loadDoctorAppointments(SessionScope.read(context).api);

  void _reload() => setState(() => _future = _load());

  List<DoctorAppointment> _apply(List<DoctorAppointment> all) {
    final now = DateTime.now();
    return switch (_filter) {
      _Filter.upcoming =>
        all.where((a) => a.isOpen && a.end.isAfter(now)).toList(),
      _Filter.pending =>
        all.where((a) => a.status == 'Pending' && a.end.isAfter(now)).toList(),
      _Filter.past =>
        all
            .where((a) => !a.end.isAfter(now) || !a.isOpen)
            .toList()
            .reversed
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      title: 'Randevular',
      onSignOut: () => confirmSignOut(context),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: _filter == f ? AppGradients.primary : null,
                          color: _filter == f ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _filter == f
                                ? Colors.transparent
                                : AppColors.outline,
                          ),
                        ),
                        child: Text(
                          f.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _filter == f
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<DoctorAppointment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return MessageView(
                      icon: Icons.cloud_off_rounded,
                      text: '${snapshot.error}',
                      action: FilledButton(
                        onPressed: _reload,
                        child: const Text('Tekrar dene'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = _apply(snapshot.data!);
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        MessageView(
                          icon: Icons.event_available_rounded,
                          text: 'Bu listede randevu yok.',
                        ),
                      ],
                    );
                  }
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i == 0 ||
                            !DateUtils.isSameDay(
                              items[i].start,
                              items[i - 1].start,
                            ))
                          Padding(
                            padding: EdgeInsets.only(
                              top: i == 0 ? 4 : 16,
                              bottom: 8,
                            ),
                            child: Text(
                              items[i].isToday
                                  ? 'Bugün · ${longDay(items[i].start)}'
                                  : longDay(items[i].start),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AppointmentCard(
                            appointment: items[i],
                            onChanged: _reload,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onChanged});

  final DoctorAppointment appointment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showPatientInfo(context, appointment, onChanged),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hhmm(appointment.start),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (appointment.forDependent)
                          const Text(
                            'Yakın adına alınmış',
                            style: TextStyle(
                              color: Color(0xFFA78BFA),
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusChip(appointment.status),
                ],
              ),
              if (appointment.isOpen) ...[
                const SizedBox(height: 12),
                AppointmentActions(
                  appointment: appointment,
                  onChanged: onChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
