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
    final bool isPlayingThisSong = audioPlayerService.currentSong?.id == song.id && audioPlayerService.isPlaying;
    final bool isPausedOnThisSong = audioPlayerService.currentSong?.id == song.id && audioPlayerService.playerState == PlayerState.paused;
    final bool isLoadingThisSong = audioPlayerService.isLoading && audioPlayerService.currentSong?.id == song.id;

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${song.id}/cover';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              // CORRECTION ICI
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
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.music_note_rounded, size: 35, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            );
                          },
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
                        Text(
                          song.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.artist,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.duration != null && song.duration! > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              song.formattedDuration,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: isLoadingThisSong
                          ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5)
                      )
                          : IconButton(
                        icon: Icon(
                          isPlayingThisSong ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: Theme.of(context).primaryColor,
                        ),
                        iconSize: 38,
                        padding: EdgeInsets.zero,
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
                style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 15, color: Theme.of(context).hintColor),
                              const SizedBox(width: 5),
                              Text(song.formattedPublicationDate),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined, size: 16, color: Theme.of(context).hintColor),
                              const SizedBox(width: 5),
                              Text(song.formattedViewCount),
                            ],
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
                            count: song.commentCount,
                            tooltip: '${song.commentCount} Commentaire${song.commentCount != 1 ? 's' : ''}',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  // CORRECTION ICI: focusComments est toujours un paramètre valide
                                  builder: (ctx) => SongDetailScreen(song: song, focusComments: true),
                                ),
                              );
                            }
                        ),
                        const SizedBox(width: 16),
                        _buildMetadataIconText(
                            context: context,
                            icon: Icons.emoji_emotions_outlined,
                            count: song.totalReactionCount,
                            tooltip: '${song.totalReactionCount} Réaction${song.totalReactionCount != 1 ? 's' : ''}',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  // CORRECTION ICI: Remplacer focusReactions par openReactionsDialogOnLoad
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
    );
  }

  Widget _buildMetadataIconText({
    required BuildContext context,
    required IconData icon,
    required int count,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: Theme.of(context).hintColor),
              const SizedBox(width: 5),
              Text(
                count.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: Theme.of(context).textTheme.bodySmall!.fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}