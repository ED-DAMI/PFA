// lib/widgets/home/tag_list_widget.dart
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
    final chipTheme = Theme.of(context).chipTheme;

    // --- MODIFICATION ICI: Indicateur de chargement plus discret si les tags sont vides initialement ---
    if (songProvider.isLoadingInitialTags && tags.isEmpty) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        alignment: Alignment.centerLeft, // Aligner à gauche pour que ça ne saute pas au centre
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0), // Un peu de padding
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor.withOpacity(0.7)),
            ),
          ),
        ),
      );
    }

    if (tags.isEmpty && !songProvider.isLoading) {
      return const SizedBox.shrink();
    }
    // --- FIN DE LA MODIFICATION ---

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length + 1,
        padding: const EdgeInsets.symmetric(horizontal: 10.0), // Padding pour ne pas coller aux bords
        itemBuilder: (ctx, index) {
          Widget chip;
          if (index == 0) {
            final bool isSelected = selectedTag == null;
            chip = ChoiceChip(
              label: const Text('Tous'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  songProvider.selectTag(null);
                }
              },
              // --- MODIFICATION ICI: Utilisation plus explicite des couleurs du thème ---
              selectedColor: chipTheme.selectedColor ?? Theme.of(context).primaryColor,
              backgroundColor: chipTheme.backgroundColor ?? Colors.grey[300],
              labelStyle: TextStyle(
                color: isSelected
                    ? (chipTheme.secondaryLabelStyle?.color ?? Colors.white)
                    : (chipTheme.labelStyle?.color ?? Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              // Ajout d'un avatar pour un look plus "pilule"
              // avatar: isSelected ? Icon(Icons.check_circle, color: chipTheme.secondaryLabelStyle?.color ?? Colors.white, size: 18) : null,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : (Theme.of(context).dividerColor) ,
                  )
              ),
              // --- FIN DE LA MODIFICATION ---
            );
          } else {
            final tag = tags[index - 1];
            final isSelected = selectedTag?.id == tag.id;
            chip = ChoiceChip(
              label: Text(tag.name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  songProvider.selectTag(tag);
                }
              },
              selectedColor: chipTheme.selectedColor ?? Theme.of(context).primaryColor,
              backgroundColor: chipTheme.backgroundColor ?? Colors.grey[300],
              labelStyle: TextStyle(
                color: isSelected
                    ? (chipTheme.secondaryLabelStyle?.color ?? Colors.white)
                    : (chipTheme.labelStyle?.color ?? Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              // avatar: isSelected ? Icon(Icons.check_circle, color: chipTheme.secondaryLabelStyle?.color ?? Colors.white, size: 18) : null,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : (Theme.of(context).dividerColor) ,
                  )
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0), // Réduire le padding horizontal entre les chips
            child: chip,
          );
        },
      ),
    );
  }
}