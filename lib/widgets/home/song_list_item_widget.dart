// lib/widgets/home/song_list_item_widget.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../screens/song_detail_screen.dart';
import '../../services/audio_player_service.dart';

class SongListItemWidget extends StatelessWidget {
  final Song song;

  const SongListItemWidget({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final bool isThisSongCurrentlyPlaying = audioPlayerService.currentSong?.id == song.id;
    final bool isPlayingThisSong = isThisSongCurrentlyPlaying && audioPlayerService.isPlaying;
    final bool isPausedOnThisSong = isThisSongCurrentlyPlaying && audioPlayerService.playerState == PlayerState.paused;
    final bool isLoadingThisSong = audioPlayerService.isLoading && audioPlayerService.currentSong?.id == song.id;

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${song.id}/cover';
    final theme = Theme.of(context);

    // --- MODIFICATION ICI: Style pour la chanson en cours de lecture ---
    BoxDecoration? itemDecoration;
    if (isThisSongCurrentlyPlaying) {
      itemDecoration = BoxDecoration(
        // border: Border(left: BorderSide(color: theme.primaryColor, width: 4)), // Ou une bordure
        borderRadius: BorderRadius.circular(10.0),
        gradient: LinearGradient( // Un léger gradient pour la chanson active
          stops: const [0.01, 0.99],
          colors: [
            theme.primaryColor.withOpacity(0.15),
            theme.colorScheme.surface.withOpacity(0.1),
          ],
        ),
      );
    }
    // --- FIN DE LA MODIFICATION ---

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      elevation: isThisSongCurrentlyPlaying ? 4.0 : 2.0, // Plus d'élévation si active
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      // --- MODIFICATION ICI: Appliquer la décoration ---
      child: DecoratedBox(
        decoration: itemDecoration ?? const BoxDecoration(),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => SongDetailScreen(song: song),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'song_cover_${song.id}',
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(1, 2),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            coverImageUrl,
                            fit: BoxFit.cover,
                            // --- MODIFICATION ICI: Placeholder et gestion d'erreur améliorés ---
                            loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container( // Placeholder pendant le chargement
                                width: 65,
                                height: 65,
                                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.music_note_rounded, size: 35, color: theme.colorScheme.onSurfaceVariant),
                              );
                            },
                            // --- FIN DE LA MODIFICATION ---
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // --- MODIFICATION ICI: Indicateur visuel pour la chanson en cours ---
                          Row(
                            children: [
                              if (isThisSongCurrentlyPlaying && isPlayingThisSong)
                                Icon(Icons.volume_up_rounded, color: theme.primaryColor, size: 18),
                              if (isThisSongCurrentlyPlaying && isPausedOnThisSong)
                                Icon(Icons.pause_rounded, color: theme.hintColor, size: 18),
                              if (isThisSongCurrentlyPlaying) const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  song.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isThisSongCurrentlyPlaying ? theme.primaryColor : theme.textTheme.titleMedium?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // --- FIN DE LA MODIFICATION ---
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (song.duration != null && song.duration! > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                song.formattedDuration,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox( // Zone pour le bouton play/pause
                      width: 48,
                      height: 48, // Assurer une bonne zone de clic
                      child: Center(
                        child: isLoadingThisSong
                            ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                            : IconButton(
                          icon: Icon(
                            isPlayingThisSong ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: theme.primaryColor,
                          ),
                          iconSize: 38,
                          padding: EdgeInsets.zero,
                          splashRadius: 24, // Rayon du ripple effect
                          tooltip: isPlayingThisSong ? 'Pause' : (isPausedOnThisSong ? 'Reprendre' : 'Lecture'),
                          onPressed: () {
                            if (isPlayingThisSong) {
                              audioPlayerService.pause();
                            } else if (isPausedOnThisSong) {
                              audioPlayerService.resume();
                            } else {
                              audioPlayerService.play(song);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetadataIconText(
                              context: context,
                              icon: Icons.calendar_today_outlined,
                              text: song.formattedPublicationDate,
                              tooltip: 'Date de publication',
                              // onTap: null, // Pas d'action pour la date
                            ),
                            const SizedBox(height: 4),
                            _buildMetadataIconText(
                              context: context,
                              icon: Icons.visibility_outlined,
                              text: song.formattedViewCount,
                              tooltip: 'Nombre de vues',
                              // onTap: null, // Pas d'action pour les vues
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMetadataIconText(
                              context: context,
                              icon: Icons.mode_comment_outlined,
                              text: song.commentCount.toString(), // Utiliser text au lieu de count
                              tooltip: '${song.commentCount} Commentaire${song.commentCount != 1 ? 's' : ''}',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => SongDetailScreen(song: song, focusComments: true),
                                  ),
                                );
                              }
                          ),
                          const SizedBox(width: 16),
                          _buildMetadataIconText(
                              context: context,
                              icon: Icons.emoji_emotions_outlined,
                              text: song.totalReactionCount.toString(), // Utiliser text au lieu de count
                              tooltip: '${song.totalReactionCount} Réaction${song.totalReactionCount != 1 ? 's' : ''}',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => SongDetailScreen(
                                      song: song,
                                      openReactionsDialogOnLoad: true,
                                    ),
                                  ),
                                );
                              }
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MODIFICATION ICI: _buildMetadataIconText prend un 'text' au lieu de 'count' pour plus de flexibilité ---
  Widget _buildMetadataIconText({
    required BuildContext context,
    required IconData icon,
    required String text,
    required String tooltip,
    VoidCallback? onTap, // Rendre onTap optionnel
  }) {
    final theme = Theme.of(context);
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: theme.hintColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontWeight: onTap != null ? FontWeight.w600 : FontWeight.normal, // Gras si cliquable
              fontSize: theme.textTheme.bodySmall!.fontSize,
              color: onTap != null ? theme.colorScheme.onSurface : theme.hintColor, // Couleur différente si non cliquable
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: content,
    );
  }
// --- FIN DE LA MODIFICATION ---
}