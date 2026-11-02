import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// "2026-10-27T09:30:00+03:00": [hhmm] on [day] in this device's local time, with its UTC offset.
String slotIso(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  final local = DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  final offset = local.timeZoneOffset;
  String two(int n) => n.abs().toString().padLeft(2, '0');
  final sign = offset.isNegative ? '-' : '+';
  return '${formatDate(local)}T${two(local.hour)}:${two(local.minute)}:00'
      '$sign${two(offset.inHours)}:${two(offset.inMinutes % 60)}';
}

String formatDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// A free slot the user picked: its ISO start time and the "HH:mm" label.
typedef PickedSlot = ({String iso, String label});

/// Day picker plus a doctor's 30-minute slots for that day. Reports the chosen free slot
/// through [onChanged]. Booked ("Dolu") slots call [onFullSlot] when given, e.g. to join
/// the waitlist.
class SlotPicker extends StatefulWidget {
  const SlotPicker({
    super.key,
    required this.doctorId,
    required this.onChanged,
    this.onFullSlot,
  });

  final int doctorId;
  final ValueChanged<PickedSlot?> onChanged;
  final ValueChanged<PickedSlot>? onFullSlot;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  late final ApiClient _api = SessionScope.read(context).api;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  List<Map<String, dynamic>>? _slots;
  String? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(notify: false);
  }

  @override
  void didUpdateWidget(SlotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent already cleared its selection when it picked another doctor.
    if (oldWidget.doctorId != widget.doctorId) _load(notify: false);
  }

  /// [notify] clears the parent's selection; not allowed while the parent is building.
  Future<void> _load({bool notify = true}) async {
    _slots = null;
    _selected = null;
    _error = null;
    if (mounted && notify) setState(() {});
    if (notify) widget.onChanged(null);
    try {
      final slots = (await _api.get(
        '/api/catalog/doctors/${widget.doctorId}/daily-slots',
        query: {'date': formatDate(_day)},
      ) as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _slots = slots);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Randevu günü',
    );
    if (picked == null) return;
    _day = picked;
    _load();
  }

  void _tap(Map<String, dynamic> s) {
    final label = s['startTime'] as String;
    final slot = (iso: slotIso(_day, label), label: label);
    if (s['isAvailable'] == true && !_isPast(label)) {
      setState(() => _selected = label);
      widget.onChanged(slot);
    } else if (s['unavailableReason'] == 'Dolu' && widget.onFullSlot != null) {
      widget.onFullSlot!(slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.field),
          onTap: _pickDay,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Gün',
              prefixIcon: Icon(Icons.calendar_month_rounded),
              suffixIcon: Icon(Icons.expand_more_rounded),
            ),
            child: Text(formatDay(_day), style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 18),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger))
        else if (slots == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (slots.isEmpty)
          const MessageView(
            icon: Icons.event_busy_rounded,
            text: 'Bu gün için uygun saat yok.',
          )
        else ...[
          const Text(
            'Saat seçin',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (widget.onFullSlot != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Dolu bir saate dokunarak bekleme listesine katılabilirsiniz.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in slots) _chip(s)],
          ),
        ],
      ],
    );
  }

  /// The API still lists today's earlier slots as available; they can't be booked.
  bool _isPast(String hhmm) {
    final parts = hhmm.split(':');
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    return !start.isAfter(DateTime.now());
  }

  Widget _chip(Map<String, dynamic> s) {
    final label = s['startTime'] as String;
    final free = s['isAvailable'] == true && !_isPast(label);
    final full = s['unavailableReason'] == 'Dolu';
    final selected = _selected == label;
    final tappable = free || (full && widget.onFullSlot != null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tappable ? () => _tap(s) : null,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.primary : null,
            color: selected
                ? null
                : free
                ? AppColors.surface
                : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : full
                  ? AppColors.warning.withValues(alpha: 0.35)
                  : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: free
                  ? Colors.white
                  : full
                  ? AppColors.warning
                  : AppColors.textMuted,
              decoration: free || full ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }
}
