import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import '../../models/tag.dart';

class TagListWidget extends StatelessWidget {
  const TagListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final tags = songProvider.tags;
    final selectedTag = songProvider.selectedTag;

    if (tags.isEmpty && !songProvider.isLoading) { // Ne pas afficher si pas de tags et pas en chargement
      return const SizedBox.shrink();
    }
    if (songProvider.isLoading && tags.isEmpty) { // Afficher un petit loader si les tags sont en cours de chargement
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }


    return Container(
      height: 50, // Hauteur fixe pour la liste de tags
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1, // +1 pour le tag "Tous"
        itemBuilder: (ctx, index) {
          if (index == 0) { // Le tag "Tous"
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: ChoiceChip(
                label: const Text('Tous'),
                selected: selectedTag == null,
                onSelected: (isSelected) {
                  if (isSelected) {
                    songProvider.selectTag(null);
                  }
                },
                // Utilisez les couleurs du thème
                selectedColor: Theme.of(context).chipTheme.selectedColor,
                backgroundColor: Theme.of(context).chipTheme.backgroundColor,
                labelStyle: selectedTag == null
                    ? Theme.of(context).chipTheme.secondaryLabelStyle // Style pour texte quand sélectionné
                    : Theme.of(context).chipTheme.labelStyle, // Style pour texte quand non sélectionné
              ),
            );
          }
          final tag = tags[index - 1];
          final isSelected = selectedTag?.id == tag.id;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ChoiceChip(
              label: Text(tag.name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  songProvider.selectTag(tag);
                }
              },
              selectedColor: Theme.of(context).chipTheme.selectedColor,
              backgroundColor: Theme.of(context).chipTheme.backgroundColor,
              labelStyle: isSelected
                  ? Theme.of(context).chipTheme.secondaryLabelStyle
                  : Theme.of(context).chipTheme.labelStyle,
            ),
          );
        },
      ),
    );
  }
}// TODO Implement this library.