import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'support_ticket.dart';
import 'ticket_detail_screen.dart';

/// Patients and guests: open a support request, follow their own, or look one up by number.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _mine = GlobalKey<AsyncListState<SupportTicket>>();

  Future<void> _open(SupportTicket ticket) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)));

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return DefaultTabController(
      length: session.isSignedIn ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Destek Talebi'),
          bottom: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              const Tab(text: 'Yeni Talep'),
              if (session.isSignedIn) const Tab(text: 'Taleplerim'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NewTicketForm(
              onCreated: (t) {
                _mine.currentState?.reload();
                _showCreated(t);
              },
              onLookup: _open,
            ),
            if (session.isSignedIn)
              AsyncList<SupportTicket>(
                key: _mine,
                emptyText: 'Henüz destek talebiniz yok.',
                emptyIcon: Icons.support_agent_rounded,
                load: () async =>
                    (await session.api.get('/api/support/tickets/mine') as List)
                        .map((j) => SupportTicket(j as Map<String, dynamic>))
                        .toList(),
                itemBuilder: (context, t, _) =>
                    SupportTicketCard(ticket: t, onTap: () => _open(t)),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreated(SupportTicket t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const TintedIcon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 64,
        ),
        title: const Text('Talebiniz alındı', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Talep numaranız:',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Clipboard.setData(ClipboardData(text: t.no));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Talep numarası kopyalandı.')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.no,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bu numarayla talebinizin durumunu istediğiniz zaman sorgulayabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _open(t);
            },
            child: const Text('Talebi Gör'),
          ),
        ],
      ),
    );
  }
}

class _NewTicketForm extends StatefulWidget {
  const _NewTicketForm({required this.onCreated, required this.onLookup});

  final ValueChanged<SupportTicket> onCreated;
  final ValueChanged<SupportTicket> onLookup;

  @override
  State<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends State<_NewTicketForm> {
  final _form = GlobalKey<FormState>();
  late final Session _session = SessionScope.read(context);
  late final _name = TextEditingController(
    text: _session.hasName ? _session.displayName : '',
  );
  late final _contact = TextEditingController(
    text: _session.email?.endsWith('@mhrs.local') == true
        ? ''
        : _session.email ?? '',
  );
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _lookup = TextEditingController();
  String _category = supportCategories.first;
  String _priority = 'Normal';
  bool _busy = false;
  bool _searching = false;

  @override
  void dispose() {
    for (final c in [_name, _contact, _subject, _description, _lookup]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final j = await _session.api.post('/api/support/tickets', {
        'adSoyad': _name.text.trim(),
        'iletisim': _contact.text.trim(),
        'kategori': _category,
        'oncelik': _priority,
        'konu': _subject.text.trim(),
        'aciklama': _description.text.trim(),
      });
      _subject.clear();
      _description.clear();
      widget.onCreated(SupportTicket(j as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final no = _lookup.text.trim().toUpperCase();
    if (no.isEmpty) return;
    setState(() => _searching = true);
    try {
      final j = await _session.api.get(
        '/api/support/tickets/${Uri.encodeComponent(no)}',
      );
      widget.onLookup(SupportTicket(j as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SupportHero(),
          const SizedBox(height: 20),
          // Look up an existing request by number.
          _Panel(
            icon: Icons.manage_search_rounded,
            color: AppColors.cyan,
            title: 'Talebimi sorgula',
            subtitle: 'Size verilen DT-… numarasıyla durumu görün.',
            child: TextField(
              controller: _lookup,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _search(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
              decoration: InputDecoration(
                hintText: 'DT-20261102-ABCDE',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: _search,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            icon: Icons.edit_note_rounded,
            color: AppColors.indigo,
            title: 'Yeni destek talebi',
            subtitle: 'Talebiniz yetkililere anında iletilir.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ad soyad *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Telefon veya e-posta',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Konu hangi alanla ilgili?'),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    for (final c in supportCategories)
                      _CategoryTile(
                        label: c,
                        selected: c == _category,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _FieldLabel('Öncelik'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final p in supportPriorities) ...[
                      if (p != supportPriorities.first)
                        const SizedBox(width: 8),
                      Expanded(
                        child: _PriorityPill(
                          label: p,
                          selected: p == _priority,
                          onTap: () => setState(() => _priority = p),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _subject,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Konu *',
                    prefixIcon: Icon(Icons.short_text_rounded),
                    counterText: '',
                  ),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama *',
                    hintText: 'Yaşadığınız sorunu kısaca anlatın.',
                    alignLabelWithHint: true,
                  ),
                  validator: required,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _busy
              ? const Center(child: CircularProgressIndicator())
              : GradientButton(
                  label: 'Talebi Gönder',
                  icon: Icons.send_rounded,
                  onPressed: _submit,
                ),
        ],
      ),
    );
  }
}

/// Gradient intro card: what the support desk does and the three steps of a request.
class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
    Widget arrow() => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Icon(
        Icons.chevron_right_rounded,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Size nasıl yardımcı olabiliriz?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Randevu, uygulama ya da hizmetle ilgili her konuda.',
                      style: TextStyle(color: Colors.white70, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              step(Icons.edit_rounded, 'Talebi\noluştur'),
              arrow(),
              step(Icons.confirmation_number_rounded, 'Numaranı\nal'),
              arrow(),
              step(Icons.track_changes_rounded, 'Durumu\ntakip et'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Surface card with a tinted icon, title and subtitle above its content.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TintedIcon(icon, color: color, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = supportCategoryColor(label);
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              supportCategoryIcon(label),
              color: selected ? color : AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = supportPriorityColor(label);
    return Material(
      color: selected ? color.withValues(alpha: 0.16) : AppColors.surfaceHigh,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
