import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

/// Opens Google Maps with directions to the appointment's hospital; uses the name and
/// address when the hospital has no coordinates.
Future<void> openDirections(
  BuildContext context,
  Map<String, dynamic> a,
) async {
  final lat = a['hospitalLatitude'];
  final lng = a['hospitalLongitude'];
  final destination = lat != null && lng != null
      ? '$lat,$lng'
      : [
          a['hospitalName'],
          a['hospitalAddress'],
        ].whereType<String>().join(', ');
  if (destination.isEmpty) {
    _toast(context, 'Hastane konumu bulunamadı.');
    return;
  }
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': destination,
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    _toast(context, 'Harita açılamadı.');
  }
}

/// Adds the appointment to the user's calendar through Google Calendar's event form.
Future<void> addToCalendar(BuildContext context, Map<String, dynamic> a) async {
  final start = DateTime.parse(a['appointmentDateUtc'] as String).toUtc();
  final end = start.add(const Duration(minutes: 30));
  String stamp(DateTime d) =>
      '${d.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'Randevu: ${a['departmentName'] ?? ''} - ${a['doctorName'] ?? ''}',
    'dates': '${stamp(start)}/${stamp(end)}',
    'details': 'Dijital Randevu Asistanı randevusu. Lütfen randevu saatinden 15 dakika önce hastanede olun.',
    'location': [
      a['hospitalName'],
      a['hospitalAddress'],
    ].whereType<String>().join(', '),
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    _toast(context, 'Takvim açılamadı.');
  }
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Shows the stars already given, or a button to rate a completed appointment.
class ReviewArea extends StatelessWidget {
  const ReviewArea({super.key, required this.stars, required this.onReview});

  final int? stars;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: stars == null
          ? FilledButton.tonalIcon(
              onPressed: onReview,
              icon: const Icon(Icons.star_rate_rounded),
              label: const Text('Doktoru değerlendir'),
            )
          : Row(
              children: [
                StarRow(stars: stars!),
                const SizedBox(width: 8),
                const Text(
                  'Değerlendirmeniz',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 20});

  final num stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            stars >= i
                ? Icons.star_rounded
                : stars >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: AppColors.warning,
          ),
      ],
    );
  }
}

/// Asks for 1-5 stars and an optional comment; returns the stars once saved.
Future<int?> showReviewSheet(BuildContext context, Map<String, dynamic> a) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReviewSheet(appointment: a),
    );

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _stars = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _labels = ['', 'Çok kötü', 'Kötü', 'Orta', 'İyi', 'Çok iyi'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).api.post(
        '/api/appointments/${widget.appointment['id']}/review',
        {'stars': _stars, 'comment': _comment.text.trim()},
      );
      if (mounted) Navigator.pop(context, _stars);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const Text(
            'Muayenenizi değerlendirin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.appointment['doctorName'] ?? ''} · ${widget.appointment['departmentName'] ?? ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 42,
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    _stars >= i
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          Text(
            _labels[_stars],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Yorumunuz (isteğe bağlı)',
              alignLabelWithHint: true,
            ),
          ),
          const Text(
            'Yorumunuz diğer hastalara yalnızca baş harfleriniz ile gösterilir.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 14),
          _busy
              ? const Center(child: CircularProgressIndicator())
              : GradientButton(
                  label: 'Gönder',
                  icon: Icons.send_rounded,
                  onPressed: _stars == 0 ? null : _save,
                ),
        ],
      ),
    );
  }
}
