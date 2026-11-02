import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Shown to the user in their login history ("Giriş Geçmişim"). HTTP headers
/// must be ASCII, so no Turkish letters or "·" here.
final clientDevice =
    'Mobil uygulama - ${Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : Platform.operatingSystem}';

/// Supplies and renews the bearer token for [ApiClient].
abstract interface class TokenProvider {
  String? get accessToken;

  /// Gets a fresh access token after a 401. Returns false if the user must sign in again.
  Future<bool> refreshAccessToken();
}

/// Small JSON client for WebAppointment.Api. Errors come back from the API either as
/// plain text or as `{ "message": "..." }`; both become an [ApiException].
class ApiClient {
  ApiClient({required this.baseUrl, this.tokens});

  String baseUrl;
  TokenProvider? tokens;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool retried = false,
  }) async {
    final base = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');
    final uri = query == null ? base : base.replace(queryParameters: query);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set('X-Client-Device', clientDevice);
      final token = tokens?.accessToken;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await response.transform(utf8.decoder).join();

      if (response.statusCode == HttpStatus.unauthorized &&
          !retried &&
          token != null &&
          await tokens!.refreshAccessToken()) {
        return await _send(
          method,
          path,
          body: body,
          query: query,
          retried: true,
        );
      }
      if (response.statusCode >= 400) {
        throw ApiException(
          _errorText(text, response.statusCode),
          response.statusCode,
        );
      }
      if (text.isEmpty) return null;
      try {
        return jsonDecode(text);
      } on FormatException {
        return text;
      }
    } on SocketException {
      throw ApiException(
        'Sunucuya bağlanılamadı. API çalışıyor mu? ($baseUrl)',
      );
    } on TimeoutException {
      throw ApiException('Sunucu yanıt vermedi.');
    } finally {
      client.close(force: true);
    }
  }

  static String _errorText(String body, int status) {
    if (body.isNotEmpty) {
      try {
        final json = jsonDecode(body);
        if (json is Map) {
          final message = json['message'] ?? json['title'] ?? json['error'];
          if (message != null) return message.toString();
        }
      } on FormatException {
        return body;
      }
    }
    return switch (status) {
      401 => 'Oturum açmanız gerekiyor.',
      403 => 'Bu işlemi yapma izniniz yok.',
      404 => 'Kayıt bulunamadı.',
      _ => 'İstek başarısız oldu (HTTP $status).',
    };
  }
}
