import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../patient/patient_nav.dart';
import 'home_shell.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final cards = [
      ServiceCard(
        icon: Icons.local_hospital_rounded,
        color: AppColors.danger,
        title: 'Hastaneler',
        description: 'Hastanelerin bölümleri ve iletişim bilgileri',
        onTap: () => openBooking(context),
      ),
      ServiceCard(
        icon: Icons.medical_services_rounded,
        color: AppColors.success,
        title: 'Doktorlar',
        description: 'Doktor arayın ve uygun saatleri görün',
        onTap: () => openBooking(context),
      ),
      ServiceCard(
        icon: Icons.event_note_rounded,
        color: AppColors.warning,
        title: 'Randevularım',
        description: 'Aktif ve geçmiş randevularınız',
        onTap: () => openMyAppointments(context),
      ),
      ServiceCard(
        icon: Icons.monitor_heart_rounded,
        color: const Color(0xFFFF7043),
        title: 'Sağlık Profilim',
        description: 'Kronik hastalık, alerji ve ilaç bilgileriniz',
        onTap: () => openHealthProfile(context),
      ),
      ServiceCard(
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFF26C6DA),
        title: 'Bekleme Listesi',
        description: 'Boş yer açıldığında haber alın',
        onTap: () => openWaitlistInfo(context),
      ),
      ServiceCard(
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFA78BFA),
        title: 'Destek Talebi',
        description: 'Sorun bildirin, talebinizi takip edin',
        onTap: () => openSupport(context),
      ),
      ServiceCard(
        icon: Icons.qr_code_2_rounded,
        color: AppColors.indigo,
        title: 'Belge Doğrulama',
        description: 'Randevu belgesinin gerçekliğini kontrol edin',
        onTap: () => openVerifyDocument(context),
      ),
      ServiceCard(
        icon: Icons.accessibility_new_rounded,
        color: AppColors.warning,
        title: 'Erişilebilirlik',
        description: 'Yazı boyutu, kalın yazı ve yüksek kontrast',
        onTap: () => openAccessibility(context),
      ),
      ServiceCard(
        icon: Icons.forum_rounded,
        color: AppColors.primary,
        title: 'Asistan',
        description: 'Yapay zekâ asistanına soru sorun',
        onTap: () => onOpenTab(AppTab.assistant),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Hizmetler'), centerTitle: false),
      body: GridView.count(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: cards,
      ),
    );
  }
}
