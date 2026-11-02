import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

/// Patient sign-up. The API checks the T.C. Kimlik No, name and birth date
/// against the population registry (NVI), so they must be real and match.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _tc = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _tc,
      _firstName,
      _lastName,
      _phone,
      _password,
      _password2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Doğum tarihi',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (_birthDate == null) setState(() => _error = 'Doğum tarihinizi seçin.');
    if (!valid || _birthDate == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).registerPatient(
        tcKimlikNo: _tc.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        birthDate: _birthDate!,
        password: _password.text,
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? 'Bu alan zorunludur.' : null;
    const hint = TextStyle(color: AppColors.textMuted, fontSize: 13);

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const Text(
                'Kimlik Bilgileri',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tc,
                keyboardType: TextInputType.number,
                maxLength: 11,
                decoration: const InputDecoration(
                  hintText: 'T.C. Kimlik No *',
                  counterText: '',
                ),
                validator: (v) => RegExp(r'^\d{11}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'T.C. Kimlik No 11 haneli olmalıdır.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Ad *'),
                validator: required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Soyad *'),
                validator: required,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Doğum Tarihi *'
                        : '${_birthDate!.day.toString().padLeft(2, '0')}.'
                              '${_birthDate!.month.toString().padLeft(2, '0')}.${_birthDate!.year}',
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDate == null
                          ? AppColors.textMuted
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Bilgileriniz nüfus kayıtlarıyla doğrulanır.',
                  style: hint,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'İletişim ve Şifre',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: 'Cep Telefonu * (5XX XXX XX XX)',
                ),
                validator: required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Şifre *'),
                validator: (v) => (v ?? '').length < 6
                    ? 'Şifre en az 6 karakter olmalıdır.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password2,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Şifre (tekrar) *'),
                validator: (v) =>
                    v != _password.text ? 'Şifreler eşleşmiyor.' : null,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Şifreniz en az 6 karakter olmalıdır.',
                  style: hint,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 15),
                ),
              ],
              const SizedBox(height: 28),
              _busy
                  ? const Center(child: CircularProgressIndicator())
                  : GradientButton(label: 'Kayıt Ol', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
