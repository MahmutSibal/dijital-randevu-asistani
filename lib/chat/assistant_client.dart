import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

export '../core/config.dart' show defaultApiBaseUrl;

class ChatMessage {
  ChatMessage({
    required this.role,
    this.content = '',
    this.thinking = '',
    this.images = const [],
  });

  final String role; // 'user' | 'assistant'
  String content;
  String thinking;

  /// Photos attached to a user message (JPEG bytes).
  final List<Uint8List> images;

  /// The answer was reused from the database instead of generated now.
  bool fromCache = false;

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (images.isNotEmpty) 'images': images.map(base64Encode).toList(),
  };
}

/// One streamed piece of an assistant reply.
class ChatChunk {
  const ChatChunk({
    this.thinking = '',
    this.content = '',
    this.done = false,
    this.cached = false,
  });

  final String thinking;
  final String content;
  final bool done;
  final bool cached;
}

class AssistantException implements Exception {
  AssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the backend's `/api/assistant` endpoints. The backend forwards
/// the conversation to the AI model and streams the reply back as NDJSON.
class AssistantClient {
  AssistantClient({required this.baseUrl});

  String baseUrl;
  HttpClient? _activeClient;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  /// Name of the model the backend answers with.
  Future<String> fetchModel() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final response = await (await client.getUrl(_uri('/api/assistant')))
          .close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != HttpStatus.ok) throw AssistantException(body);
      return (jsonDecode(body) as Map<String, dynamic>)['model'] as String? ??
          '';
    } on SocketException catch (e) {
      throw AssistantException(
        'Sunucuya bağlanılamadı ($baseUrl): ${e.message}',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Streams a reply with the model's reasoning. [history] is the full
  /// conversation so far, ending with the latest user message.
  ///
  /// [think] lets the model reason first (streamed as `thinking`): better on hard
  /// questions but takes about a minute instead of a few seconds.
  Stream<ChatChunk> chat(
    List<ChatMessage> history, {
    bool think = false,
  }) async* {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _activeClient = client;
    try {
      final request = await client.postUrl(_uri('/api/assistant/chat'));
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'messages': history.map((m) => m.toJson()).toList(),
            'think': think,
          }),
        ),
      );
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        // The backend sends errors as plain text.
        final body = await response.transform(utf8.decoder).join();
        throw AssistantException(
          body.isEmpty ? 'HTTP ${response.statusCode}' : body,
        );
      }

      final lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['error'] != null) {
          throw AssistantException(json['error'].toString());
        }
        yield ChatChunk(
          thinking: json['thinking'] as String? ?? '',
          content: json['content'] as String? ?? '',
          done: json['done'] == true,
          cached: json['cached'] == true,
        );
      }
    } on SocketException catch (e) {
      throw AssistantException(
        'Sunucuya bağlanılamadı ($baseUrl): ${e.message}',
      );
    } finally {
      client.close(force: true);
      if (identical(_activeClient, client)) _activeClient = null;
    }
  }

  /// Aborts the in-flight request, if any.
  void cancel() {
    _activeClient?.close(force: true);
    _activeClient = null;
  }
}
