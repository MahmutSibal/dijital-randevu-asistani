import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';
import 'slot_picker.dart' show formatDay;

const relations = {
  'Child': 'Çocuğum',
  'Mother': 'Annem',
  'Father': 'Babam',
  'Sister': 'Kız kardeşim',
  'Brother': 'Erkek kardeşim',
};

/// Family members the patient can book appointments for.
class DependentsScreen extends StatefulWidget {
  const DependentsScreen({super.key});

  @override
  State<DependentsScreen> createState() => _DependentsScreenState();
}

class _DependentsScreenState extends State<DependentsScreen> {
  final _list = GlobalKey<AsyncListState<Map<String, dynamic>>>();

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AddDependentSheet(),
    );
    if (added == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: const Text('Yakınlarım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yakın Ekle'),
      ),
      body: AsyncList<Map<String, dynamic>>(
        key: _list,
        emptyText: 'Henüz yakın eklemediniz.\nEklediğiniz yakınlarınız adına randevu alabilirsiniz.',
        emptyIcon: Icons.family_restroom_rounded,
        load: () async => (await api.get('/api/patient/dependents/me') as List)
            .cast<Map<String, dynamic>>(),
        itemBuilder: (context, d, reload) {
          final birth = DateTime.tryParse(d['birthDate'] as String? ?? '');
          return InfoTile(
            icon: Icons.person_rounded,
            color: const Color(0xFFA78BFA),
            title: d['fullName'] as String? ?? '',
            subtitle: [
              relations[d['relation']] ?? d['relation'],
              if (birth != null) formatDay(birth),
            ].join(' · '),
            trailing: IconButton(
              tooltip: 'Sil',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
              onPressed: () async {
                if (!await confirm(
                  context,
                  'UYARI',
                  '${d['fullName']} yakınlarınızdan silinecek.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                final ok = await runWithFeedback(
                  context,
                  () => api.delete('/api/patient/dependents/me/${d['id']}'),
                  success: 'Yakın silindi.',
                );
                if (ok) reload();
              },
            ),
          );
        },
      ),
    );
  }
}

class _AddDependentSheet extends StatefulWidget {
  const _AddDependentSheet();

  @override
  State<_AddDependentSheet> createState() => _AddDependentSheetState();
}

class _AddDependentSheetState extends State<_AddDependentSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tc = TextEditingController();
  String? _relation;
  DateTime? _birth;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _tc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (_birth == null) setState(() => _error = 'Doğum tarihini seçin.');
    if (!valid || _birth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).api.post('/api/patient/dependents/me', {
        'fullName': _name.text.trim(),
        'tcKimlikNo': _tc.text.trim(),
        'birthDate': formatDate(_birth!),
        'relation': _relation,
      });
      if (mounted) Navigator.pop(context, true);
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
      child: Form(
        key: _form,
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
              'Yakın Ekle',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ad soyad, T.C. Kimlik No ve doğum tarihi nüfus kayıtlarıyla doğrulanır.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tc,
              keyboardType: TextInputType.number,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: 'T.C. Kimlik No',
                counterText: '',
              ),
              validator: (v) => RegExp(r'^\d{11}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'T.C. Kimlik No 11 haneli olmalıdır.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: AppColors.surfaceHigh,
              decoration: const InputDecoration(labelText: 'Yakınlık'),
              items: [
                for (final e in relations.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => _relation = v,
              validator: (v) => v == null ? 'Yakınlık türünü seçin.' : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.field),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birth ?? DateTime(2015),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  helpText: 'Doğum tarihi',
                );
                if (picked != null) setState(() => _birth = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Doğum tarihi',
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(_birth == null ? 'Seçiniz' : formatDay(_birth!)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : GradientButton(
                    label: 'Kaydet',
                    icon: Icons.check_rounded,
                    onPressed: _submit,
                  ),
          ],
        ),
      ),
    );
  }
}
