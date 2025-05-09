// lib/widgets/song_detail/reaction_bar_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/interaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart'; // Pour kReactionEmojis
import '../../utils/helpers.dart'; // Pour showAppSnackBar
import 'package:flutter/foundation.dart'; // Pour kDebugMode

class ReactionBarWidget extends StatelessWidget {
  final String songId;

  const ReactionBarWidget({super.key, required this.songId});

  // La vérification de mounted se fait via context.mounted
  Future<void> _handleReaction(BuildContext context, String emoji) async {
    final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!authProvider.isAuthenticated) {
      // Vérifier context.mounted avant d'appeler showAppSnackBar si on est dans une opération asynchrone
      // Ici, c'est synchrone avant l'await, donc c'est généralement sûr.
      showAppSnackBar(context, "Connectez-vous pour réagir !", isError: true);
      return;
    }

    // Assurez-vous que InteractionProvider est configuré pour le bon songId.
    if (interactionProvider.currentSongId != songId) {
      if (kDebugMode) {
        print("ReactionBarWidget WARN: songId ($songId) differs from provider's currentSongId (${interactionProvider.currentSongId}). Ensure provider is set correctly.");
        // Il est préférable que SongDetailScreen s'assure que setSongId est appelé correctement.
        // Forcer ici pourrait avoir des effets de bord ou être redondant.
      }
    }

    final success = await interactionProvider.toggleReaction(emoji);

    // Après l'await, il faut vérifier si le widget est toujours monté avant d'utiliser son BuildContext
    if (!context.mounted) return; // Vérification cruciale ici

    if (!success) {
      showAppSnackBar(context, interactionProvider.error ?? "Erreur lors de la réaction.", isError: true);
    }
    // Pas besoin de else if (success && context.mounted) car le context.mounted est déjà vérifié.
    // Le feedback de succès est optionnel.
  }

  void _showReactionDetailsDialog(BuildContext context) { // context est déjà passé
    final interactionProvider = Provider.of<InteractionProvider>(context, listen: false);
    final reactionCounts = interactionProvider.reactionCounts;

    final List<Widget> reactionDetailItems = [];
    kReactionEmojis.forEach((emoji) {
      final count = reactionCounts[emoji] ?? 0;
      if (count > 0) {
        reactionDetailItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
            child: Chip(
              avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
              label: Text(count.toString(), style: const TextStyle(fontSize: 14)),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      }
    });

    if (!context.mounted) return; // Vérifier avant d'afficher le dialog

    if (reactionDetailItems.isEmpty) {
      showAppSnackBar(context, "Aucune réaction pour le moment.");
      return;
    }

    showDialog(
      context: context, // Utiliser le context passé
      builder: (ctx) => AlertDialog(
        title: const Text('Détail des Réactions'),
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            alignment: WrapAlignment.center,
            children: reactionDetailItems,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Fermer'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // context est disponible ici
    final interactionProvider = Provider.of<InteractionProvider>(context);
    final reactionCounts = interactionProvider.reactionCounts;
    final totalReactions = reactionCounts.values.fold(0, (sum, count) => sum + count);

    if (interactionProvider.isLoadingReactions && !interactionProvider.isInitialized && reactionCounts.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      ));
    }
    if (interactionProvider.error != null && !interactionProvider.isInitialized && reactionCounts.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text("Erreur chargement réactions: ${interactionProvider.error}", style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6.0,
          runSpacing: 2.0,
          alignment: WrapAlignment.center,
          children: kReactionEmojis.map((emoji) {
            final count = reactionCounts[emoji] ?? 0;
            final bool hasUserReacted = interactionProvider.hasUserReactedWith(emoji);

            return ChoiceChip(
              avatar: Text(emoji, style: TextStyle(fontSize: hasUserReacted ? 21 : 19)),
              label: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 14,
                  color: hasUserReacted
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: hasUserReacted ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: hasUserReacted,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundColor: Theme.of(context).chipTheme.backgroundColor?.withOpacity(0.4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              elevation: hasUserReacted ? 1.5 : 0.5,
              pressElevation: 1.0,
              onSelected: (bool selected) {
                _handleReaction(context, emoji); // Passer le context
              },
            );
          }).toList(),
        ),
        if (totalReactions > 0 && (!interactionProvider.isLoadingReactions || interactionProvider.isInitialized) ) // Afficher si chargé ou si initialisé avec données
          Padding(
            padding: const EdgeInsets.only(top: 14.0),
            child: TextButton(
              onPressed: () => _showReactionDetailsDialog(context), // Passer le context
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                '$totalReactions Réaction${totalReactions != 1 ? 's' : ''} au total',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary
                ),
              ),
            ),
          ),
      ],
    );
  }
}