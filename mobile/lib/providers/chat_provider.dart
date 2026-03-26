import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(role: 'user', content: text.trim());
    final updatedMessages = [...state.messages, userMsg];

    // Add placeholder for streaming assistant response
    final assistantPlaceholder = ChatMessage(
      role: 'assistant',
      content: '',
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...updatedMessages, assistantPlaceholder],
      isLoading: true,
      error: null,
    );

    final buffer = StringBuffer();

    try {
      await for (final delta in apiService.streamChat(updatedMessages)) {
        buffer.write(delta);
        final currentMessages = [...state.messages];
        currentMessages[currentMessages.length - 1] = assistantPlaceholder.copyWith(
          content: buffer.toString(),
          isStreaming: true,
        );
        state = state.copyWith(messages: currentMessages, isLoading: true);
      }

      // Mark streaming complete
      final currentMessages = [...state.messages];
      currentMessages[currentMessages.length - 1] = ChatMessage(
        role: 'assistant',
        content: buffer.toString(),
        isStreaming: false,
      );
      state = state.copyWith(messages: currentMessages, isLoading: false);

    } catch (e) {
      final currentMessages = [...state.messages];
      if (currentMessages.isNotEmpty &&
          currentMessages.last.role == 'assistant' &&
          currentMessages.last.isStreaming) {
        currentMessages.removeLast();
      }
      state = state.copyWith(
        messages: currentMessages,
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearConversation() {
    state = const ChatState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(),
);
