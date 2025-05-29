// lib/widgets/song_detail/reactions_dialog_helper.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/interaction_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart'; // Pour kReactionEmojis
import '../../utils/helpers.dart';   // Pour showAppSnackBar
import 'package:flutter/foundation.dart'; // Pour kDebugMode

class _ReactionsDialogContent extends StatefulWidget {
  final String songId;
  final InteractionProvider interactionProvider;
  final BuildContext dialogContext;

  const _ReactionsDialogContent({
    super.key, // Ajout de super.key
    required this.songId,
    required this.interactionProvider,
    required this.dialogContext,
  });

  @override
  State<_ReactionsDialogContent> createState() => _ReactionsDialogContentState();
}

class _ReactionsDialogContentState extends State<_ReactionsDialogContent> {
  bool _isProcessingReaction = false;

  Future<void> _handleReaction(String emoji) async {
    if (!mounted) return;
    setState(() => _isProcessingReaction = true);

    if (widget.interactionProvider.currentSongId != widget.songId) {
      if (kDebugMode) {
        print("ReactionsDialog WARN: songId (${widget
            .songId}) differs from provider's currentSongId (${widget
            .interactionProvider.currentSongId}).");
      }
    }

    final success = await widget.interactionProvider.toggleReaction(emoji);

    if (!mounted) return;
    setState(() => _isProcessingReaction = false);

    // MODIFICATION ICI: Fermer le dialogue en cas de succès
    if (success) {
      if (mounted) { // Revérifier avant de pop
        Navigator.of(widget.dialogContext).pop();
      }
    } else {
      showAppSnackBar(widget.dialogContext,
          widget.interactionProvider.error ?? "Erreur lors de la réaction.",
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reactionCounts = widget.interactionProvider.reactionCounts;
    final List<Widget> reactionDetailItems = [];

    // Utiliser kReactionEmojis pour l'ordre et inclure ceux avec 0 compte si on veut les afficher tous
    // Ou filtrer comme avant pour n'afficher que ceux avec des réactions.
    // Ici, on garde l'affichage de ceux qui ont des réactions pour la section "Réactions actuelles"
    kReactionEmojis.forEach((emoji) {
      final count = reactionCounts[emoji] ?? 0;
      if (count > 0) {
        reactionDetailItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Chip(
              avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
              label: Text(count.toString(), style: const TextStyle(fontSize: 14)),
              backgroundColor: Theme.of(widget.dialogContext).colorScheme.surfaceVariant.withOpacity(0.8),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choisissez votre réaction :",
          style: Theme.of(widget.dialogContext).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_isProcessingReaction)
          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2.5)))
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            alignment: WrapAlignment.center,
            children: kReactionEmojis.map((emoji) {
              final bool hasUserReacted = widget.interactionProvider.hasUserReactedWith(emoji);
              return ChoiceChip(
                avatar: Text(emoji, style: TextStyle(fontSize: hasUserReacted ? 22 : 20)),
                label: Text(emoji),
                selected: hasUserReacted,
                selectedColor: Theme.of(widget.dialogContext).colorScheme.primaryContainer,
                backgroundColor: Theme.of(widget.dialogContext).chipTheme.backgroundColor?.withOpacity(0.5),
                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                elevation: hasUserReacted ? 2.0 : 0.5,
                pressElevation: 1.0,
                onSelected: (bool selected) {
                  _handleReaction(emoji);
                },
              );
            }).toList(),
          ),
        if (reactionDetailItems.isNotEmpty) ...[
          const Divider(height: 32, thickness: 1, indent: 20, endIndent: 20),
          Text(
            "Réactions actuelles :",
            style: Theme.of(widget.dialogContext).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            alignment: WrapAlignment.center,
            children: reactionDetailItems,
          ),
        ] else if (!_isProcessingReaction) ...[
          const Padding(
            padding: EdgeInsets.only(top: 24.0, bottom: 8.0),
            child: Center(child: Text("Soyez le premier à réagir !")),
          )
        ],
      ],
    );
  }
}

// La fonction showReactionsPickerDialog reste inchangée
Future<void> showReactionsPickerDialog({
  required BuildContext screenContext,
  required String songId,
}) async {
  final authProvider = Provider.of<AuthProvider>(screenContext, listen: false);
  if (!authProvider.isAuthenticated) {
    if (!screenContext.mounted) return;
    showAppSnackBar(screenContext, "Connectez-vous pour réagir !", isError: true);
    return;
  }

  final interactionProvider = Provider.of<InteractionProvider>(screenContext, listen: false);
  if (interactionProvider.currentSongId != songId) {
    if (kDebugMode) {
      print("ReactionsPickerDialog WARN: songId ($songId) in dialog call differs from provider's currentSongId (${interactionProvider.currentSongId}).");
    }
  }

  if (!screenContext.mounted) return;

  return showDialog<void>(
    context: screenContext,
    builder: (dialogContext) {
      return Consumer<InteractionProvider>(
        builder: (contextForConsumer, listenedInteractionProvider, child) {
          if (listenedInteractionProvider.currentSongId != songId) {
            return AlertDialog(
              title: const Text('Réagissez & Voir Détails'),
              content: const Center(child: Text("Erreur: Contexte de la chanson invalide ou modifié.")),
              actions: <Widget>[
                TextButton(
                  child: const Text('Fermer'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Réagissez & Voir Détails'),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            content: SingleChildScrollView(
              child: _ReactionsDialogContent(
                key: ValueKey(songId), // Ajout d'une clé pour aider Flutter si le dialogue est reconstruit
                songId: songId,
                interactionProvider: listenedInteractionProvider,
                dialogContext: dialogContext,
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Fermer'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}