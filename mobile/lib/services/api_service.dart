import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/memory.dart';
import '../models/message.dart';

class ApiService {
  static const _baseUrlKey = 'server_base_url';
  static const _apiKeyKey = 'api_key';

  final _storage = const FlutterSecureStorage();
  Dio? _dio;

  // -------------------------------------------------------------------------
  // Configuration
  // -------------------------------------------------------------------------

  Future<String?> getBaseUrl() => _storage.read(key: _baseUrlKey);
  Future<String?> getApiKey() => _storage.read(key: _apiKeyKey);

  Future<void> saveSettings({
    required String baseUrl,
    required String apiKey,
  }) async {
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: baseUrl.trimRight().replaceAll(RegExp(r'/$'), '')),
      _storage.write(key: _apiKeyKey, value: apiKey.trim()),
    ]);
    _dio = null; // reset client
  }

  Future<bool> hasSettings() async {
    final url = await getBaseUrl();
    final key = await getApiKey();
    return url != null && url.isNotEmpty && key != null && key.isNotEmpty;
  }

  Future<Dio> _client() async {
    if (_dio != null) return _dio!;
    final baseUrl = await getBaseUrl() ?? '';
    final apiKey = await getApiKey() ?? '';
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Authorization': 'Bearer $apiKey'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
    ));
    return _dio!;
  }

  // -------------------------------------------------------------------------
  // Health check
  // -------------------------------------------------------------------------

  Future<bool> testConnection() async {
    try {
      final client = await _client();
      final response = await client.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Chat (streaming SSE)
  // -------------------------------------------------------------------------

  /// Streams token deltas from /chat.
  /// Yields each delta string as it arrives.
  Stream<String> streamChat(
    List<ChatMessage> messages, {
    String? model,
    int? conversationId,
    CancelToken? cancelToken,
  }) async* {
    final client = await _client();

    final response = await client.post<ResponseBody>(
      '/chat',
      data: {
        'messages': messages.map((m) => m.toJson()).toList(),
        'model': model,
        'conversation_id': conversationId,
      },
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data!.stream;

    await for (final chunk in stream) {
      final raw = utf8.decode(chunk);
      final lines = raw.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final payload = line.substring(6).trim();
          if (payload == '[DONE]') return;
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            if (json.containsKey('error')) {
              throw Exception(json['error']);
            }
            final delta = json['delta'] as String? ?? '';
            if (delta.isNotEmpty) yield delta;
          } catch (e) {
            if (e is Exception) rethrow;
            // Malformed line — skip
          }
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Conversations & History
  // -------------------------------------------------------------------------

  Future<List<dynamic>> getConversations() async {
    final client = await _client();
    final response = await client.get<List>('/conversations');
    return response.data ?? [];
  }

  Future<Map<String, dynamic>> createConversation(String personaId, String? title) async {
    final client = await _client();
    final response = await client.post<Map<String, dynamic>>(
      '/conversations',
      data: {'persona_id': personaId, 'title': title},
    );
    return response.data!;
  }

  Future<List<dynamic>> getConversationMessages(int id) async {
    final client = await _client();
    final response = await client.get<List>('/conversations/$id/messages');
    return response.data ?? [];
  }

  // -------------------------------------------------------------------------
  // Memory CRUD
  // -------------------------------------------------------------------------

  Future<List<MemoryRecord>> fetchMemories() async {
    final client = await _client();
    final response = await client.get<List>('/memory');
    return (response.data ?? [])
        .map((e) => MemoryRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MemoryRecord> createMemory(String content) async {
    final client = await _client();
    final response = await client.post<Map<String, dynamic>>(
      '/memory',
      data: {'content': content},
    );
    return MemoryRecord.fromJson(response.data!);
  }

  Future<MemoryRecord> updateMemory(int id, String content) async {
    final client = await _client();
    final response = await client.put<Map<String, dynamic>>(
      '/memory/$id',
      data: {'content': content},
    );
    return MemoryRecord.fromJson(response.data!);
  }

  Future<void> deleteMemory(int id) async {
    final client = await _client();
    await client.delete('/memory/$id');
  }

  Future<void> deleteConversation(int id) async {
    final client = await _client();
    await client.delete('/conversations/$id');
  }
}

// Singleton
final apiService = ApiService();
