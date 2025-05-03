// lib/models/playlist.dart
class Playlist {
  final String id;
  final String name;
  final String description;
  final int songCount;

  Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.songCount,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      songCount: json['songCount'] ?? 0,
    );
  }
  get imageUrl => null;

  get songs => null;
}

// Vous aurez besoin de modèles similaires pour Song, Artist, Album, User, etc.
// Pensez à utiliser json_serializable pour les modèles complexes afin de générer automatiquement les méthodes fromJson/toJson.