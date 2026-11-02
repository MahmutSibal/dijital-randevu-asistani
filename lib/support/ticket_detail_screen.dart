import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'support_ticket.dart';

/// One support request: its progress, details and the staff note. With [canManage]
/// (hospital admin / super admin) the status can be changed. Pops `true` after a change.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.ticket,
    this.canManage = false,
  });

  final SupportTicket ticket;
  final bool canManage;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late SupportTicket _ticket = widget.ticket;
  bool _changed = false;

  Future<void> _refresh() async {
    try {
      final j = await SessionScope.read(context).api
          .get('/api/support/tickets/${_ticket.no}');
      if (mounted) {
        setState(() => _ticket = SupportTicket(j as Map<String, dynamic>));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editStatus() async {
    final updated = await showModalBottomSheet<SupportTicket>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _StatusSheet(ticket: _ticket),
    );
    if (updated != null && mounted) {
      setState(() {
        _ticket = updated;
        _changed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final step = supportStatuses.indexOf(t.status);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Talep Detayı')),
        floatingActionButton: widget.canManage
            ? FloatingActionButton.extended(
                onPressed: _editStatus,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Durumu Güncelle'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              _Header(ticket: t),
              const SizedBox(height: 24),
              _Progress(step: step, closed: t.status == 'Kapatıldı'),
              const SizedBox(height: 20),
              if (t.staffNote.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Yetkili notu',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.staffNote,
                              style: const TextStyle(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Açıklama',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        t.description,
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      _Row('Talep sahibi', t.name),
                      if (t.contact.isNotEmpty) _Row('İletişim', t.contact),
                      _Row('Oluşturulma', t.createdAt),
                      _Row('Son güncelleme', t.updatedAt),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status-tinted card with the copyable ticket number, subject, category and priority.
class _Header extends StatelessWidget {
  const _Header({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final color = supportStatusColor(t.status);
    Widget tag(IconData icon, String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: c,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.28), AppColors.surface],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: t.no));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Talep numarası kopyalandı.')),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.confirmation_number_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.no,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SupportStatusChip(t.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            t.subject,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              tag(
                supportCategoryIcon(t.category),
                t.category,
                supportCategoryColor(t.category),
              ),
              tag(
                Icons.flag_rounded,
                'Öncelik: ${t.priority}',
                supportPriorityColor(t.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Açık → İşlemde → Çözüldü, with Kapatıldı shown as a closed final state.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.closed});

  final int step;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    const labels = ['Alındı', 'İşlemde', 'Çözüldü'];
    final reached = closed ? 2 : step.clamp(0, 2);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: i <= reached ? AppGradients.primary : null,
                  color: i <= reached ? null : AppColors.surfaceHigh,
                ),
                child: Icon(
                  i < reached || (i == reached && (closed || step >= 2))
                      ? Icons.check_rounded
                      : Icons.circle,
                  size: i < reached || (i == reached && (closed || step >= 2))
                      ? 18
                      : 8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                i == 2 && closed ? 'Kapatıldı' : labels[i],
                style: TextStyle(
                  fontSize: 12,
                  color: i <= reached ? Colors.white : AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: i < reached
                      ? AppColors.primary
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.ticket});

  final SupportTicket ticket;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late String _status = widget.ticket.status;
  late final _note = TextEditingController(text: widget.ticket.staffNote);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final j = await SessionScope.read(context).api.patch(
        '/api/support/tickets/${widget.ticket.no}/status',
        {'durum': _status, 'not': _note.text.trim()},
      );
      if (mounted) {
        Navigator.pop(context, SupportTicket(j as Map<String, dynamic>));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Durumu Güncelle',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in supportStatuses)
                ChoiceChip(
                  label: Text(s),
                  selected: _status == s,
                  showCheckmark: false,
                  selectedColor: supportStatusColor(s).withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Talep sahibine not',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          const SizedBox(height: 12),
          _busy
              ? const Center(child: CircularProgressIndicator())
              : GradientButton(
                  label: 'Kaydet',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
        ],
      ),
    );
  }
}
