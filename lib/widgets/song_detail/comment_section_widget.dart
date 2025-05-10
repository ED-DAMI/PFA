import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/interaction_provider.dart';
import '../../providers/auth_provider.dart'; // Pour vérifier si l'utilisateur est connecté
import '../../models/comment.dart';
import '../../utils/helpers.dart'; // Pour formatDate

class CommentSectionWidget extends StatefulWidget {
  final String songId;
  const CommentSectionWidget({super.key, required this.songId});

  @override
  State<CommentSectionWidget> createState() => _CommentSectionWidgetState();
}

class _CommentSectionWidgetState extends State<CommentSectionWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _isPostingComment = false;

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      showAppSnackBar(context, "Le commentaire ne peut pas être vide.");
      return;
    }
    if (!mounted) return;

    setState(() => _isPostingComment = true);
    final success = await Provider.of<InteractionProvider>(context, listen: false)
        .addComment(_commentController.text.trim());

    if (!mounted) return;
    setState(() => _isPostingComment = false);

    if (success) {
      _commentController.clear();
      _commentFocusNode.unfocus(); // Cacher le clavier
      showAppSnackBar(context, "Commentaire ajouté !");
    } else {
      final error = Provider.of<InteractionProvider>(context, listen: false).error;
      showAppSnackBar(context, error ?? "Erreur lors de l'ajout du commentaire.", isError: true);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactionProvider = Provider.of<InteractionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final comments = interactionProvider.comments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Champ pour ajouter un commentaire
        if (authProvider.isAuthenticated) // Afficher seulement si connecté
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un commentaire...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 8),
                _isPostingComment
                    ? const SizedBox(width: 24, height:24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),

        // Liste des commentaires
        if (interactionProvider.isLoadingComments && comments.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ))
        else if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('Aucun commentaire pour le moment. Soyez le premier !')),
          )
        else
          ListView.builder(
            shrinkWrap: true, // Important dans un SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(), // Pour éviter le scroll dans le scroll
            itemCount: comments.length,
            itemBuilder: (ctx, index) {
              final comment = comments[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    // Vous pouvez utiliser comment.author.avatarUrl si disponible
                    backgroundColor: Theme.of(context).primaryColor.withAlpha(50),
                    child: Text(comment.author.isEmpty ? comment.author[0].toUpperCase() : "?", style: TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                  title: Text(comment.author, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(comment.text),
                  trailing: Text(
                    formatDate(comment.createdAt), // Utilisez votre helper
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          ),
        if (interactionProvider.error != null && !interactionProvider.isLoadingComments)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Erreur: ${interactionProvider.error}", style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
      ],
    );
  }
}