import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'appointment_actions.dart';

/// Average stars and the latest comments for the doctor being booked.
class DoctorRatingCard extends StatefulWidget {
  const DoctorRatingCard({super.key, required this.doctorId});

  final int doctorId;

  @override
  State<DoctorRatingCard> createState() => _DoctorRatingCardState();
}

class _DoctorRatingCardState extends State<DoctorRatingCard> {
  Map<String, dynamic>? _rating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DoctorRatingCard old) {
    super.didUpdateWidget(old);
    if (old.doctorId != widget.doctorId) {
      _rating = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final j = await SessionScope.read(context).api
          .get('/api/reviews/doctors/${widget.doctorId}');
      if (mounted) setState(() => _rating = j as Map<String, dynamic>);
    } catch (_) {
      // Ratings are extra; booking works without them.
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _rating;
    if (r == null) return const SizedBox.shrink();
    final count = r['count'] as int;
    final latest = (r['latest'] as List).cast<Map<String, dynamic>>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: count == 0
            ? const Row(
                children: [
                  Icon(Icons.star_outline_rounded, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'Bu doktor için henüz değerlendirme yok.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${r['average']}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      StarRow(stars: r['average'] as num),
                      const Spacer(),
                      Text(
                        '$count değerlendirme',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  for (final c
                      in latest
                          .where(
                            (c) =>
                                (c['comment'] as String?)?.isNotEmpty == true,
                          )
                          .take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '“${c['comment']}” — ${c['patientInitials']}, ${formatDateTime(c['createdAtUtc'] as String).split(' ').first}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
