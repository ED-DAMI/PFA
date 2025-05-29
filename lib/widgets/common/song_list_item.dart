// lib/widgets/common/song_list_item.dart
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';

import '../../models/song.dart';
// Assurez-vous que le chemin vers Song est correct

class SongListItem extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? coverArtUrl;

  const SongListItem({
    super.key,
    required this.song,
    this.onTap,
    this.trailing,
    this.coverArtUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget leadingWidget;

    String? actualCoverArtUrl ='$API_BASE_URL/api/songs/'+song.id+'/cover';

    if (actualCoverArtUrl != null && actualCoverArtUrl.isNotEmpty) {
      leadingWidget = CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(actualCoverArtUrl),
        backgroundColor: theme.colorScheme.primaryContainer,
        onBackgroundImageError: (exception, stackTrace) {},
        child: (actualCoverArtUrl == null || actualCoverArtUrl.isEmpty) ? Icon(Icons.music_note, color: theme.colorScheme.onPrimaryContainer) : null,
      );
    } else {
      leadingWidget = CircleAvatar(
        radius: 28,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.music_note,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      leading: leadingWidget,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.75)),
      ),
      trailing: trailing ?? (onTap != null ? Icon(Icons.play_arrow_rounded, size: 28, color: theme.colorScheme.primary) : null),
      onTap: onTap,
    );
  }
}