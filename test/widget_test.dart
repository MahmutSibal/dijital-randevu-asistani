import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dijital_randevu_asistani/core/session.dart';
import 'package:dijital_randevu_asistani/main.dart';
import 'package:dijital_randevu_asistani/theme/app_theme.dart' as theme;

void main() {
  setUp(() => theme.useGoogleFonts = false);

  testWidgets('bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MainApp(session: Session()));

    expect(find.text('Hızlı Erişim'), findsOneWidget);

    await tester.tap(find.text('Hizmetler'));
    await tester.pumpAndSettle();
    expect(find.text('Sağlık Profilim'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Size nasıl yardımcı olabilirim?'), findsOneWidget);
  });

  testWidgets('guest profile offers sign-in for every role', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MainApp(session: Session()));

    await tester.tap(find.text('Profilim'));
    await tester.pumpAndSettle();
    expect(find.text('PERSONEL GİRİŞİ'), findsOneWidget);

    await tester.ensureVisible(find.text('Admin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('E-posta'), findsOneWidget);

    await tester.tap(find.text('Hasta'));
    await tester.pumpAndSettle();
    expect(find.text('T.C. Kimlik No'), findsOneWidget);
    expect(find.text('Hesabınız yok mu? Kayıt Olun'), findsOneWidget);
  });
}
