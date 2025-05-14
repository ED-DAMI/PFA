// import 'package:flutter/foundation.dart'; // Pas utilisé directement ici
// import 'package:intl/intl.dart'; // Décommentez si vous utilisez DateFormat

// --- Helpers de Parsing ---
DateTime? _safeDateTimeParse(dynamic value) {
  if (value == null || !(value is String) || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int _safeIntParse(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String)
  {
    var valueCapture =int.tryParse(value);
    if(valueCapture!=null) return valueCapture;
    return 0;
  }
  if (value is double) return value.toInt();
  return 0;
}

List<String>? _safeListStringParse(dynamic value) {
  if (value is List) {
    return value.map((item) => item?.toString()).whereType<String>().toList();
  }
  return null;
}
// --- Fin Helpers ---

class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String genre;
  final int? duration; // En secondes
  final DateTime? releaseDate;
  final String? language;
  final List<String>? tags;
  final DateTime? createdAt; // Date de publication sur la plateforme
  final int viewCount;
  final int commentCount;
  final int totalReactionCount;

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
    required this.viewCount,
    required this.commentCount,
    required this.totalReactionCount,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id']?.toString() ?? 'unknown_id_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Titre Inconnu',
      artist: json['artist']?.toString() ?? 'Artiste Inconnu',
      album: json['album'] as String?,
      genre: json['genre']?.toString() ?? 'Genre Inconnu',
      duration: _safeIntParse(json['duration']),
      releaseDate: _safeDateTimeParse(json['releaseDate']),
      language: json['language'] as String?,
      tags: _safeListStringParse(json['tags']),
      createdAt: _safeDateTimeParse(json['createdAt']),
      viewCount: _safeIntParse(json['viewCount']),
      commentCount: _safeIntParse(json['commentCount']), // Redundant ?? 0 removed
      totalReactionCount: _safeIntParse(json['totalReactionCount']), // Redundant ?? 0 removed
    );
  }

  String get formattedPublicationDate {
    if (createdAt == null) return 'Date inconnue';
    final day = createdAt!.day.toString().padLeft(2, '0');
    final month = createdAt!.month.toString().padLeft(2, '0');
    final year = createdAt!.year.toString();
    return '$day/$month/$year';
  }

  String get formattedDuration {
    if (duration == null || duration! <= 0) return '--:--';
    final int minutes = duration! ~/ 60;
    final int seconds = duration! % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedViewCount {
    if (viewCount < 0) return '0'; // Simplified null check as _safeIntParse defaults to 0
    if (viewCount < 1000) return viewCount.toString();
    if (viewCount < 1000000) return '${(viewCount / 1000).toStringAsFixed(viewCount % 1000 == 0 ? 0 : 1)}k';
    return '${(viewCount / 1000000).toStringAsFixed(viewCount % 1000000 == 0 ? 0 : 1)}M';
  }

  @override
  String toString() {
    return 'Song(id: $id, title: "$title", artist: "$artist", published: ${createdAt?.toIso8601String()}, views: $viewCount, comments: $commentCount, reactions: $totalReactionCount)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  get coverImageUrl => null;


  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? genre,
    int? duration,
    DateTime? releaseDate,
    String? language,
    List<String>? tags,
    DateTime? createdAt,
    int? viewCount,
    int? commentCount,
    int? totalReactionCount,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      totalReactionCount: totalReactionCount ?? this.totalReactionCount,
    );
  }
}