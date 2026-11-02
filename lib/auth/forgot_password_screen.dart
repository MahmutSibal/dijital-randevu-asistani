import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

/// Patient password reset: the API checks the details against the patient record and
/// sends a new password to the phone number over WhatsApp.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _tc = TextEditingController();
  final _phone = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _tc, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).api
          .post('/api/auth/patient/forgot-password', {
            'firstName': _firstName.text.trim(),
            'lastName': _lastName.text.trim(),
            'tcKimlikNo': _tc.text.trim(),
            'phone': _phone.text.trim(),
          });
      setState(() => _sent = true);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Unuttum')),
      body: SafeArea(
        child: _sent
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TintedIcon(
                      Icons.mark_chat_read_rounded,
                      color: AppColors.success,
                      size: 84,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Yeni şifreniz gönderildi',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kayıtlı telefon numaranıza WhatsApp ile yeni bir şifre gönderdik. '
                      'Bu şifreyle giriş yapabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    GradientButton(
                      label: 'Girişe Dön',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  children: [
                    const Text(
                      'Bilgileriniz kayıtlarımızla eşleşirse kayıtlı telefon numaranıza '
                      'WhatsApp ile yeni bir şifre gönderilir.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _tc,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'T.C. Kimlik No',
                        counterText: '',
                      ),
                      validator: (v) =>
                          RegExp(r'^\d{11}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'T.C. Kimlik No 11 haneli olmalıdır.',
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Ad'),
                      validator: required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Soyad'),
                      validator: required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Kayıtlı cep telefonu',
                      ),
                      validator: required,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _busy
                        ? const Center(child: CircularProgressIndicator())
                        : GradientButton(
                            label: 'Yeni Şifre Gönder',
                            icon: Icons.send_rounded,
                            onPressed: _submit,
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}
