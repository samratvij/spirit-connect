class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isStreaming;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
