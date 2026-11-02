import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../documents/appointment_document.dart';
import '../theme/app_theme.dart';
import 'appointment_actions.dart';
import 'book_appointment_screen.dart';
import 'reschedule_screen.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  /// Stars the user already gave, by appointment id.
  Map<String, int> _stars = {};

  Future<void> _book() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BookAppointmentScreen()),
    );
    if (booked == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Randevularım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        icon: const Icon(Icons.add),
        label: const Text('Randevu Al'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Henüz randevunuz yok.',
        emptyIcon: Icons.event_busy_rounded,
        load: () async {
          final results = await Future.wait([
            api.get('/api/appointments/my'),
            api.get('/api/reviews/mine'),
          ]);
          final items = (results[0] as List).cast<Map<String, dynamic>>();
          _stars = {
            for (final r in (results[1] as List).cast<Map<String, dynamic>>())
              r['appointmentId'] as String: r['stars'] as int,
          };
          items.sort(
            (a, b) => (b['appointmentDateUtc'] as String).compareTo(
              a['appointmentDateUtc'] as String,
            ),
          );
          return items;
        },
        itemBuilder: (context, a, reload) {
          final status = a['status'] as String;
          final cancellable = status == 'Pending' || status == 'Approved';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const TintedIcon(
                        Icons.event_rounded,
                        color: AppColors.warning,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatDateTime(a['appointmentDateUtc'] as String),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      StatusChip(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    a['doctorName'] as String? ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  Text(
                    a['departmentName'] as String? ?? '',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  if (a['dependentFullName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.family_restroom_rounded,
                            size: 16,
                            color: Color(0xFFA78BFA),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${a['dependentFullName']} için',
                            style: const TextStyle(color: Color(0xFFA78BFA)),
                          ),
                        ],
                      ),
                    ),
                  if (a['hospitalName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_hospital_rounded,
                            size: 16,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a['hospitalName'] as String,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (status == 'Completed')
                    ReviewArea(
                      stars: _stars[a['id']],
                      onReview: () async {
                        final stars = await showReviewSheet(context, a);
                        if (stars != null) {
                          setState(() => _stars[a['id'] as String] = stars);
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Belge'),
                        onPressed: () =>
                            openAppointmentDocument(context, a['id'] as String),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.directions_rounded),
                        label: const Text('Yol tarifi'),
                        onPressed: () => openDirections(context, a),
                      ),
                      if (cancellable)
                        TextButton.icon(
                          icon: const Icon(Icons.event_available_rounded),
                          label: const Text('Takvime ekle'),
                          onPressed: () => addToCalendar(context, a),
                        ),
                      if (cancellable) ...[
                        const SizedBox(width: 4),
                        TextButton.icon(
                          icon: const Icon(Icons.update_rounded),
                          label: const Text('Ertele'),
                          onPressed: () async {
                            final moved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RescheduleScreen(appointment: a),
                                  ),
                                );
                            if (moved == true) reload();
                          },
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                          ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('İptal Et'),
                          onPressed: () async {
                            if (!await confirm(
                              context,
                              'UYARI',
                              'Bu randevu iptal edilecek. Emin misiniz?',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            final ok = await runWithFeedback(
                              context,
                              () => api.put(
                                '/api/appointments/${a['id']}/cancel',
                                {'reason': null},
                              ),
                              success: 'Randevu iptal edildi.',
                            );
                            if (ok) reload();
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
