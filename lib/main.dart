import 'package:flutter/material.dart';

import 'admin/admin_shell.dart';
import 'core/accessibility.dart';
import 'core/session.dart';
import 'doctor/doctor_shell.dart';
import 'home/home_shell.dart';
import 'hospital_admin/hospital_admin_shell.dart';
import 'security/kvkk_screen.dart';
import 'security/session_guard.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session();
  await Future.wait([session.restore(), accessibility.load()]);
  runApp(MainApp(session: session));
}

class MainApp extends StatelessWidget {
  MainApp({super.key, required this.session});

  final Session session;
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'Dijital Randevu Asistanı',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        navigatorKey: _navigator,
        scaffoldMessengerKey: _messenger,
        builder: (context, child) => ListenableBuilder(
          listenable: accessibility,
          builder: (context, _) => accessibility.apply(
            context,
            SessionGuard(
              navigatorKey: _navigator,
              messengerKey: _messenger,
              child: child!,
            ),
          ),
        ),
        home: const RoleRouter(),
      ),
    );
  }
}

/// Shows the panel for the signed-in user's role. Guests and patients get the
/// patient app; staff get their management panel. Anyone who has not accepted
/// the current KVKK disclosure sees that first.
class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.isSignedIn && session.needsKvkk) {
      return const KvkkScreen(required: true);
    }
    return switch (session.isSignedIn ? session.role : null) {
      UserRole.doctor => const DoctorShell(),
      UserRole.hospitalAdmin => const HospitalAdminShell(),
      UserRole.admin => const AdminShell(),
      _ => const HomeShell(),
    };
  }
}
