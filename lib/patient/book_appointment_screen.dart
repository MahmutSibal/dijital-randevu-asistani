import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'doctor_rating_card.dart';
import 'slot_picker.dart';

/// Patient (or one of their dependents) → hospital → department → doctor → day → free
/// slot → book. Full slots offer the waitlist. Pops `true` once booked.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  late final ApiClient _api = SessionScope.read(context).api;

  List<Map<String, dynamic>>? _hospitals;
  List<Map<String, dynamic>>? _departments;
  List<Map<String, dynamic>>? _doctors;

  /// Doctor id → {average, count} from patients' reviews.
  Map<String, dynamic> _ratings = {};
  List<Map<String, dynamic>> _dependents = const [];

  int? _hospitalId;
  int? _departmentId;
  int? _doctorId;
  int? _dependentId; // null = for the patient themself
  PickedSlot? _slot;

  bool _loading = false;
  bool _booking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(() async => _hospitals = await _fetch('/api/catalog/hospitals'));
    _fetch('/api/patient/dependents/me')
        .then((d) => mounted ? setState(() => _dependents = d) : null)
        .catchError(
          (_) => null,
        ); // Booking for oneself still works without them.
  }

  Future<List<Map<String, dynamic>>> _fetch(
    String path, [
    Map<String, String>? query,
  ]) async =>
      (await _api.get(path, query: query) as List).cast<Map<String, dynamic>>();

  Future<void> _load(Future<void> Function() step) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await step();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectHospital(int? id) {
    setState(() {
      _hospitalId = id;
      _departmentId = _doctorId = null;
      _departments = _doctors = null;
      _slot = null;
    });
    if (id != null) {
      _load(
        () async => _departments = await _fetch('/api/catalog/departments', {
          'hospitalId': '$id',
        }),
      );
    }
  }

  void _selectDepartment(int? id) {
    setState(() {
      _departmentId = id;
      _doctorId = null;
      _doctors = null;
      _slot = null;
    });
    if (id != null) {
      _load(() async {
        final results = await Future.wait([
          _fetch('/api/catalog/doctors', {'departmentId': '$id'}),
          _api.get('/api/reviews/doctors/averages'),
        ]);
        _doctors = results[0] as List<Map<String, dynamic>>;
        _ratings = (results[1] as Map).cast<String, dynamic>();
      });
    }
  }

  Future<void> _joinWaitlist(PickedSlot slot) async {
    if (!await confirm(
      context,
      'BEKLEME LİSTESİ',
      '${slot.label} saati dolu. Bu saat boşalırsa size bildirim gönderilsin mi?',
      ok: 'KATIL',
    )) {
      return;
    }
    if (!mounted) return;
    await runWithFeedback(
      context,
      () => _api.post('/api/waitlist/join', {
        'doctorId': _doctorId,
        'startAtUtc': slot.iso,
      }),
      success:
          'Bekleme listesine eklendiniz. Yer açılınca bildirim alacaksınız.',
    );
  }

  Future<void> _book() async {
    setState(() => _booking = true);
    final ok = await runWithFeedback(
      context,
      () => _api.post('/api/appointments', {
        'doctorId': _doctorId,
        'appointmentDate': _slot!.iso,
        'dependentId': _dependentId,
      }),
      success: 'Randevunuz oluşturuldu.',
    );
    if (!mounted) return;
    setState(() => _booking = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu Al')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_dependents.isNotEmpty)
            _Dropdown(
              label: 'Kimin için?',
              icon: Icons.person_rounded,
              items: [
                {'id': 0, 'name': 'Kendim'},
                for (final d in _dependents)
                  {'id': d['id'], 'name': d['fullName']},
              ],
              value: _dependentId ?? 0,
              onChanged: (id) =>
                  setState(() => _dependentId = id == 0 ? null : id),
            ),
          _Dropdown(
            label: 'Hastane',
            icon: Icons.local_hospital_rounded,
            items: _hospitals,
            value: _hospitalId,
            onChanged: _selectHospital,
          ),
          if (_hospitalId != null)
            _Dropdown(
              label: 'Bölüm',
              icon: Icons.category_rounded,
              items: _departments,
              value: _departmentId,
              onChanged: _selectDepartment,
            ),
          if (_departmentId != null)
            _Dropdown(
              label: 'Doktor',
              icon: Icons.medical_services_rounded,
              items: _doctors?.where((d) => d['isActive'] != false).toList(),
              value: _doctorId,
              onChanged: (id) => setState(() {
                _doctorId = id;
                _slot = null;
              }),
              itemLabel: (d) {
                final r = _ratings['${d['id']}'] as Map?;
                final name = '${d['title']} ${d['name']}'.trim();
                return r == null
                    ? name
                    : '$name  ★ ${r['average']} (${r['count']})';
              },
            ),
          if (_doctorId != null) ...[
            DoctorRatingCard(doctorId: _doctorId!),
            const SizedBox(height: 4),
            SlotPicker(
              doctorId: _doctorId!,
              onChanged: (s) => setState(() => _slot = s),
              onFullSlot: _joinWaitlist,
            ),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          if (_hospitals != null && _hospitals!.isEmpty)
            const MessageView(
              icon: Icons.local_hospital_outlined,
              text: 'Henüz kayıtlı hastane yok.',
            ),
          const SizedBox(height: 24),
          if (_slot != null)
            _booking
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Randevuyu Onayla (${_slot!.label})',
                    icon: Icons.check_rounded,
                    onPressed: _book,
                  ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final IconData icon;
  final List<Map<String, dynamic>>? items;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String Function(Map<String, dynamic>)? itemLabel;

  @override
  Widget build(BuildContext context) {
    final list = items ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        dropdownColor: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.field),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        hint: Text(
          items == null
              ? 'Yükleniyor…'
              : (list.isEmpty ? 'Kayıt yok' : 'Seçiniz'),
        ),
        items: [
          for (final item in list)
            DropdownMenuItem(
              value: item['id'] as int,
              child: Text(
                itemLabel?.call(item) ?? item['name'] as String,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: list.isEmpty ? null : onChanged,
      ),
    );
  }
}
