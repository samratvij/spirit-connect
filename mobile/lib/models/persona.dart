class Persona {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String? modelName; // null means use server default

  const Persona({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.modelName,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      modelName: json['modelName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'modelName': modelName,
    };
  }
}
