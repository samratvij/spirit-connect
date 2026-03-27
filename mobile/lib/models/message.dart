class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isStreaming;
  final List<String>? images;

  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.images,
  });

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    List<String>? images,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (images != null) 'images': images,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      isStreaming: false,
      images: json['images'] != null ? List<String>.from(json['images']) : null,
    );
  }
}
