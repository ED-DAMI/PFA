// lib/models/song.dart
// import 'package:flutter/foundation.dart'; // Pas utilisé directement ici
// import 'package:intl/intl.dart'; // Décommentez si vous utilisez DateFormat

// --- Helpers de Parsing ---
DateTime? _safeDateTimeParse(dynamic value) {
  if (value == null || !(value is String) || value.isEmpty) return null;
  return DateTime.tryParse(value);
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
  final int? viewCount;
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
    this.viewCount,
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
      commentCount: _safeIntParse(json['commentCount']) ?? 0,
      totalReactionCount: _safeIntParse(json['totalReactionCount']) ?? 0,
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
    if (viewCount == null || viewCount! < 0) return '0';
    if (viewCount! < 1000) return viewCount.toString();
    if (viewCount! < 1000000) return '${(viewCount! / 1000).toStringAsFixed(viewCount! % 1000 == 0 ? 0 : 1)}k';
    return '${(viewCount! / 1000000).toStringAsFixed(viewCount! % 1000000 == 0 ? 0 : 1)}M';
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
}