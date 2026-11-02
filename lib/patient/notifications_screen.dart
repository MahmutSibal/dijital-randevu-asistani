import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: AsyncList<Map<String, dynamic>>(
        emptyText: 'Henüz bildiriminiz yok.',
        emptyIcon: Icons.notifications_none_rounded,
        load: () async =>
            (await api.get('/api/notifications', query: {'take': '50'}) as List)
                .cast<Map<String, dynamic>>(),
        itemBuilder: (context, n, _) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TintedIcon(
                  Icons.notifications_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n['message'] as String? ?? '',
                        style: const TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatDateTime(n['createdAtUtc'] as String),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
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
