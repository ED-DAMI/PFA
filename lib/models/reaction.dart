import 'package:flutter/foundation.dart'; // Pour kDebugMode

class Reaction {
  final String id;
  final String songId; // Peut être nullable si une réaction n'est pas toujours liée à une chanson
  final String reactorName;
  final String emoji; // Contiendra le symbole emoji (ex: "❤️")
  final DateTime createdAt;

  // Map statique et constante pour convertir les noms d'emoji du backend en symboles
  // Ceci est utilisé si votre backend envoie des noms comme "HEART", "FIRE", etc.
  static const Map<String, String> _backendEmojiNameToSymbol = {
    'HEART': '❤️',
    'LOVE': '😍',
    'FIRE': '🔥',
    'LIKE': '👍',
    'SAD': '😢',
    'SURPRISED': '😮',
    // Ajoutez d'autres emojis ici si votre backend en a plus
  };

  Reaction({
    required this.id,
    required this.songId,
    required this.reactorName,
    required this.emoji, // Doit être le symbole emoji
    required this.createdAt,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    // Lire l'emoji. Le backend envoie "emojis" dans la réponse du POST.
    // Vérifiez ce que le GET envoie. Supposons qu'il envoie "emoji" ou "emojis".
    String emojiKeyName = json.containsKey('emojis') ? 'emojis' : 'emoji';
    String emojiValueFromBackend = json[emojiKeyName]?.toString() ?? '❓'; // Valeur par défaut

    String displayEmojiSymbol = emojiValueFromBackend;
    if (_backendEmojiNameToSymbol.containsKey(emojiValueFromBackend.toUpperCase())) {
      displayEmojiSymbol = _backendEmojiNameToSymbol[emojiValueFromBackend.toUpperCase()]!;
      if (kDebugMode) {
        print("Reaction.fromJson: Mapped backend name '$emojiValueFromBackend' to symbol '$displayEmojiSymbol'");
      }
    } else {
      if (kDebugMode) {
        print("Reaction.fromJson: Emoji value '$emojiValueFromBackend' from backend not in map. Using directly. Ensure map contains '${emojiValueFromBackend.toUpperCase()}' or backend sends a known symbol.");
      }
    }

    // Lire la date. La réponse du POST utilise "date".
    // Vérifiez ce que le GET envoie. Supposons "createdAt", "timestamp", ou "date".
    String? dateString;
    if (json.containsKey('date')) {
      dateString = json['date']?.toString();
    } else if (json.containsKey('createdAt')) {
      dateString = json['createdAt']?.toString();
    } else if (json.containsKey('timestamp')) {
      dateString = json['timestamp']?.toString();
    }

    DateTime createdAt;
    if (dateString != null) {
      try {
        createdAt = DateTime.parse(dateString);
      } catch (e) {
        if (kDebugMode) print("Reaction.fromJson: Error parsing date string '$dateString'. Using DateTime.now(). Error: $e");
        createdAt = DateTime.now();
      }
    } else {
      if (kDebugMode) print("Reaction.fromJson: Date field ('date', 'createdAt', or 'timestamp') is null or missing. Using DateTime.now(). JSON was: $json");
      createdAt = DateTime.now();
    }

    return Reaction(
      id: json['id']?.toString() ?? 'error_id_${DateTime.now().millisecondsSinceEpoch}', // ID unique en cas d'erreur
      songId: json['songId']?.toString() ?? '',
      reactorName: json['reactorName']?.toString() ?? 'Unknown',
      emoji: displayEmojiSymbol,
      createdAt: createdAt,
    );
  }

// Optionnel : une méthode toJson si vous avez besoin de renvoyer cet objet au backend
// (par exemple, pour des mises à jour, bien que ce ne soit généralement pas le cas pour les réactions).
// Cette méthode devrait convertir le symbole emoji en nom si le backend s'attend à un nom.
/*
  static const Map<String, String> _emojiSymbolToBackendName = {
    '❤️': 'HEART',
    '😍': 'LOVE',
    '🔥': 'FIRE',
    '👍': 'LIKE',
    '😢': 'SAD',
    '😮': 'SURPRISED',
  };

  Map<String, dynamic> toJson() {
    String emojiToSend = emoji; // Par défaut, le symbole
    if (_emojiSymbolToBackendName.containsKey(emoji)) {
      emojiToSend = _emojiSymbolToBackendName[emoji]!;
    }

    return {
      'id': id,
      'songId': songId,
      'reactorName': reactorName,
      'emoji': emojiToSend, // Envoie le nom si mappé, sinon le symbole
      'createdAt': createdAt.toIso8601String(),
    };
  }
  */
}