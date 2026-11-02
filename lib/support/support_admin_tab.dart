import 'package:flutter/material.dart';

import '../auth/sign_out.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'support_ticket.dart';
import 'ticket_detail_screen.dart';

/// Hospital admin / super admin: every support request, filterable by status.
class SupportAdminTab extends StatefulWidget {
  const SupportAdminTab({super.key});

  @override
  State<SupportAdminTab> createState() => _SupportAdminTabState();
}

class _SupportAdminTabState extends State<SupportAdminTab> {
  final _list = GlobalKey<AsyncListState<SupportTicket>>();
  String? _status; // null = all

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return PanelScaffold(
      title: 'Destek Talepleri',
      onSignOut: () => confirmSignOut(context),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final s in <String?>[null, ...supportStatuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() => _status = s);
                        _list.currentState?.reload();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: _status == s ? AppGradients.primary : null,
                          color: _status == s ? null : AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _status == s
                                ? Colors.transparent
                                : AppColors.outline,
                          ),
                        ),
                        child: Text(
                          s ?? 'Tümü',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _status == s
                                ? Colors.white
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncList<SupportTicket>(
              key: _list,
              emptyText: 'Bu listede destek talebi yok.',
              emptyIcon: Icons.support_agent_rounded,
              load: () async =>
                  (await api.get(
                        '/api/support/tickets',
                        query: _status == null ? null : {'durum': _status!},
                      ) as List)
                      .map((j) => SupportTicket(j as Map<String, dynamic>))
                      .toList(),
              itemBuilder: (context, t, reload) => SupportTicketCard(
                ticket: t,
                showRequester: true,
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          TicketDetailScreen(ticket: t, canManage: true),
                    ),
                  );
                  if (changed == true) reload();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
