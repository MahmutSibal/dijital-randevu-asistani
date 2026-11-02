import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../security/two_factor_dialog.dart';
import '../theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialRole = UserRole.patient});

  final UserRole initialRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late UserRole _role = widget.initialRole;
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _isPatient => _role == UserRole.patient;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context)
          .signIn(_role, _identifier.text, _password.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on EmailVerificationRequired {
      if (!mounted) return;
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            _EmailCodeDialog(email: _identifier.text, password: _password.text),
      );
      if (verified == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on TwoFactorRequired catch (challenge) {
      if (!mounted) return;
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => TwoFactorDialog(challenge: challenge),
      );
      if (verified == true && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: GlowBackground(
        child: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
                const Center(child: AppLogo(large: true)),
                const SizedBox(height: 32),
                _RolePicker(
                  selected: _role,
                  onChanged: (role) => setState(() {
                    _role = role;
                    _identifier.clear();
                    _error = null;
                  }),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _identifier,
                  keyboardType: _isPatient
                      ? TextInputType.number
                      : TextInputType.emailAddress,
                  maxLength: _isPatient ? 11 : null,
                  textInputAction: TextInputAction.next,
                  autofillHints: [
                    _isPatient ? AutofillHints.username : AutofillHints.email,
                  ],
                  decoration: InputDecoration(
                    hintText: _isPatient ? 'T.C. Kimlik No' : 'E-posta',
                    prefixIcon: Icon(
                      _isPatient ? Icons.badge_outlined : Icons.alternate_email,
                    ),
                    counterText: '',
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (_isPatient) {
                      return RegExp(r'^\d{11}$').hasMatch(value)
                          ? null
                          : 'T.C. Kimlik No 11 haneli olmalıdır.';
                    }
                    return value.contains('@')
                        ? null
                        : 'Geçerli bir e-posta girin.';
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Şifre',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Şifrenizi girin.' : null,
                ),
                if (_isPatient)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text('Şifremi Unuttum'),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 15,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                _busy
                    ? const Center(child: CircularProgressIndicator())
                    : GradientButton(label: 'Giriş Yap', onPressed: _submit),
                const SizedBox(height: 20),
                if (_isPatient)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Hesabınız yok mu? Kayıt Olun',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  )
                else
                  const Text(
                    'Doktor ve yönetici hesapları sistem tarafından oluşturulur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First staff sign-in: asks for the code the API e-mailed. Pops `true` once signed in.
class _EmailCodeDialog extends StatefulWidget {
  const _EmailCodeDialog({required this.email, required this.password});

  final String email;
  final String password;

  @override
  State<_EmailCodeDialog> createState() => _EmailCodeDialogState();
}

class _EmailCodeDialogState extends State<_EmailCodeDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? success,
    bool close = false,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (close && mounted) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _message = success;
        _messageIsError = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.read(context);
    return AlertDialog(
      title: const Text('E-POSTA DOĞRULAMA'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.email} adresine bir doğrulama kodu gönderildi. '
            'İlk girişinizi tamamlamak için kodu girin.',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Doğrulama kodu'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(
                color: _messageIsError ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => session.resendEmailCode(
                        widget.email,
                        widget.password,
                      ),
                      success: 'Yeni kod gönderildi.',
                    ),
              child: const Text('Kodu tekrar gönder'),
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('İPTAL'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : () => _run(
                  () => session.confirmEmail(
                    widget.email,
                    widget.password,
                    _code.text,
                  ),
                  close: true,
                ),
          child: const Text('DOĞRULA'),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  static const _icons = {
    UserRole.patient: Icons.person_rounded,
    UserRole.doctor: Icons.medical_services_rounded,
    UserRole.hospitalAdmin: Icons.local_hospital_rounded,
    UserRole.admin: Icons.admin_panel_settings_rounded,
  };

  static const _short = {
    UserRole.patient: 'Hasta',
    UserRole.doctor: 'Doktor',
    UserRole.hospitalAdmin: 'Hastane',
    UserRole.admin: 'Admin',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final role in UserRole.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: role == selected ? AppGradients.primary : null,
                    color: role == selected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: role == selected
                          ? Colors.transparent
                          : AppColors.outline,
                    ),
                    boxShadow: role == selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _icons[role],
                        color: role == selected
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _short[role]!,
                        style: TextStyle(
                          color: role == selected
                              ? Colors.white
                              : AppColors.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
