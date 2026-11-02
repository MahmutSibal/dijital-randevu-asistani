import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'config.dart';

enum UserRole {
  patient('Patient', 'Hasta', '/api/auth/patient/login'),
  doctor('Doctor', 'Doktor', '/api/auth/doctor/login'),
  hospitalAdmin(
    'HospitalAdmin',
    'Hastane Yöneticisi',
    '/api/auth/hospital-admin/login',
  ),
  admin('Admin', 'Sistem Yöneticisi', '/api/auth/admin/login');

  const UserRole(this.apiName, this.label, this.loginPath);

  /// Role name as the API returns it.
  final String apiName;
  final String label;
  final String loginPath;

  static UserRole? fromApi(String? name) {
    for (final role in values) {
      if (role.apiName.toLowerCase() == name?.toLowerCase()) return role;
    }
    return null;
  }
}

class EmailVerificationRequired implements Exception {}

/// The password was right; finish with [Session.verifyTwoFactor] and the code sent to the phone.
class TwoFactorRequired implements Exception {
  TwoFactorRequired(Map<String, dynamic> j)
    : challengeId = j['challengeId'] as String,
      maskedPhone = j['maskedPhone'] as String? ?? '',
      devCode = j['devCode'] as String?;

  final String challengeId;
  final String maskedPhone;

  /// Only sent by a Development API, where no SMS goes out.
  final String? devCode;
}

/// The signed-in user, persisted across app restarts. Listen to it to react to
/// sign-in and sign-out.
class Session extends ChangeNotifier implements TokenProvider {
  Session() {
    api = ApiClient(baseUrl: defaultApiBaseUrl, tokens: this);
  }

  static const _keyAccess = 'session.access';
  static const _keyRefresh = 'session.refresh';
  static const _keyRole = 'session.role';
  static const _keyEmail = 'session.email';
  static const _keyName = 'session.name';

  late final ApiClient api;

  final _signIns = StreamController<void>.broadcast();

  /// Fires after the user signs in or registers (not on token refresh or restore).
  Stream<void> get signIns => _signIns.stream;

  @override
  String? accessToken;
  String? _refreshToken;
  UserRole? role;
  String? email;

  /// What to greet the user with: a patient's name or the account's e-mail.
  String? displayName;

