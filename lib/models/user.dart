// lib/models/user.dart
class User {
  final String id; // Ou un autre identifiant unique de votre API
  final String email;
  final String name;
  // Ajoutez d'autres champs retournés par votre API si nécessaire (ex: photoUrl)

  User({
    required this.id,
    required this.email,
    required this.
    name,
  });

  // Méthode pratique pour créer un User depuis un Map (souvent du JSON)
  // Adaptez les clés ('_id', 'email', 'name') aux noms réels des champs dans la réponse de votre API
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '', // Gérez les clés possibles ou les nulls
      email: json['email'] ?? '',
      name: json['username'] ?? 'Utilisateur', // Nom par défaut si absent
    );
  }

  get photoUrl => null;

  // Optionnel : Méthode toJson si vous devez envoyer l'objet User à l'API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
    };
  }
}