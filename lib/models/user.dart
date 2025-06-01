import 'package:flutter/foundation.dart';
import 'package:pfa/config/api_config.dart'; // Pour @override et potentiellement kDebugMode

// Helper local pour parser les dates de manière sûre
DateTime? _safeDateTimeParse(dynamic value) {
  if (value == null || !(value is String) || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Représente un utilisateur de l'application.
class User {
  /// L'identifiant unique de l'utilisateur (provenant de l'API).
  final String id;

  /// L'adresse e-mail de l'utilisateur.
  final String email;

  /// Le nom d'affichage de l'utilisateur (peut être un nom d'utilisateur ou un nom réel).
  final String name;

  /// L'URL de l'image de profil (avatar) de l'utilisateur. Peut être null.
  final String? avatarUrl;

  /// La date à laquelle l'utilisateur a rejoint la plateforme. Peut être null.
  final DateTime? joinDate;

  /// Constructeur pour créer une instance de [User].
  User({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.joinDate,
  });

  /// Factory pour créer une instance de [User] à partir d'un Map JSON.
  ///
  /// Gère différentes clés potentielles pour l'ID ('_id', 'id') et le nom ('name', 'username').
  /// Utilise des valeurs par défaut sûres si des champs sont manquants ou invalides.
  /// Parse les dates de manière sécurisée.
  factory User.fromJson(Map<String, dynamic> json) {
    String? finalAvatarUrl;
    final String? relativeAvatarPath = json['avatarUrl'] as String?; // Ex: "api/users/ID/avatar"

    if (API_BASE_URL.isNotEmpty && relativeAvatarPath != null && relativeAvatarPath.isNotEmpty) {
      // Vérifier si relativeAvatarPath est déjà une URL complète
      if (relativeAvatarPath.toLowerCase().startsWith('http://') || relativeAvatarPath.toLowerCase().startsWith('https://')) {
        finalAvatarUrl = relativeAvatarPath;
      } else {
        // Construire l'URL complète
        String tempBase = API_BASE_URL; // Ex: "http://192.168.1.33:8080"
        if (tempBase.endsWith('/')) {
          tempBase = tempBase.substring(0, tempBase.length - 1);
        }
        String tempRelative = relativeAvatarPath; // Ex: "api/users/ID/avatar"
        if (!tempRelative.startsWith('/')) {
          tempRelative = '/$tempRelative';
        }
        finalAvatarUrl = tempBase + tempRelative; // Ex: "http://192.168.1.33:8080/api/users/ID/avatar"
      }
    } else if (relativeAvatarPath != null && (relativeAvatarPath.toLowerCase().startsWith('http://') || relativeAvatarPath.toLowerCase().startsWith('https://'))) {
      finalAvatarUrl = relativeAvatarPath; // Cas où API_BASE_URL est vide mais on a une URL complète
    }

    return User(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? 'error_user_id_${DateTime.now().millisecondsSinceEpoch}',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? 'Utilisateur Inconnu',
      avatarUrl: finalAvatarUrl, // L'URL complète est assignée ici
      joinDate: _safeDateTimeParse(json['joinDate'] ?? json['createdAt'] ?? json['registeredAt']),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id, // Utilisez '_id': id, si votre API attend cela
      'email': email,
      'name': name, // Utilisez 'username': name, si votre API attend cela
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (joinDate != null) 'joinDate': joinDate!.toIso8601String(), // Convertit DateTime en String standard
    };
  }


  User copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    DateTime? joinDate,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinDate: joinDate ?? this.joinDate,
    );
  }


  @override
  String toString() {
    return 'User(id: $id, name: "$name", email: "$email", avatarUrl: $avatarUrl, joinDate: ${joinDate?.toIso8601String()})';
  }

  /// Vérifie l'égalité basée sur l'identifiant unique [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && runtimeType == other.runtimeType && id == other.id;


  @override
  int get hashCode => id.hashCode;

  String get username => name;
}