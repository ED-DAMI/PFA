// import 'package:flutter/foundation.dart'; // Pas utilisé directement ici
import 'package:intl/intl.dart'; // Décommentez si vous utilisez DateFormat pour releaseDate

// --- Helpers de Parsing ---
DateTime? _safeDateTimeParse(dynamic value) {
  if (value == null || !(value is String) || value.isEmpty) return null;
  // Essayer de parser avec plusieurs formats si nécessaire, ou s'attendre à un format ISO8601 standard
  // DateTime.tryParse est généralement bon pour les formats ISO8601 (ex: "2023-10-27T10:00:00Z")
  return DateTime.tryParse(value);
}

int _safeIntParse(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
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
  final DateTime? listenedAt; // Date/heure à laquelle la chanson a été écoutée (pour l'historique)
  final String? coverImageUrlPath; // Chemin relatif ou URL complète de l'image de couverture

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
    this.listenedAt,
    this.coverImageUrlPath,
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
      viewCount: _safeIntParse(json['viewCount'] ?? json['view_count']), // Gère les deux conventions de nommage
      commentCount: _safeIntParse(json['commentCount'] ?? json['comment_count']),
      totalReactionCount: _safeIntParse(json['totalReactionCount'] ?? json['total_reaction_count']),
      listenedAt: _safeDateTimeParse(json['listenedAt'] ?? json['listened_at'] ?? json['playedAt'] ?? json['played_at']), // Pour l'historique
      coverImageUrlPath: json['coverImageUrl'] as String? ?? json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'genre': genre,
      'duration': duration,
      'releaseDate': releaseDate?.toIso8601String(),
      'language': language,
      'tags': tags,
      'createdAt': createdAt?.toIso8601String(),
      'viewCount': viewCount,
      'commentCount': commentCount,
      'totalReactionCount': totalReactionCount,
      'listenedAt': listenedAt?.toIso8601String(),
      'coverImageUrl': coverImageUrlPath,
    };
  }


  // Getter pour l'URL complète de la couverture, si API_BASE_URL est disponible globalement
  // Assurez-vous d'importer votre fichier de configuration API si nécessaire
  // import 'package:pfa/config/api_config.dart'; // Exemple
  // String? get fullCoverUrl {
  //   if (coverImageUrlPath == null || coverImageUrlPath!.isEmpty) return null;
  //   if (coverImageUrlPath!.toLowerCase().startsWith('http')) {
  //     return coverImageUrlPath; // C'est déjà une URL complète
  //   }
  //   // Supposons que API_BASE_URL est défini quelque part
  //   // Exemple: final String API_BASE_URL = "http://localhost:8080";
  //   // Adaptez selon votre configuration
  //   // return '${API_BASE_URL}$coverImageUrlPath';
  //   return 'YOUR_API_BASE_URL_HERE$coverImageUrlPath'; // Remplacez par votre logique
  // }


  String get formattedPublicationDate {
    if (createdAt == null) return 'Date inconnue';
    // Utilisation de intl pour un formatage localisé serait mieux, mais pour un format simple :
    final day = createdAt!.day.toString().padLeft(2, '0');
    final month = createdAt!.month.toString().padLeft(2, '0');
    final year = createdAt!.year.toString();
    return '$day/$month/$year';
    // Avec intl:
    // return DateFormat.yMd(Platform.localeName).format(createdAt!); // Ou autre format souhaité
  }

  String get formattedReleaseDate {
    if (releaseDate == null) return 'Date de sortie inconnue';
    // Utilisation de intl pour un formatage localisé serait mieux
    return DateFormat.yMMMMd('fr_FR').format(releaseDate!); // Exemple pour '27 octobre 2023'
    // Ou plus simple :
    // final day = releaseDate!.day.toString().padLeft(2, '0');
    // final month = releaseDate!.month.toString().padLeft(2, '0');
    // final year = releaseDate!.year.toString();
    // return '$day/$month/$year';
  }

  String get formattedDuration {
    if (duration == null || duration! <= 0) return '--:--';
    final int minutes = duration! ~/ 60;
    final int seconds = duration! % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedViewCount {
    if (viewCount < 0) return '0';
    if (viewCount < 1000) return viewCount.toString();
    if (viewCount < 1000000) {
      double k = viewCount / 1000.0;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    double m = viewCount / 1000000.0;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
  }

  String get formattedListenedAt {
    if (listenedAt == null) return 'Jamais écouté';
    // Adaptez le format selon vos besoins, par exemple avec DateFormat de intl
    // return DateFormat('dd/MM/yy HH:mm').format(listenedAt!);
    // Ou un format plus relatif comme "il y a 5 minutes", "hier", etc. (nécessite une logique supplémentaire)
    final now = DateTime.now();
    final difference = now.difference(listenedAt!);

    if (difference.inSeconds < 60) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays == 1) return 'Hier';
    // Pour un format simple date/heure:
    final day = listenedAt!.day.toString().padLeft(2, '0');
    final month = listenedAt!.month.toString().padLeft(2, '0');
    final year = listenedAt!.year.toString().substring(2); // Juste les 2 derniers chiffres de l'année
    final hour = listenedAt!.hour.toString().padLeft(2, '0');
    final minute = listenedAt!.minute.toString().padLeft(2, '0');
    return 'Le $day/$month/$year à $hour:$minute';
  }


  @override
  String toString() {
    return 'Song(id: $id, title: "$title", artist: "$artist", duration: $formattedDuration, views: $viewCount, published: ${createdAt?.toIso8601String()})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  // Ce getter est un exemple. Vous devez le remplacer par la logique réelle
  // pour obtenir l'URL de l'image de couverture, potentiellement en utilisant API_BASE_URL.
  // Si coverImageUrlPath est déjà une URL complète, vous pouvez simplement la retourner.
  // String? get coverImageUrl {
  //   if (coverImageUrlPath == null || coverImageUrlPath!.isEmpty) return null;
  //   // Exemple si coverImageUrlPath est un chemin relatif et nécessite API_BASE_URL
  //   // Assurez-vous que API_BASE_URL est accessible ici (via import ou constante globale)
  //   // return '${API_BASE_URL}/api/songs/$id/cover'; // Si l'ID est utilisé pour construire l'URL
  //   // return '${API_BASE_URL}$coverImageUrlPath'; // Si coverImageUrlPath est le chemin relatif
  //   return coverImageUrlPath; // Si c'est déjà une URL complète ou si vous la construisez ailleurs
  // }


  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album, // Utiliser Object? pour permettre de passer explicitement null
    String? genre,
    int? duration,
    DateTime? releaseDate,
    String? language,
    List<String>? tags,
    DateTime? createdAt,
    int? viewCount,
    int? commentCount,
    int? totalReactionCount,
    DateTime? listenedAt,
    String? coverImageUrlPath,
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
      listenedAt: listenedAt ?? this.listenedAt,
      coverImageUrlPath: coverImageUrlPath ?? this.coverImageUrlPath,
    );
  }

  static Song empty() {
    return Song(
      id: '',
      title: '',
      artist: '',
      album: null, // Préférable à une chaîne vide pour un champ nullable
      genre: 'Genre Inconnu', // Ou '' si vous préférez
      duration: 0,
      releaseDate: null,
      language: null,
      tags: null,
      createdAt: null,
      viewCount: 0,
      commentCount: 0,
      totalReactionCount: 0,
      listenedAt: null,
      coverImageUrlPath: null,
    );
  }
}