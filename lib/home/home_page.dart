import 'package:flutter/material.dart';

import '../core/session.dart';
import '../patient/patient_nav.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.hasName ? session.displayName : null;
    final quickActions = [
      QuickAction(
        icon: Icons.edit_calendar_rounded,
        color: AppColors.warning,
        label: 'Randevu Al',
        onTap: () => openBooking(context),
      ),
      QuickAction(
        icon: Icons.event_note_rounded,
        color: AppColors.cyan,
        label: 'Randevularım',
        onTap: () => openMyAppointments(context),
      ),
      QuickAction(
        icon: Icons.local_hospital_rounded,
        color: AppColors.danger,
        label: 'Hastaneler',
        onTap: () => openBooking(context),
      ),
      QuickAction(
        icon: Icons.medical_services_rounded,
        color: AppColors.success,
        label: 'Doktorlar',
        onTap: () => openBooking(context),
      ),
      QuickAction(
        icon: Icons.forum_rounded,
        color: AppColors.primary,
        label: 'Asistana Sor',
        onTap: () => onOpenTab(AppTab.assistant),
      ),
      QuickAction(
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFA78BFA),
        label: 'Destek Talebi',
        onTap: () => openSupport(context),
      ),
    ];

    return GlowBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                const AppLogo(),
                const Spacer(),
                _RoundIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Bildirimler',
                  onPressed: () => openNotifications(context),
                ),
                const SizedBox(width: 8),
                _RoundIconButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: 'Bilgi',
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'Dijital Randevu Asistanı',
                    children: const [
                      Text(
                        'Hastane randevularınızı yönetin ve yapay zekâ asistanına danışın.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _HeroCard(name: name, onOpenTab: onOpenTab),
            const SizedBox(height: 28),
            SectionHeader(
              'Hızlı Erişim',
              action: 'Tümü',
              onAction: () => onOpenTab(AppTab.services),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              childAspectRatio: 0.92,
              children: quickActions,
            ),
            const SizedBox(height: 20),
            _AssistantCard(onTap: () => onOpenTab(AppTab.assistant)),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.onOpenTab});

  final String? name;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -18,
            child: Icon(
              Icons.calendar_month_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null ? 'Hoş geldiniz' : 'Merhaba,',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                if (name != null)
                  Text(
                    name!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Randevunuzu birkaç adımda alın,\nsorularınızı asistana sorun.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => openBooking(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Randevu Al'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.field,
                            ),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => openMyAppointments(context),
                        icon: const Icon(Icons.event_note_rounded),
                        label: const Text('Randevularım'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Gradient hairline border around a dark card.
    return Container(
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(AppRadius.card + 1),
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const TintedIcon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 52,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yapay Zekâ Asistanı',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Randevu ve uygulama hakkındaki sorularınızı yanıtlar.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.outline)),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
