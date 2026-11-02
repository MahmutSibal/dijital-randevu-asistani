import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/sign_out.dart';
import '../core/session.dart';
import '../patient/patient_nav.dart';
import '../theme/app_theme.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return session.isSignedIn
        ? _SignedInProfile(session: session)
        : const _SignedOutProfile();
  }
}

class _SignedOutProfile extends StatelessWidget {
  const _SignedOutProfile();

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Center(child: AppLogo(large: true)),
            const SizedBox(height: 48),
            const Center(
              child: Text(
                'Merhaba',
                style: TextStyle(fontSize: 30, color: Colors.white),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Randevularınız için giriş yapın',
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Giriş Yap',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text(
                  'Hesap Oluştur',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'PERSONEL GİRİŞİ',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (role, icon, color, label) in const [
                  (
                    UserRole.doctor,
                    Icons.medical_services_rounded,
                    AppColors.success,
                    'Doktor',
                  ),
                  (
                    UserRole.hospitalAdmin,
                    Icons.local_hospital_rounded,
                    AppColors.danger,
                    'Hastane',
                  ),
                  (
                    UserRole.admin,
                    Icons.admin_panel_settings_rounded,
                    AppColors.warning,
                    'Admin',
                  ),
                ])
                  Expanded(
                    child: QuickAction(
                      icon: icon,
                      color: color,
                      label: label,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(initialRole: role),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInProfile extends StatelessWidget {
  const _SignedInProfile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () => confirmSignOut(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (session.displayName ?? '?').characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.displayName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              session.role?.label ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Oturum açık',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              _ProfileTile(
                icon: Icons.event_note_rounded,
                color: AppColors.warning,
                label: 'Randevularım',
                onTap: () => openMyAppointments(context),
              ),
              _ProfileTile(
                icon: Icons.monitor_heart_rounded,
                color: const Color(0xFFFF7043),
                label: 'Sağlık Profilim',
                onTap: () => openHealthProfile(context),
              ),
              _ProfileTile(
                icon: Icons.family_restroom_rounded,
                color: const Color(0xFFA78BFA),
                label: 'Yakınlarım',
                onTap: () => openDependents(context),
              ),
              _ProfileTile(
                icon: Icons.notifications_rounded,
                color: AppColors.primary,
                label: 'Bildirimler',
                onTap: () => openNotifications(context),
              ),
              _ProfileTile(
                icon: Icons.support_agent_rounded,
                color: const Color(0xFFA78BFA),
                label: 'Destek Taleplerim',
                onTap: () => openSupport(context),
              ),
              _ProfileTile(
                icon: Icons.verified_user_rounded,
                color: AppColors.success,
                label: 'Hesap Güvenliği',
                onTap: () => openAccountSecurity(context),
              ),
              _ProfileTile(
                icon: Icons.history_rounded,
                color: AppColors.cyan,
                label: 'Giriş Geçmişim',
                onTap: () => openLoginHistory(context),
              ),
              _ProfileTile(
                icon: Icons.privacy_tip_rounded,
                color: AppColors.cyan,
                label: 'KVKK Aydınlatma Metni',
                onTap: () => openKvkk(context),
              ),
              _ProfileTile(
                icon: Icons.accessibility_new_rounded,
                color: AppColors.warning,
                label: 'Erişilebilirlik',
                onTap: () => openAccessibility(context),
              ),
              _ProfileTile(
                icon: Icons.qr_code_2_rounded,
                color: AppColors.indigo,
                label: 'Belge Doğrulama',
                onTap: () => openVerifyDocument(context),
              ),
              _ProfileTile(
                icon: Icons.power_settings_new_rounded,
                color: AppColors.danger,
                label: 'Çıkış Yap',
                onTap: () => confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TintedIcon(icon, color: color, size: 52),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
