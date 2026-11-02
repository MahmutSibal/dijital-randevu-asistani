import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../core/form_dialog.dart';
import '../core/panel_shell.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../hospital_admin/hospital_admin_shell.dart' show AppointmentsTab;
import '../support/support_admin_tab.dart';
import 'security_tab.dart';
import '../theme/app_theme.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelShell(
      tabs: [
        PanelTab(
          icon: Icons.dashboard_rounded,
          label: 'Özet',
          page: _SummaryTab(),
        ),
        PanelTab(
          icon: Icons.support_agent_rounded,
          label: 'Destek',
          page: SupportAdminTab(),
        ),
        PanelTab(
          icon: Icons.local_hospital_rounded,
          label: 'Hastaneler',
          page: _HospitalsTab(),
        ),
        PanelTab(
          icon: Icons.groups_rounded,
          label: 'Hastalar',
          page: _PatientsTab(),
        ),
        PanelTab(
          icon: Icons.event_note_rounded,
          // Short enough for six tabs on a phone.
          label: 'Randevu',
          page: AppointmentsTab(
            title: 'Tüm Randevular',
            path: '/api/admin/appointments',
          ),
        ),
        PanelTab(
          icon: Icons.shield_rounded,
          label: 'Güvenlik',
          page: SecurityTab(),
        ),
      ],
    );
  }
}

class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async =>
      await SessionScope.read(context).api.get(
        '/api/admin/reports/appointment-summary',
        query: {'days': '30'},
      ) as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return PanelScaffold(
      title: 'Sistem Yönetimi',
      onSignOut: () => confirmSignOut(context),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _future = _load()),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 18),
                children: [
                  const TextSpan(text: 'Hoş geldiniz  '),
                  TextSpan(
                    text: session.email ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SON 30 GÜN',
              style: TextStyle(color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    '${snapshot.error}',
                    style: const TextStyle(color: AppColors.danger),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final s =
                    snapshot.data!['statusSummary'] as Map<String, dynamic>;
                final tiles = [
                  (
                    'Toplam',
                    s['total'],
                    Icons.event_note_rounded,
                    AppColors.primary,
                  ),
                  (
                    'Onay bekleyen',
                    s['pending'],
                    Icons.hourglass_top_rounded,
                    AppColors.warning,
                  ),
                  (
                    'Onaylanan',
                    s['approved'],
                    Icons.check_circle_rounded,
                    const Color(0xFF42A5F5),
                  ),
                  (
                    'Tamamlanan',
                    s['completed'],
                    Icons.done_all_rounded,
                    AppColors.success,
                  ),
                  (
                    'İptal',
                    s['cancelled'],
                    Icons.cancel_rounded,
                    AppColors.danger,
                  ),
                ];
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    for (final (label, value, icon, color) in tiles)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(icon, color: color, size: 30),
                              Text(
                                '$value',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HospitalsTab extends StatefulWidget {
  const _HospitalsTab();

  @override
  State<_HospitalsTab> createState() => _HospitalsTabState();
}

class _HospitalsTabState extends State<_HospitalsTab> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  Future<void> _add() async {
    final api = SessionScope.read(context).api;
    final values = await showFormDialog(
      context,
      title: 'YENİ HASTANE',
      fields: const [
        FormFieldSpec('name', 'Hastane adı'),
        FormFieldSpec('address', 'Adres', optional: true),
        FormFieldSpec(
          'type',
          'Tür',
          options: {'Public': 'Devlet Hastanesi', 'Private': 'Özel Hastane'},
        ),
      ],
    );
    if (values == null || !mounted) return;
    final address = values['address'] as String;
    final ok = await runWithFeedback(
      context,
      () => api.post('/api/admin/hospitals', {
        'name': values['name'],
        'address': address.isEmpty ? null : address,
        'latitude': null,
        'longitude': null,
        'type': values['type'],
      }),
      success: 'Hastane eklendi.',
    );
    if (ok) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Hastaneler',
      onSignOut: () => confirmSignOut(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Hastane Ekle'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Henüz hastane eklenmedi.',
        emptyIcon: Icons.local_hospital_outlined,
        load: () async => (await api.get('/api/admin/hospitals') as List)
            .cast<Map<String, dynamic>>(),
        itemBuilder: (context, h, _) => InfoTile(
          icon: Icons.local_hospital_rounded,
          color: AppColors.danger,
          title: h['name'] as String,
          subtitle: [
            h['type'] == 'Private' ? 'Özel Hastane' : 'Devlet Hastanesi',
            if (h['address'] != null) h['address'] as String,
          ].join(' · '),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primary,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _HospitalDetailScreen(hospital: h),
            ),
          ),
        ),
      ),
    );
  }
}

/// A hospital's managers ("hastane yöneticisi" accounts) with add and remove.
class _HospitalDetailScreen extends StatefulWidget {
  const _HospitalDetailScreen({required this.hospital});

  final Map<String, dynamic> hospital;

  @override
  State<_HospitalDetailScreen> createState() => _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends State<_HospitalDetailScreen> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  int get _id => widget.hospital['id'] as int;

  Future<void> _assign() async {
    final api = SessionScope.read(context).api;
    final values = await showFormDialog(
      context,
      title: 'HASTANE YÖNETİCİSİ',
      fields: const [
        FormFieldSpec(
          'email',
          'E-posta',
          keyboardType: TextInputType.emailAddress,
        ),
        FormFieldSpec('password', 'Şifre', obscure: true, minLength: 8),
      ],
    );
    if (values == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => api.post('/api/admin/hospitals/$_id/assign-subadmin', values),
      success: 'Yönetici eklendi. Bu e-posta ve şifreyle "Hastane" girişini kullanabilir.',
    );
    if (ok) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: Text(widget.hospital['name'] as String)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _assign,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Yönetici Ekle'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Bu hastanenin yöneticisi yok.\nYönetici ekleyerek hastane panelini açın.',
        emptyIcon: Icons.manage_accounts_outlined,
        load: () async =>
            (await api.get('/api/admin/hospitals/$_id/subadmins') as List)
                .cast<Map<String, dynamic>>(),
        itemBuilder: (context, s, reload) {
          final userId = s['userId'] ?? s['id'];
          return InfoTile(
            icon: Icons.manage_accounts_rounded,
            color: AppColors.primary,
            title: s['email'] as String? ?? '',
            subtitle: 'Hastane yöneticisi',
            trailing: IconButton(
              tooltip: 'Kaldır',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () async {
                if (!await confirm(
                  context,
                  'UYARI',
                  'Bu yönetici kaldırılacak. Emin misiniz?',
                )) {
                  return;
                }
                if (!context.mounted) return;
                final ok = await runWithFeedback(
                  context,
                  () =>
                      api.delete('/api/admin/hospitals/$_id/subadmins/$userId'),
                  success: 'Yönetici kaldırıldı.',
                );
                if (ok) reload();
              },
            ),
          );
        },
      ),
    );
  }
}

class _PatientsTab extends StatelessWidget {
  const _PatientsTab();

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Hastalar',
      onSignOut: () => confirmSignOut(context),
      body: AsyncList<Map<String, dynamic>>(
        emptyText: 'Kayıtlı hasta yok.',
        emptyIcon: Icons.groups_outlined,
        load: () async => (await api.get('/api/admin/patients') as List)
            .cast<Map<String, dynamic>>(),
        itemBuilder: (context, p, _) => InfoTile(
          icon: Icons.person_rounded,
          color: const Color(0xFF42A5F5),
          title: '${p['firstName']} ${p['lastName']}',
          subtitle: p['phone'] as String?,
        ),
      ),
    );
  }
}
