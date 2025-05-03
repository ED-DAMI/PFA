// lib/models/song.dart
import 'package:flutter/foundation.dart'; // Pour required si nécessaire

class Song {
  final String id;
  final String title;
  final String artist; // <-- Champ artiste (String)
  final String genre;  // <-- Champ genre (String)
  final String? album;
  final String urlAudio;
  final String? coverImage;
  final DateTime? releaseDate;
  final int? duration;
  final String? language;
  final List<String>? tags;
  final String? lyrics;
  final DateTime? createdAt;

  Song({
    required this.id,
    required this.title,
    required this.artist, // <-- Utilise artist
    required this.genre,  // <-- Utilise genre
    this.album,
    required this.urlAudio,
    this.coverImage,
    this.releaseDate,
    this.duration,
    this.language,
    this.tags,
    this.lyrics,
    this.createdAt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    // Helper pour parser la date sans erreur
    DateTime? safeDateTimeParse(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      return DateTime.tryParse(dateString);
    }

    // Helper pour caster en int sans erreur
    int? safeIntParse(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null; // ou une valeur par défaut si pertinent
    }


    return Song(
      id: json['id']?.toString() ?? 'unknown_id_${DateTime.now().millisecondsSinceEpoch}', // Fournir un ID unique si null
      title: json['title'] as String? ?? 'Titre inconnu', // Default title plus logique
      artist: json['artist'] as String? ?? 'Artiste inconnu', // <-- Utilise artist
      genre: json['genre'] as String? ?? 'Genre inconnu',   // <-- Utilise genre
      album: json['album'] as String?,
      urlAudio: json['urlAudio'] as String? ?? '', // Fournir chaîne vide si null
      coverImage: json['coverImage'] as String?,
      releaseDate: safeDateTimeParse(json['releaseDate'] as String?),
      duration: safeIntParse(json['duration']),
      language: json['language'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      lyrics: json['lyrics'] as String?,
      createdAt: safeDateTimeParse(json['createdAt'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    // print("toJson pour: " + title); // Décommenter pour débugger si besoin
    return {
      'id': id,
      'title': title,
      'artist': artist, // <-- Utilise artist
      'genre': genre,   // <-- Utilise genre
      'album': album,
      'urlAudio': urlAudio,
      'coverImage': coverImage,
      'releaseDate': releaseDate?.toIso8601String(),
      'duration': duration,
      'language': language,
      'tags': tags,
      'lyrics': lyrics,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist)';
  }
}