import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../core/form_dialog.dart';
import '../core/panel_shell.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../support/support_admin_tab.dart';
import '../theme/app_theme.dart';

class HospitalAdminShell extends StatelessWidget {
  const HospitalAdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelShell(
      tabs: [
        PanelTab(
          icon: Icons.medical_services_rounded,
          label: 'Doktorlar',
          page: _DoctorsTab(),
        ),
        PanelTab(
          icon: Icons.category_rounded,
          label: 'Bölümler',
          page: _DepartmentsTab(),
        ),
        PanelTab(
          icon: Icons.event_note_rounded,
          label: 'Randevular',
          page: AppointmentsTab(
            title: 'Hastane Randevuları',
            path: '/api/hospital/appointments',
          ),
        ),
        PanelTab(
          icon: Icons.verified_rounded,
          label: 'Onaylar',
          page: _ApprovalsTab(),
        ),
        PanelTab(
          icon: Icons.support_agent_rounded,
          label: 'Destek',
          page: SupportAdminTab(),
        ),
      ],
    );
  }
}

class _DoctorsTab extends StatefulWidget {
  const _DoctorsTab();

  @override
  State<_DoctorsTab> createState() => _DoctorsTabState();
}

class _DoctorsTabState extends State<_DoctorsTab> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  Future<void> _add() async {
    final api = SessionScope.read(context).api;
    final departments = await _loadDepartments(context);
    if (departments == null || !mounted) return;
    if (departments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce Bölümler sekmesinden bir bölüm ekleyin.'),
        ),
      );
      return;
    }
    final values = await showFormDialog(
      context,
      title: 'YENİ DOKTOR',
      fields: [
        const FormFieldSpec('title', 'Unvan (ör. Uzm. Dr.)'),
        const FormFieldSpec('name', 'Ad Soyad'),
        FormFieldSpec(
          'departmentId',
          'Bölüm',
          options: {
            for (final d in departments) d['id'] as int: d['name'] as String,
          },
        ),
        const FormFieldSpec(
          'email',
          'Giriş e-postası',
          keyboardType: TextInputType.emailAddress,
        ),
        const FormFieldSpec(
          'password',
          'Giriş şifresi',
          obscure: true,
          minLength: 8,
        ),
      ],
    );
    if (values == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => api.post('/api/hospitaladmin/doctors', {...values, 'userId': null}),
      success: 'Doktor eklendi. Doktor bu e-posta ve şifreyle giriş yapabilir.',
    );
    if (ok) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Doktorlar',
      onSignOut: () => confirmSignOut(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Doktor Ekle'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Henüz doktor eklenmedi.',
        emptyIcon: Icons.medical_services_outlined,
        load: () async => (await api.get('/api/hospitaladmin/doctors') as List)
            .cast<Map<String, dynamic>>(),
        itemBuilder: (context, d, reload) => InfoTile(
          icon: Icons.medical_services_rounded,
          color: d['isActive'] == false
              ? AppColors.textMuted
              : AppColors.success,
          title: '${d['title']} ${d['name']}',
          subtitle: d['departmentName'] as String?,
          trailing: IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              if (!await confirm(
                context,
                'UYARI',
                '${d['name']} silinecek. Emin misiniz?',
              )) {
                return;
              }
              if (!context.mounted) return;
              final ok = await runWithFeedback(
                context,
                () => api.delete('/api/hospitaladmin/doctors/${d['id']}'),
                success: 'Doktor silindi.',
              );
              if (ok) reload();
            },
          ),
        ),
      ),
    );
  }
}

Future<List<Map<String, dynamic>>?> _loadDepartments(
  BuildContext context,
) async {
  final api = SessionScope.read(context).api;
  try {
    return (await api.get('/api/hospitaladmin/departments') as List)
        .cast<Map<String, dynamic>>();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return null;
  }
}

class _DepartmentsTab extends StatefulWidget {
  const _DepartmentsTab();

  @override
  State<_DepartmentsTab> createState() => _DepartmentsTabState();
}

class _DepartmentsTabState extends State<_DepartmentsTab> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  Future<void> _add() async {
    final api = SessionScope.read(context).api;
    final values = await showFormDialog(
      context,
      title: 'YENİ BÖLÜM',
      fields: const [FormFieldSpec('name', 'Bölüm adı (ör. Kardiyoloji)')],
    );
    if (values == null || !mounted) return;
    final ok = await runWithFeedback(
      context,
      () => api.post('/api/hospitaladmin/departments', values),
      success: 'Bölüm eklendi.',
    );
    if (ok) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Bölümler',
      onSignOut: () => confirmSignOut(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Bölüm Ekle'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Henüz bölüm eklenmedi.',
        emptyIcon: Icons.category_outlined,
        load: () async =>
            (await api.get('/api/hospitaladmin/departments') as List)
                .cast<Map<String, dynamic>>(),
        itemBuilder: (context, d, reload) => InfoTile(
          icon: Icons.category_rounded,
          color: AppColors.primary,
          title: d['name'] as String,
          trailing: IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              if (!await confirm(
                context,
                'UYARI',
                '${d['name']} bölümü silinecek. Emin misiniz?',
              )) {
                return;
              }
              if (!context.mounted) return;
              final ok = await runWithFeedback(
                context,
                () => api.delete('/api/hospitaladmin/departments/${d['id']}'),
                success: 'Bölüm silindi.',
              );
              if (ok) reload();
            },
          ),
        ),
      ),
    );
  }
}

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab();

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Profil Onayları',
      onSignOut: () => confirmSignOut(context),
      body: AsyncList<Map<String, dynamic>>(
        emptyText: 'Onay bekleyen doktor profili yok.',
        emptyIcon: Icons.verified_outlined,
        load: () async => (await api.get(
          '/api/hospitaladmin/doctor-profiles/pending',
        ) as List).cast<Map<String, dynamic>>(),
        itemBuilder: (context, p, reload) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p['doctorTitle']} ${p['doctorName']}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  p['departmentName'] as String? ?? '',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Text('Üniversite: ${p['graduationUniversity']}'),
                const SizedBox(height: 4),
                Text(
                  p['experienceSummary'] as String? ?? '',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.verified),
                    label: const Text('ONAYLA'),
                    onPressed: () async {
                      final ok = await runWithFeedback(
                        context,
                        () => api.post(
                          '/api/hospitaladmin/doctor-profiles/${p['doctorId']}/approve',
                        ),
                        success: 'Profil onaylandı.',
                      );
                      if (ok) reload();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only list of appointments (AdminAppointmentDto), used by both admin panels.
class AppointmentsTab extends StatelessWidget {
  const AppointmentsTab({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: title,
      onSignOut: () => confirmSignOut(context),
      body: AsyncList<Map<String, dynamic>>(
        emptyText: 'Kayıtlı randevu yok.',
        emptyIcon: Icons.event_busy_rounded,
        load: () async {
          final items = (await api.get(path) as List)
              .cast<Map<String, dynamic>>();
          items.sort(
            (a, b) => (b['appointmentDateUtc'] as String).compareTo(
              a['appointmentDateUtc'] as String,
            ),
          );
          return items;
        },
        itemBuilder: (context, a, _) => InfoTile(
          icon: Icons.event_rounded,
          color: AppColors.warning,
          title: formatDateTime(a['appointmentDateUtc'] as String),
          subtitle:
              '${a['doctorName']} · ${a['departmentName']}\n${a['userEmail']}',
          trailing: StatusChip(a['status'] as String),
        ),
      ),
    );
  }
}
