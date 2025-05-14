import 'package:flutter/foundation.dart'; // Pour @override et potentiellement kDebugMode

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
    this.avatarUrl, // Optionnel
    this.joinDate,  // Optionnel
  });

  /// Factory pour créer une instance de [User] à partir d'un Map JSON.
  ///
  /// Gère différentes clés potentielles pour l'ID ('_id', 'id') et le nom ('name', 'username').
  /// Utilise des valeurs par défaut sûres si des champs sont manquants ou invalides.
  /// Parse les dates de manière sécurisée.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // Gère '_id' ou 'id' comme clé pour l'identifiant. Fournit un fallback unique si absent.
      id: json['_id']?.toString() ?? json['id']?.toString() ?? 'error_user_id_${DateTime.now().millisecondsSinceEpoch}',

      // Utilise une chaîne vide comme fallback pour l'email si absent.
      email: json['email'] as String? ?? '',

      // Utilise 'name' ou 'username' comme clé pour le nom. Fournit 'Utilisateur' comme fallback.
      name: json['name'] as String? ?? json['username'] as String? ?? 'Utilisateur',

      // Récupère 'avatarUrl' comme String nullable.
      avatarUrl: json['avatarUrl'] as String?,

      // Parse la date d'inscription en utilisant une fonction helper sûre.
      // Vérifie plusieurs clés potentielles ('joinDate', 'createdAt', 'registeredAt').
      joinDate: _safeDateTimeParse(json['joinDate'] ?? json['createdAt'] ?? json['registeredAt']),
    );
  }

  /// Convertit l'instance [User] en un Map JSON.
  ///
  /// Utile pour envoyer des données utilisateur à une API.
  /// N'inclut les champs optionnels (`avatarUrl`, `joinDate`) que s'ils ne sont pas null.
  /// Utilise la clé 'id' (ajustez si votre API attend '_id').
  Map<String, dynamic> toJson() {
    return {
      'id': id, // Utilisez '_id': id, si votre API attend cela
      'email': email,
      'name': name, // Utilisez 'username': name, si votre API attend cela
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (joinDate != null) 'joinDate': joinDate!.toIso8601String(), // Convertit DateTime en String standard
    };
  }

  /// Crée une copie de cette instance [User] avec les champs spécifiés remplacés.
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

  /// Retourne une représentation textuelle de l'objet User pour le débogage.
  @override
  String toString() {
    return 'User(id: $id, name: "$name", email: "$email", avatarUrl: $avatarUrl, joinDate: ${joinDate?.toIso8601String()})';
  }

  /// Vérifie l'égalité basée sur l'identifiant unique [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is User && runtimeType == other.runtimeType && id == other.id;

  /// Retourne le hash code basé sur l'identifiant unique [id].
  @override
  int get hashCode => id.hashCode;

  /// Fournit `username` comme un alias pour `name`, utile pour la compatibilité
  /// ou si l'interface utilisateur s'attend à un `username`.
  String get username => name;
}