import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// Admin "Güvenlik": sign-in activity overview and the audit log.
class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Güvenlik'),
          bottom: const TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Genel Bakış'),
              Tab(text: 'Denetim Kaydı'),
            ],
          ),
        ),
        body: const TabBarView(children: [_Overview(), _AuditLog()]),
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview();

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  late Future<Map<String, dynamic>> _data = _load();

  Future<Map<String, dynamic>> _load() async =>
      await SessionScope.read(context).api.get('/api/admin/security')
          as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snap) {
        if (snap.hasError) {
          return MessageView(
            icon: Icons.cloud_off_rounded,
            text: '${snap.error}',
            action: OutlinedButton(
              onPressed: () => setState(() => _data = _load()),
              child: const Text('Tekrar dene'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snap.data!;
        final locked = (s['lockedAccounts'] as List)
            .cast<Map<String, dynamic>>();
        final failures = (s['recentFailures'] as List)
            .cast<Map<String, dynamic>>();
        final byHour = (s['failedByHour'] as List).cast<int>();
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _data = _load());
            await _data;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _Stat(
                    icon: Icons.login_rounded,
                    color: AppColors.success,
                    label: 'Başarılı giriş (24 sa)',
                    value: '${s['successfulLogins24h']}',
                  ),
                  _Stat(
                    icon: Icons.gpp_maybe_rounded,
                    color: AppColors.danger,
                    label: 'Hatalı deneme (24 sa)',
                    value: '${s['failedLogins24h']}',
                  ),
                  _Stat(
                    icon: Icons.devices_rounded,
                    color: AppColors.primary,
                    label: 'Aktif oturum',
                    value: '${s['activeSessions']}',
                  ),
                  _Stat(
                    icon: Icons.phonelink_lock_rounded,
                    color: AppColors.cyan,
                    label: 'İki adımlı doğrulama',
                    value: '${s['twoFactorUsers']} kişi',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader('Hatalı denemeler (son 24 saat)'),
              _HourBars(values: byHour),
              const SizedBox(height: 20),
              SectionHeader('Kilitli hesaplar (${locked.length})'),
              if (locked.isEmpty)
                const _Empty('Şu an kilitli hesap yok.')
              else
                for (final l in locked)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const TintedIcon(
                        Icons.lock_clock_rounded,
                        color: AppColors.danger,
                        size: 40,
                      ),
                      title: Text(
                        l['account'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${l['failedCount']} hatalı deneme · ${formatDateTime(l['lockedUntilUtc'] as String)} saatine kadar'
                        '${l['lastIpAddress'] == null ? '' : '\nIP ${l['lastIpAddress']}'}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              const SectionHeader('Son hatalı denemeler'),
              if (failures.isEmpty)
                const _Empty('Kayıt yok.')
              else
                for (final f in failures)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const TintedIcon(
                        Icons.cancel_rounded,
                        color: AppColors.danger,
                        size: 40,
                      ),
                      title: Text(
                        '${f['userLabel'] ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          formatDateTime(f['atUtc'] as String),
                          if (f['role'] != null)
                            _roleLabel(f['role'] as String),
                          if (f['device'] != null) f['device'] as String,
                          if (f['ipAddress'] != null) 'IP ${f['ipAddress']}',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

String _roleLabel(String role) => UserRole.fromApi(role)?.label ?? role;

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TintedIcon(icon, color: color, size: 34),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// 24 bars, oldest hour on the left.
class _HourBars extends StatelessWidget {
  const _HourBars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (m, v) => v > m ? v : m);
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in values)
                  Expanded(
                    child: Tooltip(
                      message: '$v hatalı deneme',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: max == 0 ? 2 : 2 + 90 * v / max,
                        decoration: BoxDecoration(
                          color: v == 0
                              ? AppColors.surfaceHigh
                              : AppColors.danger.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '24 sa önce',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                '12 sa önce',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                'Şimdi',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
  );
}

class _AuditLog extends StatefulWidget {
  const _AuditLog();

  @override
  State<_AuditLog> createState() => _AuditLogState();
}

class _AuditLogState extends State<_AuditLog> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();
  String? _action;

  static const _actions = {
    null: 'Tümü',
    'Created': 'Ekleme',
    'Updated': 'Güncelleme',
    'Deleted': 'Silme',
  };

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            children: [
              for (final e in _actions.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _action == e.key,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _action = e.key);
                      _list.currentState?.reload();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncList<Map<String, dynamic>>(
            key: _list,
            emptyText: 'Kayıt yok.',
            emptyIcon: Icons.fact_check_rounded,
            load: () async => (await api.get(
              '/api/admin/audit-logs',
              query: {'take': '100', 'action': ?_action},
            ) as List).cast<Map<String, dynamic>>(),
            itemBuilder: (context, l, _) {
              final action = l['action'] as String;
              final (icon, color) = switch (action) {
                'Created' => (Icons.add_circle_rounded, AppColors.success),
                'Deleted' => (Icons.delete_rounded, AppColors.danger),
                _ => (Icons.edit_rounded, AppColors.warning),
              };
              return Card(
                child: ListTile(
                  leading: TintedIcon(icon, color: color, size: 40),
                  title: Text(
                    '${l['entity']} · ${_actions[action] ?? action}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      formatDateTime(l['timestampUtc'] as String),
                      if ((l['role'] as String?)?.isNotEmpty == true)
                        _roleLabel(l['role'] as String),
                      if (l['ipAddress'] != null) 'IP ${l['ipAddress']}',
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
