import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// The user's recent sign-ins and failed attempts, newest first.
class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  late Future<Map<String, dynamic>?> _data = _load();

  Future<Map<String, dynamic>?> _load() =>
      SessionScope.read(context).loadAccountSecurity();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş Geçmişim')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final s = snap.data;
          if (s == null) {
            return MessageView(
              icon: Icons.cloud_off_rounded,
              text: 'Giriş geçmişi yüklenemedi.',
              action: OutlinedButton(
                onPressed: () => setState(() => _data = _load()),
                child: const Text('Tekrar dene'),
              ),
            );
          }
          final history = (s['history'] as List).cast<Map<String, dynamic>>();
          final previous = s['previousLogin'] as Map<String, dynamic>?;
          final failed = s['lastFailedLogin'] as Map<String, dynamic>?;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _data = _load());
              await _data;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Summary(
                        icon: Icons.login_rounded,
                        color: AppColors.success,
                        label: 'Önceki başarılı giriş',
                        value: previous == null
                            ? 'Kayıt yok'
                            : formatDateTime(previous['atUtc'] as String),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Summary(
                        icon: Icons.gpp_maybe_rounded,
                        color: AppColors.danger,
                        label: 'Son başarısız deneme',
                        value: failed == null
                            ? 'Kayıt yok'
                            : formatDateTime(failed['atUtc'] as String),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tanımadığınız bir giriş görürseniz şifrenizi hemen değiştirin. '
                          'Art arda 5 hatalı denemede hesabınız 15 dakika kilitlenir.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader('Son 20 giriş'),
                for (final e in history) _EventTile(e),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TintedIcon(icon, color: color, size: 38),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.e);

  final Map<String, dynamic> e;

  @override
  Widget build(BuildContext context) {
    final ok = e['success'] == true;
    final color = ok ? AppColors.success : AppColors.danger;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: TintedIcon(
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: color,
          size: 40,
        ),
        title: Text(
          ok ? 'Başarılı giriş' : 'Hatalı şifre denemesi',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            formatDateTime(e['atUtc'] as String),
            if (e['device'] != null) e['device'] as String,
            if (e['ipAddress'] != null) 'IP ${e['ipAddress']}',
          ].join('\n'),
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        isThreeLine: true,
      ),
    );
  }
}
