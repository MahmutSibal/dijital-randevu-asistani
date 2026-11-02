import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api_client.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// A certificate from /api/documents (issue or verify).
class AppointmentDocument {
  AppointmentDocument(Map<String, dynamic> j)
    : code = j['code'] as String,
      issuedAt = formatDateTime(j['issuedAtUtc'] as String),
      patient = j['patientName'] as String? ?? '',
      tc = j['maskedTcKimlikNo'] as String? ?? '',
      hospital = j['hospital'] as String? ?? '',
      department = j['department'] as String? ?? '',
      doctor = j['doctor'] as String? ?? '',
      startAt = formatDateTime(j['startAt'] as String),
      status = j['status'] as String? ?? '';

  final String code;
  final String issuedAt;
  final String patient;
  final String tc;
  final String hospital;
  final String department;
  final String doctor;
  final String startAt;
  final String status;

  /// What the QR code holds; the verify screen accepts it as well as the bare code.
  String get qrData => 'DRA-BELGE:$code';

  List<(String, String)> get rows => [
    ('Hasta', patient),
    ('T.C. Kimlik No', tc),
    ('Hastane', hospital),
    ('Bölüm', department),
    ('Hekim', doctor),
    ('Randevu tarihi', startAt),
    ('Randevu durumu', status),
    ('Belge tarihi', issuedAt),
  ];
}

/// Issues a certificate for [appointmentId] and opens it.
Future<void> openAppointmentDocument(
  BuildContext context,
  String appointmentId,
) async {
  final api = SessionScope.read(context).api;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final j = await api.post('/api/documents/appointments/$appointmentId');
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AppointmentDocumentScreen(
          document: AppointmentDocument(j as Map<String, dynamic>),
        ),
      ),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class AppointmentDocumentScreen extends StatelessWidget {
  const AppointmentDocumentScreen({super.key, required this.document});

  final AppointmentDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu Belgesi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          DocumentPaper(document: document),
          const SizedBox(height: 20),
          GradientButton(
            label: 'PDF Olarak Paylaş',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: () => _sharePdf(context),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: document.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Doğrulama kodu kopyalandı.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Doğrulama Kodunu Kopyala'),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.sharePdf(
        bytes: await buildDocumentPdf(document),
        filename: 'randevu-belgesi-${document.code}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('PDF oluşturulamadı. Lütfen tekrar deneyin.'),
        ),
      );
    }
  }
}

/// The certificate drawn as a sheet of paper, with the QR code and verification code.
class DocumentPaper extends StatelessWidget {
  const DocumentPaper({super.key, required this.document});

  final AppointmentDocument document;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F2937);
    const muted = Color(0xFF6B7280);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANDEVU BELGESİ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Dijital Randevu Asistanı',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              children: [
                for (final (label, value) in document.rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 118,
                          child: Text(
                            label,
                            style: const TextStyle(color: muted, fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(
            color: Color(0xFFE5E7EB),
            height: 24,
            indent: 20,
            endIndent: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                QrImageView(
                  data: document.qrData,
                  size: 104,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: ink,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Doğrulama kodu',
                        style: TextStyle(color: muted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        document.code,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bu belgenin geçerliliğini uygulamadaki Belge Doğrulama ekranından bu kodla kontrol edebilirsiniz.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A4 PDF of the certificate. Noto Sans is fetched for the Turkish letters
/// (the built-in PDF fonts lack ğ, ş, ı).
Future<Uint8List> buildDocumentPdf(AppointmentDocument d) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const accent = PdfColor.fromInt(0xFF4F46E5);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(18),
            color: accent,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RANDEVU BELGESİ',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Dijital Randevu Asistanı',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(140),
              1: pw.FlexColumnWidth(),
            },
            children: [
              for (final (label, value) in d.rows)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(
                        label,
                        style: const pw.TextStyle(color: PdfColors.grey700),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      child: pw.Text(
                        value,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: d.qrData,
                width: 90,
                height: 90,
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Doğrulama kodu',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      d.code,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Bu belge elektronik ortamda oluşturulmuştur. Geçerliliğini Dijital Randevu '
                      'Asistanı uygulamasındaki Belge Doğrulama ekranından yukarıdaki kodla kontrol edebilirsiniz.',
                      style: const pw.TextStyle(
                        color: PdfColors.grey700,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return pdf.save();
}
