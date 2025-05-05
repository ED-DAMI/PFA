// lib/models/song.dart
import 'package:flutter/foundation.dart';

// --- Helpers de Parsing (placés ici pour la clarté, peuvent être dans un fichier utilitaire) ---
DateTime? _safeDateTimeParse(String? dateString) {
  if (dateString == null || dateString.isEmpty) return null;
  return DateTime.tryParse(dateString);
}

int? _safeIntParse(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

List<String>? _safeListStringParse(dynamic value) {
  if (value is List) {
    return value.map((item) => item?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  return null;
}
// --- Fin Helpers ---


class Song {
  final String id;
  final String title;
  final String artist; // Nom/ID Artiste
  final String? album;
  final String genre;  // Nom/ID Genre
  final int? duration; // En secondes?
  final DateTime? releaseDate;
  final String? language;
  final List<String>? tags;
  // final String? lyrics; // Peut être omis du modèle de liste si non utilisé
  final DateTime? createdAt;

  // --- PAS DE urlAudio ou coverImage ici ---

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.genre,
    this.duration,
    this.releaseDate,
    this.language,
    this.tags,
    this.createdAt,
  });

  // Factory pour créer depuis le JSON du SongListDto du backend
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? 'unknown_id_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Titre Inconnu',
      artist: json['artist']?.toString() ?? 'Artiste Inconnu', // Adapter si objets complexes
      album: json['album'] as String?,
      genre: json['genre']?.toString() ?? 'Genre Inconnu', // Adapter si objets complexes
      duration: _safeIntParse(json['duration']),
      releaseDate: _safeDateTimeParse(json['releaseDate'] as String?),
      language: json['language'] as String?,
      tags: _safeListStringParse(json['tags']),
      // lyrics: json['lyrics'] as String?, // Exclu par défaut
      createdAt: _safeDateTimeParse(json['createdAt'] as String?),
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, title: "$title", artist: "$artist")';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}