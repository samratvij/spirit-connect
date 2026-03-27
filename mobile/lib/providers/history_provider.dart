import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/persona.dart';
import '../services/api_service.dart';

class Conversation {
  final int id;
  final String personaId;
  final String? title;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.personaId,
    this.title,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      personaId: json['persona_id'],
      title: json['title'],
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class HistoryState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  HistoryState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  HistoryState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return HistoryState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(HistoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await apiService.getConversations();
      state = state.copyWith(
        conversations: list.map((j) => Conversation.fromJson(j)).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Conversation> create(String personaId, String? title) async {
    final json = await apiService.createConversation(personaId, title);
    final conv = Conversation.fromJson(json);
    state = state.copyWith(conversations: [conv, ...state.conversations]);
    return conv;
  }

  Future<void> delete(int id) async {
    try {
      await apiService.deleteConversation(id);
      state = state.copyWith(
        conversations: state.conversations.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
