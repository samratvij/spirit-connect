class MemoryRecord {
  final int id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsed;

  const MemoryRecord({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsed,
  });

  factory MemoryRecord.fromJson(Map<String, dynamic> json) {
    return MemoryRecord(
      id: json['id'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'] as String)
          : null,
    );
  }

  MemoryRecord copyWith({String? content}) {
    return MemoryRecord(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUsed: lastUsed,
    );
  }
}
