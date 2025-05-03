import 'package:flutter/foundation.dart';

class Artist {
  final String id;
  final String name;
  final String? bio; // La biographie peut être optionnelle
  final String? photoUrl; // L'URL de la photo peut être optionnelle

  Artist({
    required this.id,
    required this.name,
    this.bio,
    this.photoUrl,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'photoUrl': photoUrl,
    };
  }

  @override
  String toString() {
    return 'Artist(id: $id, name: $name)';
  }
}