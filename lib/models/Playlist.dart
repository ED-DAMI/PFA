// lib/models/playlist.dart
class Playlist {
  final String id;
  final String name;
  final String ownerId; // ID de l'utilisateur propriétaire
  final List<String> songIds; // Liste des IDs des chansons dans la playlist
  final String? description;
  final String? coverImageUrl; // Optionnel: URL de l'image de couverture
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.songIds,
    this.description,
    this.coverImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory fromJson (à adapter à votre API)
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? 'error_playlist_id',
      name: json['name'] as String? ?? 'Playlist sans nom',
      ownerId: json['ownerId']?.toString() ?? '',
      // Gérer le parsing de la liste d'IDs de chansons
      songIds: (json['songIds'] as List<dynamic>?)
          ?.map((id) => id?.toString())
          .whereType<String>()
          .toList() ??
          [],
      description: json['description'] as String?,
      coverImageUrl: json['coverImageUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // Méthode copyWith (utile pour les mises à jour)
  Playlist copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? songIds,
    String? description,
    String? coverImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      songIds: songIds ?? this.songIds,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}