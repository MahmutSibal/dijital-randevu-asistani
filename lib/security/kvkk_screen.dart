import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

const _sections = [
  (
    Icons.business_rounded,
    'Veri sorumlusu',
    'Kişisel verileriniz, 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında '
        'veri sorumlusu sıfatıyla Dijital Randevu Asistanı tarafından işlenmektedir.',
  ),
  (
    Icons.badge_rounded,
    'İşlenen kişisel veriler',
    'Kimlik (ad, soyad, T.C. kimlik numarası, doğum tarihi), iletişim (telefon), '
        'sağlık (randevu bilgileri ve sağlık profilinize kendi girdiğiniz kan grubu, '
        'alerji, kronik hastalık ve ilaç bilgileri) ile işlem güvenliği (giriş kayıtları, '
        'IP adresi, cihaz bilgisi) verileriniz işlenir.',
  ),
  (
    Icons.flag_rounded,
    'İşleme amaçları',
    'Randevu oluşturma, erteleme ve iptal; randevu hatırlatmaları ve bildirimler; '
        'yakınlarınız adına işlem yapılabilmesi; destek taleplerinin yanıtlanması; '
        'hesap güvenliğinin sağlanması ve yasal yükümlülüklerin yerine getirilmesi.',
  ),
  (
    Icons.share_rounded,
    'Aktarım',
    'Randevu bilgileriniz yalnızca randevu aldığınız hastane ve hekimle paylaşılır. '
        'Verileriniz, kanunen yetkili kurumların talepleri dışında üçüncü kişilere aktarılmaz.',
  ),
  (
    Icons.gavel_rounded,
    'Haklarınız (KVKK md. 11)',
    'Verilerinizin işlenip işlenmediğini öğrenme, bilgi talep etme, düzeltilmesini veya '
        'silinmesini isteme, aktarıldığı kişileri bilme ve zarara uğramanız hâlinde '
        'giderilmesini talep etme haklarına sahipsiniz. Başvurularınızı Destek Talebi '
        'ekranından iletebilirsiniz.',
  ),
];

/// KVKK disclosure. With [required] it blocks the app until the user accepts
/// (or signs out); otherwise it is a read-only page reached from the profile.
class KvkkScreen extends StatefulWidget {
  const KvkkScreen({super.key, this.required = false, this.acceptedAt});

  final bool required;
  final String? acceptedAt;

  @override
  State<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends State<KvkkScreen> {
  bool _read = false;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await SessionScope.read(context).acceptKvkk();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.required,
        title: const Text('KVKK Aydınlatma Metni'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.privacy_tip_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.required
                        ? 'Uygulamayı kullanmaya devam etmeden önce kişisel verilerinizin nasıl işlendiğini okuyup onaylamanız gerekiyor.'
                        : 'Kişisel verilerinizin nasıl işlendiğine dair bilgilendirme.',
                    style: const TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final (icon, title, body) in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TintedIcon(icon, color: AppColors.primary, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.acceptedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Onayladığınız tarih: ${widget.acceptedAt}',
                    style: const TextStyle(color: AppColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.required
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.navBar,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      value: _read,
                      onChanged: (v) => setState(() => _read = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Aydınlatma metnini okudum, kişisel verilerimin işlenmesine açık rıza veriyorum.',
                        style: TextStyle(fontSize: 13.5, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _busy
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(),
                          )
                        : GradientButton(
                            label: 'Onaylıyorum',
                            icon: Icons.check_circle_rounded,
                            onPressed: _read ? _accept : null,
                          ),
                    TextButton(
                      onPressed: () => SessionScope.read(context).signOut(),
                      child: const Text('Onaylamadan çıkış yap'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
