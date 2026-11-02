import 'dart:async';

import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/widgets.dart';
import '../theme/app_theme.dart';

/// Minutes without touching the app before the session ends (e-Devlet style).
/// Shorten it for a demo with --dart-define=IDLE_MINUTES=2.
const idleMinutes = int.fromEnvironment('IDLE_MINUTES', defaultValue: 10);
const _warningSeconds = 60;

/// Wraps the whole app while someone is signed in:
/// - ends the session after [idleMinutes] of inactivity, with a one-minute countdown first;
/// - after a sign-in, shows when the previous login was and loads the KVKK state.
class SessionGuard extends StatefulWidget {
  const SessionGuard({
    super.key,
    required this.navigatorKey,
    required this.messengerKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Widget child;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  late final Session _session = SessionScope.read(context);
  StreamSubscription<void>? _signIns;
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  bool _warning = false;
  bool _wasSignedIn = false;

  static const _idle = Duration(minutes: idleMinutes);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _session.addListener(_onSessionChanged);
      _signIns = _session.signIns.listen((_) => _afterSignIn());
      _onSessionChanged();
      if (_session.isSignedIn) _session.loadAccountSecurity();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    _signIns?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _onSessionChanged() {
    final signedIn = _session.isSignedIn;
    if (signedIn && !_wasSignedIn) _restart();
    if (!signedIn) _timer?.cancel();
    _wasSignedIn = signedIn;
  }

  void _restart() {
    _lastActivity = DateTime.now();
    _timer?.cancel();
    if (!_session.isSignedIn) return;
    _timer = Timer(
      _idle - const Duration(seconds: _warningSeconds),
      _showWarning,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Timers don't run reliably while the app is in the background.
    if (state != AppLifecycleState.resumed ||
        !_session.isSignedIn ||
        _warning) {
      return;
    }
    final idleFor = DateTime.now().difference(_lastActivity);
    if (idleFor >= _idle) {
      _expire();
    } else if (idleFor >= _idle - const Duration(seconds: _warningSeconds)) {
      _showWarning();
    }
  }

  Future<void> _showWarning() async {
    final context = widget.navigatorKey.currentContext;
    if (context == null || !_session.isSignedIn || _warning) return;
    _warning = true;
    final left = _idle - DateTime.now().difference(_lastActivity);
    final extend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _TimeoutDialog(seconds: left.inSeconds.clamp(1, _warningSeconds)),
    );
    _warning = false;
    if (extend == true) {
      _restart();
    } else {
      await _expire(byUser: extend == false);
    }
  }

  Future<void> _expire({bool byUser = false}) async {
    _timer?.cancel();
    widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
    await _session.signOut();
    if (byUser) return;
    widget.messengerKey.currentState?.showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 6),
        content: Text(
          'Güvenliğiniz için, uzun süre işlem yapılmadığından oturumunuz sonlandırıldı.',
        ),
      ),
    );
  }

  Future<void> _afterSignIn() async {
    final s = await _session.loadAccountSecurity();
    final previous = s?['previousLogin'] as Map<String, dynamic>?;
    final failed = s?['lastFailedLogin'] as Map<String, dynamic>?;
    final failedSincePrevious =
        failed != null &&
        (previous == null ||
            (failed['atUtc'] as String).compareTo(previous['atUtc'] as String) >
                0);

    widget.messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hoş geldiniz',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                previous == null
                    ? 'Önceki giriş kaydınız bulunmuyor.'
                    : 'Son girişiniz: ${formatDateTime(previous['atUtc'] as String)}',
              ),
              if (failedSincePrevious)
                Text(
                  'Son başarısız deneme: ${formatDateTime(failed['atUtc'] as String)}',
                  style: const TextStyle(color: AppColors.warning),
                ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_session.isSignedIn && !_warning) _restart();
      },
      child: widget.child,
    );
  }
}

class _TimeoutDialog extends StatefulWidget {
  const _TimeoutDialog({required this.seconds});

  final int seconds;

  @override
  State<_TimeoutDialog> createState() => _TimeoutDialogState();
}

class _TimeoutDialogState extends State<_TimeoutDialog> {
  late int _left = widget.seconds;
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (_left <= 1) {
      Navigator.pop(context); // null: time ran out
    } else {
      setState(() => _left--);
    }
  });

  @override
  void initState() {
    super.initState();
    _tick; // start counting
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        // Center keeps the ring round; the dialog stretches its icon slot.
        icon: Center(
          heightFactor: 1,
          child: SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _left / _warningSeconds,
                  strokeWidth: 6,
                  color: _left <= 10 ? AppColors.danger : AppColors.warning,
                  backgroundColor: AppColors.surfaceHigh,
                ),
                Center(
                  child: Text(
                    '$_left',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        title: const Text(
          'Oturumunuz sonlanmak üzere',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Uzun süredir işlem yapmadınız. Güvenliğiniz için oturumunuz $_left saniye içinde kapatılacak.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Çıkış Yap'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_clock_rounded),
            label: const Text('Oturumu Uzat'),
          ),
        ],
      ),
    );
  }
}
