import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/widgets.dart';

/// "Kişisel Verilerim" PDF from /api/account/export (KVKK md. 11).
Future<Uint8List> buildDataExportPdf(Map<String, dynamic> data) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const accent = PdfColor.fromInt(0xFF4F46E5);

  String v(Object? x) => x == null || '$x'.isEmpty ? '-' : '$x';
  String date(Object? iso) => iso == null ? '-' : formatDateTime('$iso');

  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: accent,
      ),
    ),
  );

  pw.Widget pairs(List<(String, String)> rows) => pw.Table(
    columnWidths: const {0: pw.FixedColumnWidth(150), 1: pw.FlexColumnWidth()},
    children: [
      for (final (k, value) in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(
                k,
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(value),
            ),
          ],
        ),
    ],
  );

  pw.Widget table(List<String> headers, List<List<String>> rows) => rows.isEmpty
      ? pw.Text(
          'Kayıt yok.',
          style: const pw.TextStyle(color: PdfColors.grey600),
        )
      : pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
        );

  final account = data['account'] as Map<String, dynamic>? ?? {};
  final patient = data['patient'] as Map<String, dynamic>?;
  final health = patient?['healthProfile'] as Map<String, dynamic>? ?? {};
  final dependents = (data['dependents'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final appointments = (data['appointments'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final logins = (data['loginHistory'] as List? ?? [])
      .cast<Map<String, dynamic>>();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(14),
        color: accent,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'KİŞİSEL VERİLERİM',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
              ),
            ),
            pw.Text(
              'Dijital Randevu Asistanı · ${date(data['generatedAtUtc'])}',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'KVKK md. 11 kapsamında hazırlanmıştır · Sayfa ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
        ),
      ),
      build: (_) => [
        if (patient != null) ...[
          section('Kimlik ve iletişim'),
          pairs([
            (
              'Ad soyad',
              '${v(patient['firstName'])} ${v(patient['lastName'])}',
            ),
            ('T.C. kimlik no', v(patient['tcKimlikNo'])),
            ('Doğum tarihi', v(patient['birthDate'])),
            ('Telefon', v(patient['phone'])),
          ]),
          section('Sağlık profili'),
          pairs([
            ('Kan grubu', v(health['bloodType'])),
            ('Alerjiler', v(health['allergies'])),
            ('Kronik hastalıklar', v(health['chronicDiseases'])),
            ('Kullanılan ilaçlar', v(health['medications'])),
            (
              'Acil durumda aranacak',
              '${v(health['emergencyContactName'])} ${health['emergencyContactPhone'] ?? ''}',
            ),
          ]),
        ],
        section('Hesap'),
        pairs([
          ('Rol', v(account['role'])),
          (
            'KVKK onayı',
            '${v(account['kvkkConsentVersion'])} · ${date(account['kvkkConsentAtUtc'])}',
          ),
          (
            'İki adımlı doğrulama',
            account['twoFactorEnabled'] == true ? 'Açık' : 'Kapalı',
          ),
        ]),
        section('Yakınlarım (${dependents.length})'),
        table(
          ['Ad soyad', 'T.C. kimlik no', 'Doğum tarihi', 'Yakınlık'],
          [
            for (final d in dependents)
              [
                v(d['fullName']),
                v(d['tcKimlikNo']),
                v(d['birthDate']),
                v(d['relation']),
              ],
          ],
        ),
        section('Randevular (${appointments.length})'),
        table(
          ['Tarih', 'Hastane', 'Bölüm', 'Hekim', 'Durum'],
          [
            for (final a in appointments)
              [
                date(a['startAt']),
                v(a['hospital']),
                v(a['department']),
                v(a['doctor']),
                v(a['status']),
              ],
          ],
        ),
        section('Son girişler'),
        table(
          ['Tarih', 'Sonuç', 'Cihaz', 'IP'],
          [
            for (final l in logins.take(30))
              [
                date(l['atUtc']),
                l['success'] == true ? 'Başarılı' : 'Hatalı şifre',
                v(l['device']),
                v(l['ipAddress']),
              ],
          ],
        ),
      ],
    ),
  );
  return pdf.save();
}
