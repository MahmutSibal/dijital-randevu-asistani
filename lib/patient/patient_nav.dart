import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../core/session.dart';
import '../core/widgets.dart';
import '../documents/verify_document_screen.dart';
import '../security/account_security_screen.dart';
import '../security/kvkk_screen.dart';
import '../settings/accessibility_screen.dart';
import '../security/login_history_screen.dart';
import '../support/support_screen.dart';
import 'book_appointment_screen.dart';
import 'dependents_screen.dart';
import 'health_profile_screen.dart';
import 'my_appointments_screen.dart';
import 'notifications_screen.dart';

/// Opens a patient screen, asking guests to sign in first.
void openAsPatient(BuildContext context, WidgetBuilder builder) {
  final signedIn = SessionScope.read(context).role == UserRole.patient;
  Navigator.of(context).push(
    MaterialPageRoute(builder: signedIn ? builder : (_) => const LoginScreen()),
  );
}

void openBooking(BuildContext context) =>
    openAsPatient(context, (_) => const BookAppointmentScreen());

void openMyAppointments(BuildContext context) =>
    openAsPatient(context, (_) => const MyAppointmentsScreen());

void openHealthProfile(BuildContext context) =>
    openAsPatient(context, (_) => const HealthProfileScreen());

void openDependents(BuildContext context) =>
    openAsPatient(context, (_) => const DependentsScreen());

void openNotifications(BuildContext context) =>
    openAsPatient(context, (_) => const NotificationsScreen());

void openAccountSecurity(BuildContext context) =>
    openAsPatient(context, (_) => const AccountSecurityScreen());

/// Open to guests too: the settings live on the device.
void openAccessibility(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccessibilityScreen()));

void openLoginHistory(BuildContext context) =>
    openAsPatient(context, (_) => const LoginHistoryScreen());

Future<void> openKvkk(BuildContext context) async {
  final s = await SessionScope.read(context).loadAccountSecurity();
  final at = (s?['kvkk'] as Map<String, dynamic>?)?['acceptedAtUtc'] as String?;
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          KvkkScreen(acceptedAt: at == null ? null : formatDateTime(at)),
    ),
  );
}

/// Anyone can check a certificate, signed in or not.
void openVerifyDocument(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const VerifyDocumentScreen()));

/// Support requests are open to guests too (no sign-in needed).
void openSupport(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SupportScreen()));

/// There is no waitlist screen of its own: patients join from a full slot while booking.
Future<void> openWaitlistInfo(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bekleme Listesi'),
      content: const Text(
        'Randevu alırken dolu (sarı) bir saate dokunun. O saat boşalırsa size bildirim gönderilir.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Kapat'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Randevu Al'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) openBooking(context);
}
