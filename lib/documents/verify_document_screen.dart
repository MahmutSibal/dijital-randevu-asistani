import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../theme/app_theme.dart';
import 'appointment_document.dart';

/// Public check of a certificate's verification code; no sign-in needed.
class VerifyDocumentScreen extends StatefulWidget {
  const VerifyDocumentScreen({super.key});

  @override
  State<VerifyDocumentScreen> createState() => _VerifyDocumentScreenState();
}

class _VerifyDocumentScreenState extends State<VerifyDocumentScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  AppointmentDocument? _found;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    // Accept the QR payload ("DRA-BELGE:RB-…") as well as the bare code.
    final code = _code.text.trim().toUpperCase().replaceFirst('DRA-BELGE:', '');
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _found = null;
      _error = null;
    });
    try {
      final j = await SessionScope.read(context).api
          .get('/api/documents/verify/${Uri.encodeComponent(code)}');
      setState(() => _found = AppointmentDocument(j as Map<String, dynamic>));
    } on ApiException catch (e) {
      setState(
        () => _error = e.statusCode == 404
            ? 'Bu doğrulama koduyla düzenlenmiş bir belge bulunamadı. Kodu kontrol edip tekrar deneyin.'
            : e.message,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belge Doğrulama')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 44),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Size ibraz edilen randevu belgesinin gerçek olup olmadığını, '
                    'belgedeki doğrulama koduyla kontrol edin.',
                    style: TextStyle(color: Colors.white, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _verify(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            decoration: InputDecoration(
              labelText: 'Doğrulama kodu',
              hintText: 'RB-XXXX-XXXX-XXXX',
              hintStyle: TextStyle(
                color: AppColors.textMuted.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.verified_user_outlined),
            ),
          ),
          const SizedBox(height: 14),
          _busy
              ? const Center(child: CircularProgressIndicator())
              : GradientButton(
                  label: 'Doğrula',
                  icon: Icons.search_rounded,
                  onPressed: _verify,
                ),
          const SizedBox(height: 24),
          if (_found != null) ...[
            const _Result(
              ok: true,
              text: 'Belge doğrulandı. Bu belge sistemimiz tarafından düzenlenmiştir.',
            ),
            const SizedBox(height: 14),
            DocumentPaper(document: _found!),
          ],
          if (_error != null) _Result(ok: false, text: _error!),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
