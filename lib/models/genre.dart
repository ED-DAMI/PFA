import 'package:flutter/foundation.dart';

class Genre {
  final String id;
  final String name;
  final String? description; // La description peut être optionnelle

  Genre({
    required this.id,
    required this.name,
    this.description,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'Genre(id: $id, name: $name)';
  }
}