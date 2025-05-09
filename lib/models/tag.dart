class Tag {
  final String id;
  final String name;


  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Unknown Tag',
    );
  }

  // Utile pour les comparaisons dans les listes, Set, etc.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Tag && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}