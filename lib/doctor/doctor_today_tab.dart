import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'doctor_appointments.dart';

/// The doctor's start screen: today's numbers, the next patient and the day's timeline.
class DoctorTodayTab extends StatefulWidget {
  const DoctorTodayTab({super.key});

  @override
  State<DoctorTodayTab> createState() => _DoctorTodayTabState();
}

class _DoctorTodayTabState extends State<DoctorTodayTab> {
  late Future<List<DoctorAppointment>> _future = _load();

  Future<List<DoctorAppointment>> _load() =>
      loadDoctorAppointments(SessionScope.read(context).api);

  void _reload() => setState(() => _future = _load());

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<DoctorAppointment>>(
            future: _future,
            builder: (context, snapshot) {
              final all = snapshot.data;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()},',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 15,
                              ),
                            ),
                            const Text(
                              'Doktor',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Çıkış yap',
                        icon: const Icon(Icons.power_settings_new_rounded),
                        onPressed: () => confirmSignOut(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.hasError)
                    MessageView(
                      icon: Icons.cloud_off_rounded,
                      text: '${snapshot.error}',
                      action: FilledButton(
                        onPressed: _reload,
                        child: const Text('Tekrar dene'),
                      ),
                    )
                  else if (all == null)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._content(all),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<DoctorAppointment> all) {
    final now = DateTime.now();
    final today = all.where((a) => a.isToday).toList();
    final active = today.where((a) => a.status != 'Cancelled').toList();
    final next = all.where((a) => a.isOpen && a.end.isAfter(now)).firstOrNull;
    final pending = all
        .where((a) => a.status == 'Pending' && a.end.isAfter(now))
        .length;

    return [
      _HeroSummary(
        total: active.length,
        pending: today.where((a) => a.status == 'Pending').length,
        approved: today.where((a) => a.status == 'Approved').length,
        done: today.where((a) => a.status == 'Completed').length,
      ),
      if (pending > 0) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Onayınızı bekleyen $pending randevu var.',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 24),
      const SectionHeader('Sıradaki Hasta'),
      if (next == null)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Yaklaşan randevunuz yok.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        )
      else
        _NextPatientCard(appointment: next, onChanged: _reload),
      const SizedBox(height: 24),
      SectionHeader('Bugünün Programı · ${longDay(now)}'),
      if (today.isEmpty)
        const MessageView(
          icon: Icons.event_available_rounded,
          text: 'Bugün için randevunuz yok.',
        )
      else
        for (var i = 0; i < today.length; i++)
          _TimelineEntry(
            appointment: today[i],
            isLast: i == today.length - 1,
            isNow: !now.isBefore(today[i].start) && now.isBefore(today[i].end),
            onTap: () => showPatientInfo(context, today[i], _reload),
          ),
    ];
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.total,
    required this.pending,
    required this.approved,
    required this.done,
  });

  final int total;
  final int pending;
  final int approved;
  final int done;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugün',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
            ),
          ),
          Text(
            total == 0 ? 'Randevunuz yok' : '$total randevunuz var',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              stat('Bekleyen', pending),
              const SizedBox(width: 10),
              stat('Onaylı', approved),
              const SizedBox(width: 10),
              stat('Tamamlanan', done),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextPatientCard extends StatelessWidget {
  const _NextPatientCard({required this.appointment, required this.onChanged});

  final DoctorAppointment appointment;
  final VoidCallback onChanged;

  String _when() {
    final now = DateTime.now();
    if (!now.isBefore(appointment.start)) return 'Şu an';
    final mins = appointment.start.difference(now).inMinutes;
    if (appointment.isToday) {
      return mins < 60
          ? '$mins dk sonra'
          : '${mins ~/ 60} sa ${mins % 60} dk sonra';
    }
    return '${longDay(appointment.start)} ${hhmm(appointment.start)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.card + 1),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPatientInfo(context, appointment, onChanged),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hhmm(appointment.start),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _when(),
                            style: const TextStyle(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(appointment.status),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    AppointmentActions(
                      appointment: appointment,
                      onChanged: onChanged,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          showPatientInfo(context, appointment, onChanged),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Hasta bilgisi'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.appointment,
    required this.isLast,
    required this.isNow,
    required this.onTap,
  });

  final DoctorAppointment appointment;
  final bool isLast;
  final bool isNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (_, color) = StatusChip.describe(appointment.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                hhmm(appointment.start),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isNow ? AppColors.cyan : Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isNow ? AppColors.cyan : color,
                    shape: BoxShape.circle,
                    boxShadow: isNow
                        ? [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.6),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: AppColors.divider),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${hhmm(appointment.start)} – ${hhmm(appointment.end)}'
                                '${appointment.forDependent ? ' · yakın adına' : ''}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StatusChip(appointment.status),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
