import 'user.dart'; // À créer

class Comment {
  final String id;
  final String songId;
  final String author;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.songId,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      songId: json['songId'] as String? ?? '',
      author: json['author']as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}