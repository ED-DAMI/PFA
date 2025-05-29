// lib/widgets/player/mini_player_widget.dart
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../screens/song_detail_screen.dart';
import '../../services/audio_player_service.dart'; // Pour naviguer vers les détails

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final Song? currentSong = audioPlayerService.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${currentSong.id}/cover';
    final bool isPlaying = audioPlayerService.isPlaying;
    final bool isLoading = audioPlayerService.isLoading;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            // CORRECTION ICI: Supprimer focusReactions ou le remplacer
            builder: (ctx) => SongDetailScreen(song: currentSong),
            // Si vous vouliez un comportement spécifique, utilisez le nouveau paramètre:
            // builder: (ctx) => SongDetailScreen(song: currentSong, openReactionsDialogOnLoad: false), // Exemple
          ),
        );
      },
      child: Container(
        height: 65,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.95),
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(
                        coverImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            child: Icon(Icons.music_note, size: 28, color: Theme.of(context).colorScheme.onSecondaryContainer),
                          );
                        },
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
                          currentSong.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      padding: const EdgeInsets.all(8.0),
                      tooltip: isPlaying ? "Pause" : "Lecture",
                      onPressed: () {
                        if (isPlaying) {
                          audioPlayerService.pause();
                        } else {
                          audioPlayerService.resume();
                        }
                      },
                    ),
                ],
              ),
            ),
            if (audioPlayerService.totalDuration > Duration.zero && !isLoading)
              SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  value: (audioPlayerService.totalDuration.inMilliseconds > 0)
                      ? (audioPlayerService.currentPosition.inMilliseconds /
                      audioPlayerService.totalDuration.inMilliseconds)
                      .clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: Theme.of(context).colorScheme.surfaceTint.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              )
            else if (isLoading)
              const SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                ),
              )
            else
              const SizedBox(height: 2.5),
          ],
        ),
      ),
    );
  }
}