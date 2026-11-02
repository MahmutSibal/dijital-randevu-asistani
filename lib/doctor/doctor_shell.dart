import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../chat/chat_screen.dart';
import '../core/api_client.dart';
import '../core/panel_shell.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'doctor_appointments_tab.dart';
import 'doctor_today_tab.dart';

class DoctorShell extends StatelessWidget {
  const DoctorShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelShell(
      tabs: [
        PanelTab(
          icon: Icons.today_rounded,
          label: 'Bugün',
          page: DoctorTodayTab(),
        ),
        PanelTab(
          icon: Icons.event_note_rounded,
          label: 'Randevular',
          page: DoctorAppointmentsTab(),
        ),
        PanelTab(
          icon: Icons.schedule_rounded,
          label: 'Saatlerim',
          page: _AvailabilityTab(),
        ),
        PanelTab(
          icon: Icons.chat_bubble_rounded,
          label: 'Asistan',
          page: ChatScreen(),
        ),
        PanelTab(
          icon: Icons.person_rounded,
          label: 'Profilim',
          page: _ProfileTab(),
        ),
      ],
    );
  }
}

class _AvailabilityTab extends StatefulWidget {
  const _AvailabilityTab();

  @override
  State<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends State<_AvailabilityTab> {
  late final ApiClient _api = SessionScope.read(context).api;
  TimeOfDay? _workStart, _workEnd, _lunchStart, _lunchEnd;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static TimeOfDay? _parse(Object? v) {
    if (v is! String || !v.contains(':')) return null;
    final p = v.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  static String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a =
          await _api.get('/api/doctor/availability/me') as Map<String, dynamic>;
      _workStart = _parse(a['workStart']);
      _workEnd = _parse(a['workEnd']);
      _lunchStart = _parse(a['lunchStart']);
      _lunchEnd = _parse(a['lunchEnd']);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => _api.put('/api/doctor/availability/me', {
        'workStart': _fmt(_workStart),
        'workEnd': _fmt(_workEnd),
        'lunchStart': _fmt(_lunchStart),
        'lunchEnd': _fmt(_lunchEnd),
        'slotMinutes': 30,
      }),
      success: 'Çalışma saatleri kaydedildi.',
    );
    if (mounted) setState(() => _saving = false);
  }

  Widget _timeField(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay?> onChanged, {
    bool clearable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (picked != null) setState(() => onChanged(picked));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.access_time_rounded),
            suffixIcon: clearable && value != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => onChanged(null)),
                  )
                : null,
          ),
          child: Text(
            _fmt(value) ?? 'Yok',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PanelScaffold(
      title: 'Çalışma Saatlerim',
      onSignOut: () => confirmSignOut(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? MessageView(
              icon: Icons.error_outline,
              text: _error!,
              action: FilledButton(
                onPressed: _load,
                child: const Text('TEKRAR DENE'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Hastalar bu saatler arasındaki 30 dakikalık dilimlerden randevu alabilir.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 20),
                _timeField(
                  'Mesai başlangıcı',
                  _workStart,
                  (v) => _workStart = v,
                ),
                _timeField('Mesai bitişi', _workEnd, (v) => _workEnd = v),
                _timeField(
                  'Öğle arası başlangıcı',
                  _lunchStart,
                  (v) => _lunchStart = v,
                  clearable: true,
                ),
                _timeField(
                  'Öğle arası bitişi',
                  _lunchEnd,
                  (v) => _lunchEnd = v,
                  clearable: true,
                ),
                const SizedBox(height: 16),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : GradientButton(label: 'Kaydet', onPressed: _save),
              ],
            ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final ApiClient _api = SessionScope.read(context).api;
  final _university = TextEditingController();
  final _experience = TextEditingController();
  Map<String, dynamic>? _profile;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _university.dispose();
    _experience.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p =
          await _api.get('/api/doctor/profile/me') as Map<String, dynamic>;
      _university.text = p['graduationUniversity'] as String? ?? '';
      _experience.text = p['experienceSummary'] as String? ?? '';
      setState(() {
        _profile = p;
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runWithFeedback(
      context,
      () => _api.put('/api/doctor/profile/me', {
        'graduationUniversity': _university.text.trim(),
        'experienceSummary': _experience.text.trim(),
      }),
      success: 'Profil onaya gönderildi.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final status = _profile?['profileStatus'] as String?;
    final (statusText, statusColor) = switch (status) {
      'Approved' => ('Profiliniz onaylandı.', AppColors.success),
      'Pending' || 'Submitted' => (
        'Profiliniz hastane yönetiminin onayını bekliyor.',
        AppColors.warning,
      ),
      _ => ('Profilinizi doldurup onaya gönderin.', AppColors.textMuted),
    };

    return PanelScaffold(
      title: 'Profilim',
      onSignOut: () => confirmSignOut(context),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.email ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Doktor',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  if (_profile != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.danger))
          else if (_profile == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            TextField(
              controller: _university,
              decoration: const InputDecoration(
                labelText: 'Mezun olunan üniversite',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _experience,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Deneyim özeti'),
            ),
            const SizedBox(height: 20),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(label: 'Onaya Gönder', onPressed: _save),
          ],
        ],
      ),
    );
  }
}
