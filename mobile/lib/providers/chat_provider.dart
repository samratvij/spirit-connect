import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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
  final int? activeConversationId;
  final List<String> pendingAttachments;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.activeConversationId,
    this.pendingAttachments = const [],
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    int? activeConversationId,
    List<String>? pendingAttachments,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      pendingAttachments: pendingAttachments ?? this.pendingAttachments,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState()) {
    print('ChatNotifier initialized');
  }

  Future<void> loadConversation(int conversationId) async {
    state = state.copyWith(isLoading: true, error: null, messages: [], activeConversationId: conversationId);
    try {
      final rawJson = await apiService.getConversationMessages(conversationId);
      final list = rawJson.map((j) => ChatMessage.fromJson(j)).toList();
      state = state.copyWith(messages: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  CancelToken? _activeCancelToken;

  Future<void> sendMessage(String text, {String? model}) async {
    if (text.trim().isEmpty && state.pendingAttachments.isEmpty) return;

    final List<String> b64Images = [];
    String textContent = text.trim();

    // Process attachments
    for (final path in state.pendingAttachments) {
      final file = File(path);
      if (!await file.exists()) continue;

      final ext = path.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
        final bytes = await file.readAsBytes();
        b64Images.add(base64Encode(bytes));
      } else {
        // Assume text-based file for now
        try {
          final content = await file.readAsString();
          final fileName = path.split('/').last;
          textContent += '\n\n---\n[Attached File: $fileName]\n$content\n---';
        } catch (e) {
          // Skip
        }
      }
    }

    final userMsg = ChatMessage(
      role: 'user', 
      content: textContent,
      images: b64Images.isNotEmpty ? b64Images : null,
    );
    final updatedMessages = [...state.messages, userMsg];

    // Add placeholder for streaming assistant response
    final assistantPlaceholder = ChatMessage(
      role: 'assistant',
      content: '',
      isStreaming: true,
    );

    _activeCancelToken = CancelToken();

    state = state.copyWith(
      messages: [...updatedMessages, assistantPlaceholder],
      isLoading: true,
      error: null,
      pendingAttachments: [], // Clear local list immediately after processing
    );

    final buffer = StringBuffer();

    try {
      final stream = apiService.streamChat(
        updatedMessages, 
        model: model,
        conversationId: state.activeConversationId,
        cancelToken: _activeCancelToken,
      );

      await for (final delta in stream) {
        buffer.write(delta);
        
        final currentMessages = [...state.messages];
        if (currentMessages.isNotEmpty && currentMessages.last.isStreaming) {
          currentMessages[currentMessages.length - 1] = ChatMessage(
            role: 'assistant',
            content: buffer.toString(),
            isStreaming: true,
          );
        }
        state = state.copyWith(messages: currentMessages);
      }

      // Mark streaming complete
      final finalizedMessages = [...state.messages];
      if (finalizedMessages.isNotEmpty && finalizedMessages.last.isStreaming) {
        finalizedMessages[finalizedMessages.length - 1] = ChatMessage(
          role: 'assistant',
          content: buffer.toString(),
          isStreaming: false,
        );
      }
      state = state.copyWith(
        messages: finalizedMessages, 
        isLoading: false,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // Interrupted by user
        final currentMessages = [...state.messages];
        if (currentMessages.isNotEmpty && currentMessages.last.isStreaming) {
          currentMessages[currentMessages.length - 1] = ChatMessage(
            role: 'assistant',
            content: buffer.toString() + ' [Interrupted]',
            isStreaming: false,
          );
        }
        state = state.copyWith(messages: currentMessages, isLoading: false);
      } else {
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
    } finally {
      _activeCancelToken = null;
    }
  }

  void stopResponse() {
    _activeCancelToken?.cancel();
  }

  void startNewChat(int? conversationId) {
    state = ChatState(activeConversationId: conversationId, pendingAttachments: state.pendingAttachments);
  }

  void clearConversation() {
    state = ChatState(activeConversationId: state.activeConversationId, pendingAttachments: state.pendingAttachments);
  }

  void addAttachment(String path) {
    print('Adding attachment: $path');
    if (!state.pendingAttachments.contains(path)) {
      state = state.copyWith(
        pendingAttachments: [...state.pendingAttachments, path],
      );
      print('New pendingAttachments count: ${state.pendingAttachments.length}');
    } else {
      print('Attachment already exists: $path');
    }
  }

  void removeAttachment(String path) {
    print('Removing attachment: $path');
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments.where((p) => p != path).toList(),
    );
    print('New pendingAttachments count: ${state.pendingAttachments.length}');
  }

  void clearAttachments() {
    state = state.copyWith(pendingAttachments: []);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(),
);
