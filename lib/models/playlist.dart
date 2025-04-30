// lib/models/playlist.dart
class Playlist {
  final String id;
  final String name;
  final String description;
  final int songCount; // Ou un autre champ pertinent

  Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.songCount,
  });

  // Factory constructor pour créer une instance Playlist depuis un Map JSON
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String, // Assurez-vous que les types correspondent !
      name: json['name'] as String,
      description: json['description'] as String,
      songCount: json['songCount'] as int,
    );
  }
}

// Vous aurez besoin de modèles similaires pour Song, Artist, Album, User, etc.
// Pensez à utiliser json_serializable pour les modèles complexes afin de générer automatiquement les méthodes fromJson/toJson.