  bool get isSignedIn => accessToken != null && role != null;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      accessToken = prefs.getString(_keyAccess);
      _refreshToken = prefs.getString(_keyRefresh);
      role = UserRole.fromApi(prefs.getString(_keyRole));
      email = prefs.getString(_keyEmail);
      displayName = prefs.getString(_keyName);
    } catch (_) {
      // A broken preferences store just means starting signed out.
    }
    notifyListeners();
    // Sessions saved before names were fetched still show the e-mail.
    if (isSignedIn && role == UserRole.patient && !hasName) {
      unawaited(loadPatientName());
    }
  }

  /// [identifier] is the T.C. Kimlik No for patients and the e-mail for everyone else.
  /// Throws [EmailVerificationRequired] when a staff account must first confirm its
  /// e-mail; the API has then just sent a code to that address.
  Future<void> signIn(UserRole as, String identifier, String password) async {
    final body = as == UserRole.patient
        ? {'tcKimlikNo': identifier.trim(), 'password': password}
        : {'email': identifier.trim(), 'password': password};
    try {
      final response =
          await api.post(as.loginPath, body) as Map<String, dynamic>;
      if (response['twoFactorRequired'] == true) {
        throw TwoFactorRequired(response);
      }
      await _accept(response);
      _signIns.add(null);
    } on ApiException catch (e) {
      if (e.statusCode == 403 && e.message.contains('EMAIL_NOT_VERIFIED')) {
        throw EmailVerificationRequired();
      }
      rethrow;
    }
  }

  /// Second step of a patient sign-in after [TwoFactorRequired].
  Future<void> verifyTwoFactor(String challengeId, String code) async {
    final response = await api.post('/api/auth/patient/login/verify-code', {
      'challengeId': challengeId,
      'code': code.trim(),
    }) as Map<String, dynamic>;
    await _accept(response);
    _signIns.add(null);
  }

  /// Completes a staff sign-in with the code e-mailed by [signIn].
  Future<void> confirmEmail(String email, String password, String code) async {
    final response = await api.post('/api/auth/email-verification/confirm', {
      'email': email.trim(),
      'password': password,
      'code': code.trim(),
    }) as Map<String, dynamic>;
    await _accept(response);
    _signIns.add(null);
  }

  Future<void> resendEmailCode(String email, String password) => api.post(
    '/api/auth/email-verification/request-code',
    {'email': email.trim(), 'password': password},
  );

  Future<void> registerPatient({
    required String tcKimlikNo,
    required String firstName,
    required String lastName,
    required String phone,
    required DateTime birthDate,
    required String password,
  }) async {
    final response = await api.post('/api/auth/patient/register', {
      'tcKimlikNo': tcKimlikNo.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone.trim(),
      'birthDate': formatDate(birthDate),
      'password': password,
    }) as Map<String, dynamic>;
    await _accept(response, name: '${firstName.trim()} ${lastName.trim()}');
    _signIns.add(null);
  }

  Future<void> signOut() async {
    final refresh = _refreshToken;
    if (refresh != null) {
      try {
        await api.post('/api/auth/logout', {'refreshToken': refresh});
      } catch (_) {
        // Signing out locally is what matters; the token expires on its own.
      }
    }
    await _clear();
  }

  @override
  Future<bool> refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final response = await ApiClient(baseUrl: api.baseUrl).post(
        '/api/auth/refresh',
        {'refreshToken': refresh},
      ) as Map<String, dynamic>;
      await _accept(response, name: displayName);
      return true;
    } catch (_) {
      await _clear();
      return false;
    }
  }

  Future<void> _accept(Map<String, dynamic> response, {String? name}) async {
    final newRole = UserRole.fromApi(response['role'] as String?);
    if (newRole == null) {
      throw ApiException('Bilinmeyen kullanıcı rolü: ${response['role']}');
    }
    accessToken = response['accessToken'] as String?;
    _refreshToken = response['refreshToken'] as String?;
    role = newRole;
    email = response['email'] as String?;
    displayName = name ?? email;
    await _save();
    notifyListeners();
    if (newRole == UserRole.patient && name == null) await loadPatientName();
  }

  /// Sign-in only returns an e-mail; look up the patient's real name to greet them with.
  Future<void> loadPatientName() async {
    try {
      final me = await api.get('/api/patient/me') as Map<String, dynamic>;
      final full = '${me['firstName'] ?? ''} ${me['lastName'] ?? ''}'.trim();
      if (full.isEmpty) return;
      displayName = full;
      await _save();
      notifyListeners();
    } catch (_) {
      // Keep the e-mail as the display name.
    }
  }

  /// True once the API says the user has not accepted the current KVKK disclosure.
  bool needsKvkk = false;
  String? _kvkkVersion;

  /// Login history and KVKK state from /api/account/security; null if it couldn't be loaded.
  Future<Map<String, dynamic>?> loadAccountSecurity() async {
    try {
      final s = await api.get('/api/account/security') as Map<String, dynamic>;
      final kvkk = s['kvkk'] as Map<String, dynamic>;
      _kvkkVersion = kvkk['currentVersion'] as String?;
      needsKvkk = kvkk['isUpToDate'] != true;
      notifyListeners();
      return s;
    } catch (_) {
      return null;
    }
  }

  Future<void> acceptKvkk() async {
    await api.post('/api/account/kvkk', {'version': _kvkkVersion});
    needsKvkk = false;
    notifyListeners();
  }

  /// True when [displayName] is a real name rather than the account e-mail.
  bool get hasName => displayName != null && !displayName!.contains('@');

  Future<void> _clear() async {
    accessToken = null;
    _refreshToken = null;
    role = null;
    email = null;
    displayName = null;
    needsKvkk = false;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Future<void> put(String key, String? value) =>
          value == null ? prefs.remove(key) : prefs.setString(key, value);
      await put(_keyAccess, accessToken);
      await put(_keyRefresh, _refreshToken);
      await put(_keyRole, role?.apiName);
      await put(_keyEmail, email);
      await put(_keyName, displayName);
    } catch (_) {
      // Not persisting only means signing in again next launch.
    }
  }
}

/// Makes the [Session] available to the widget tree and rebuilds dependents when it changes.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({
    super.key,
    required Session session,
    required super.child,
  }) : super(notifier: session);

  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Reads the session without rebuilding when it changes (for callbacks).
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
