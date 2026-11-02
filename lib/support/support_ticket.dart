import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const supportCategories = [
  'Randevu',
  'Teknik Sorun',
  'Şikâyet',
  'Öneri',
  'Diğer',
];
const supportPriorities = ['Düşük', 'Normal', 'Yüksek'];
const supportStatuses = ['Açık', 'İşlemde', 'Çözüldü', 'Kapatıldı'];

/// A support request from /api/support/tickets (kept in Google Sheets by n8n).
class SupportTicket {
  SupportTicket(Map<String, dynamic> j)
    : no = j['talepNo'] as String? ?? '',
      createdAt = j['olusturmaTarihi'] as String? ?? '',
      name = j['adSoyad'] as String? ?? '',
      contact = j['iletisim'] as String? ?? '',
      category = j['kategori'] as String? ?? '',
      priority = j['oncelik'] as String? ?? '',
      subject = j['konu'] as String? ?? '',
      description = j['aciklama'] as String? ?? '',
      status = j['durum'] as String? ?? '',
      updatedAt = j['guncellemeTarihi'] as String? ?? '',
      staffNote = j['yetkiliNotu'] as String? ?? '';

  final String no;
  final String createdAt;
  final String name;
  final String contact;
  final String category;
  final String priority;
  final String subject;
  final String description;
  final String status;
  final String updatedAt;
  final String staffNote;
}

Color supportStatusColor(String status) => switch (status) {
  'Açık' => AppColors.warning,
  'İşlemde' => AppColors.primary,
  'Çözüldü' => AppColors.success,
  'Kapatıldı' => AppColors.textMuted,
  _ => AppColors.textMuted,
};

IconData supportCategoryIcon(String category) => switch (category) {
  'Randevu' => Icons.event_note_rounded,
  'Teknik Sorun' => Icons.build_rounded,
  'Şikâyet' => Icons.report_rounded,
  'Öneri' => Icons.lightbulb_rounded,
  _ => Icons.help_rounded,
};

Color supportCategoryColor(String category) => switch (category) {
  'Randevu' => AppColors.primary,
  'Teknik Sorun' => AppColors.cyan,
  'Şikâyet' => AppColors.danger,
  'Öneri' => AppColors.warning,
  _ => AppColors.indigo,
};

Color supportPriorityColor(String priority) => switch (priority) {
  'Düşük' => AppColors.success,
  'Yüksek' => AppColors.danger,
  _ => AppColors.primary,
};

/// Coloured pill with the ticket status.
class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = supportStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Card used in ticket lists.
class SupportTicketCard extends StatelessWidget {
  const SupportTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.showRequester = false,
  });

  final SupportTicket ticket;
  final VoidCallback onTap;
  final bool showRequester;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(
                supportCategoryIcon(ticket.category),
                color: supportStatusColor(ticket.status),
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        ticket.no,
                        if (showRequester) ticket.name,
                        ticket.createdAt,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SupportStatusChip(ticket.status),
            ],
          ),
        ),
      ),
    );
  }
}
