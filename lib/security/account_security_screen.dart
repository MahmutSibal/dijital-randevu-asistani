import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'data_export_pdf.dart';
import 'kvkk_screen.dart';
import 'login_history_screen.dart';

/// Two-step sign-in, active sessions and the KVKK data rights in one place.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late final Session _session = SessionScope.read(context);
  Map<String, dynamic>? _twoFactor;
  List<Map<String, dynamic>>? _sessions;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _session.api.get('/api/account/two-factor'),
        _session.api.get('/api/account/sessions'),
      ]);
      if (!mounted) return;
      setState(() {
        _twoFactor = results[0] as Map<String, dynamic>;
        _sessions = (results[1] as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setTwoFactor(bool on) => _run(() async {
    final j = await _session.api.put('/api/account/two-factor', {
      'enabled': on,
    });
    setState(() => _twoFactor = j as Map<String, dynamic>);
    _toast(
      on
          ? 'İki adımlı doğrulama açıldı. Bir sonraki girişte telefonunuza kod gönderilecek.'
          : 'İki adımlı doğrulama kapatıldı.',
    );
  });

  Future<void> _endSession(Map<String, dynamic> s) async {
    if (!await confirm(
      context,
      'OTURUMU KAPAT',
      '${s['device'] ?? 'Bilinmeyen cihaz'} üzerindeki oturum kapatılacak.',
    )) {
      return;
    }
    await _run(() async {
      await _session.api.delete('/api/account/sessions/${s['id']}');
      await _load();
      _toast('Oturum kapatıldı.');
    });
  }

  Future<void> _endOthers() async {
    if (!await confirm(
      context,
      'DİĞER OTURUMLAR',
      'Bu cihaz dışındaki tüm cihazlarda oturumunuz kapatılacak.',
    )) {
      return;
    }
    await _run(() async {
      final j = await _session.api.post('/api/account/sessions/end-others');
      await _load();
      _toast('${(j as Map)['ended']} oturum kapatıldı.');
    });
  }

  Future<void> _export() => _run(() async {
    final data = await _session.api.get('/api/account/export');
    await Printing.sharePdf(
      bytes: await buildDataExportPdf(data as Map<String, dynamic>),
      filename: 'kisisel-verilerim.pdf',
    );
  });

  Future<void> _requestDeletion() async {
    if (!await confirm(
      context,
      'HESAP SİLME TALEBİ',
      'Hesabınızın ve kişisel verilerinizin silinmesi için talep oluşturulacak. '
          'Talebiniz yetkililer tarafından incelenip sonuçlandırılır.',
      ok: 'TALEP OLUŞTUR',
    )) {
      return;
    }
    await _run(() async {
      final j = await _session.api.post('/api/account/deletion-request');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const TintedIcon(
            Icons.mark_email_read_rounded,
            color: AppColors.success,
            size: 64,
          ),
          title: const Text('Talebiniz alındı', textAlign: TextAlign.center),
          content: Text(
            'Talep numaranız: ${(j as Map)['ticketNo']}\n\n'
            'Durumunu Destek Talebi ekranından bu numarayla takip edebilirsiniz.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final twoFactorOn = _twoFactor?['enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap Güvenliği')),
      body: _error != null
          ? MessageView(
              icon: Icons.cloud_off_rounded,
              text: _error!,
              action: OutlinedButton(
                onPressed: _load,
                child: const Text('Tekrar dene'),
              ),
            )
          : _sessions == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _ScoreCard(
                    twoFactor: twoFactorOn,
                    sessions: _sessions!.length,
                  ),
                  if (_busy) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 20),
                  const SectionHeader('Giriş güvenliği'),
                  Card(
                    child: SwitchListTile(
                      value: twoFactorOn,
                      onChanged: _busy ? null : _setTwoFactor,
                      secondary: const TintedIcon(
                        Icons.phonelink_lock_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                      title: const Text(
                        'İki adımlı doğrulama',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _twoFactor?['maskedPhone'] == null
                            ? 'Şifrenizden sonra telefonunuza kod gelir.'
                            : 'Şifrenizden sonra ${_twoFactor!['maskedPhone']} numarasına kod gelir.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  _LinkTile(
                    icon: Icons.history_rounded,
                    color: AppColors.success,
                    title: 'Giriş Geçmişim',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginHistoryScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    'Aktif oturumlar (${_sessions!.length})',
                    action: _sessions!.length > 1 ? 'Diğerlerini kapat' : null,
                    onAction: _busy ? null : _endOthers,
                  ),
                  for (final s in _sessions!)
                    _SessionTile(
                      session: s,
                      onEnd: s['isCurrent'] == true || _busy
                          ? null
                          : () => _endSession(s),
                    ),
                  const SizedBox(height: 20),
                  const SectionHeader('Kişisel verilerim (KVKK)'),
                  _LinkTile(
                    icon: Icons.privacy_tip_rounded,
                    color: AppColors.cyan,
                    title: 'Aydınlatma metni',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KvkkScreen()),
                    ),
                  ),
                  _LinkTile(
                    icon: Icons.download_rounded,
                    color: AppColors.indigo,
                    title: 'Verilerimi indir (PDF)',
                    subtitle:
                        'Kimlik, sağlık profili, randevu ve giriş kayıtlarınız',
                    onTap: _busy ? null : _export,
                  ),
                  _LinkTile(
                    icon: Icons.person_remove_rounded,
                    color: AppColors.danger,
                    title: 'Hesabımın silinmesini talep et',
                    subtitle: 'Talep, destek ekibine iletilir',
                    onTap: _busy ? null : _requestDeletion,
                  ),
                ],
              ),
            ),
    );
  }
}

/// A rough "how protected is this account" meter for the header.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.twoFactor, required this.sessions});

  final bool twoFactor;
  final int sessions;

  @override
  Widget build(BuildContext context) {
    final score = 50 + (twoFactor ? 35 : 0) + (sessions <= 2 ? 15 : 0);
    final (label, color) = score >= 85
        ? ('Güçlü', AppColors.success)
        : score >= 65
        ? ('İyi', AppColors.warning)
        : ('Geliştirilebilir', AppColors.danger);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 7,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
                Center(
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hesap güvenliği',
                  style: TextStyle(color: Colors.white70),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  twoFactor
                      ? 'İki adımlı doğrulama açık.'
                      : 'İki adımlı doğrulamayı açarak hesabınızı koruyun.',
                  style: TextStyle(
                    color: twoFactor ? Colors.white : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onEnd});

  final Map<String, dynamic> session;
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final current = session['isCurrent'] == true;
    final device = session['device'] as String? ?? 'Bilinmeyen cihaz';
    final mobile = device.toLowerCase().contains('mobil');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: TintedIcon(
          mobile ? Icons.smartphone_rounded : Icons.computer_rounded,
          color: current ? AppColors.success : AppColors.primary,
          size: 40,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                device,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (current) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Bu cihaz',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Son etkinlik: ${formatDateTime(session['lastActiveAtUtc'] as String)}'
          '${session['ipAddress'] == null ? '' : '\nIP ${session['ipAddress']}'}',
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        trailing: current
            ? null
            : IconButton(
                tooltip: 'Oturumu kapat',
                icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                onPressed: onEnd,
              ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: onTap,
        leading: TintedIcon(icon, color: color, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(color: AppColors.textMuted),
              ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
