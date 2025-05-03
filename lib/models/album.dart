import 'package:flutter/foundation.dart';

class Album {
  final String id;
  final String title;
  final String artistId; // Référence à l'ID de l'artiste
  final DateTime? releaseDate; // La date peut être optionnelle
  final String? coverImage; // L'URL de la couverture peut être optionnelle

  Album({
    required this.id,
    required this.title,
    required this.artistId,
    this.releaseDate,
    this.coverImage,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      title: json['title'] as String,
      artistId: json['artistId'] as String,
      releaseDate: json['releaseDate'] == null
          ? null
          : DateTime.tryParse(json['releaseDate'] as String),
      coverImage: json['coverImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artistId': artistId,
      'releaseDate': releaseDate?.toIso8601String(),
      'coverImage': coverImage,
    };
  }

  @override
  String toString() {
    return 'Album(id: $id, title: $title, artistId: $artistId)';
  }
}