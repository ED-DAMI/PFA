// ../widgets/common/song_list_item.dart
import 'package:flutter/material.dart';
import 'package:pfa/models/song.dart'; // Assurez-vous que le chemin est correct

class SongListItem extends StatelessWidget {
  final Song song;
  final String? coverArtUrl;
  final VoidCallback? onTap;
  final Widget? trailing; // Pour une flexibilité future

  const SongListItem({
    super.key,
    required this.song,
    this.coverArtUrl,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Utiliser les couleurs du thème directement pour une meilleure adaptabilité clair/sombre
    final Color itemSubtleTextColor = theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;

    Widget coverArtWidget;
    if (coverArtUrl != null && coverArtUrl!.isNotEmpty && coverArtUrl!.toLowerCase().startsWith('http')) {
      coverArtWidget = Image.network(
        coverArtUrl!,
        fit: BoxFit.cover,
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
            child: Icon(Icons.music_note, color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7)),
          );
        },
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 50,
            height: 50,
            color: theme.colorScheme.secondaryContainer.withOpacity(0.1),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      coverArtWidget = Container(
        width: 50,
        height: 50,
        color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
        child: Icon(Icons.music_note, color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7)),
      );
    }

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: coverArtWidget,
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: itemSubtleTextColor),
          ),
          const SizedBox(height: 5), // Un peu plus d'espace
          Row(
            children: <Widget>[
              Icon(Icons.timer_outlined, size: 14, color: itemSubtleTextColor),
              const SizedBox(width: 4),
              Text(
                song.formattedDuration,
                style: theme.textTheme.bodySmall?.copyWith(color: itemSubtleTextColor, fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.visibility_outlined, size: 14, color: itemSubtleTextColor),
              const SizedBox(width: 4),
              Text(
                song.formattedViewCount,
                style: theme.textTheme.bodySmall?.copyWith(color: itemSubtleTextColor, fontSize: 12),
              ),

              if (song.formattedListenedAt.isNotEmpty) ...[
                const Spacer(), // Pousse la date à droite
                Text(
                  song.formattedListenedAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: itemSubtleTextColor.withOpacity(0.85),
                    fontSize: 11.5, // Légèrement plus petit
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
              // --- FIN DE L'AJOUT ---
            ],
          ),
        ],
      ),
      trailing: this.trailing, // Utiliser le paramètre trailing du constructeur
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0), // Ajuster le padding
      isThreeLine: true, // Important pour que le subtitle ait assez de place
    );
  }
}