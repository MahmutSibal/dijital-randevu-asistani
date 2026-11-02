import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';

/// Asks for the 6-digit code sent to the patient's phone. Pops `true` once signed in.
class TwoFactorDialog extends StatefulWidget {
  const TwoFactorDialog({super.key, required this.challenge});

  final TwoFactorRequired challenge;

  @override
  State<TwoFactorDialog> createState() => _TwoFactorDialogState();
}

class _TwoFactorDialogState extends State<TwoFactorDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Kod 6 haneli olmalıdır.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context)
          .verifyTwoFactor(widget.challenge.challengeId, _code.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dev = widget.challenge.devCode;
    return AlertDialog(
      // Center keeps the badge square; the dialog stretches its icon slot.
      icon: const Center(
        heightFactor: 1,
        child: TintedIcon(
          Icons.phonelink_lock_rounded,
          color: AppColors.primary,
          size: 64,
        ),
      ),
      title: const Text('Doğrulama Kodu', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.challenge.maskedPhone} numaralı telefonunuza gönderilen 6 haneli kodu girin.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _verify(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 10,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
            ),
          ),
          if (dev != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Geliştirme ortamı: kod $dev',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12.5,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Doğrula'),
        ),
      ],
    );
  }
}
