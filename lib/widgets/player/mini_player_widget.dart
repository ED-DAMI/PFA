import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';
import '../../services/audio_player_service.dart';
import '../../models/song.dart';
import '../../screens/song_detail_screen.dart'; // Pour naviguer vers les détails
// Pour formatDuration

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final Song? currentSong = audioPlayerService.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink(); // Ne rien afficher si pas de chanson
    }

    final String coverImageUrl = '${API_BASE_URL}/api/songs/${currentSong.id}/cover';

    return GestureDetector(
      onTap: () {
        // Naviguer vers l'écran SongDetailScreen de la chanson actuelle
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => SongDetailScreen(song: currentSong),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant, // Un peu différent du fond
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Cover
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(coverImageUrl),
                      fit: BoxFit.cover,
                      onError: (e,s) => print("MiniPlayer cover error: $e"),
                    ),
                  ),
                  child: Image.network(
                    coverImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.music_note, size: 24, color: Colors.grey);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Titre et Artiste
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentSong.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        currentSong.artist,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Boutons Play/Pause
                if (audioPlayerService.isLoading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: Icon(
                      audioPlayerService.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 30,
                    ),
                    onPressed: () {
                      if (audioPlayerService.isPlaying) {
                        audioPlayerService.pause();
                      } else {
                        audioPlayerService.resume(); // Ou play si c'est un nouvel état
                      }
                    },
                  ),
                // Optionnel: Bouton Suivant (très simplifié)
                // IconButton(
                //   icon: const Icon(Icons.skip_next, size: 30),
                //   onPressed: () {
                //     // TODO: Logique pour passer à la chanson suivante
                //   },
                // ),
              ],
            ),
            // Barre de progression (optionnelle pour mini player)
            if (audioPlayerService.totalDuration > Duration.zero)
              SizedBox(
                height: 3, // Hauteur de la barre de progression
                child: LinearProgressIndicator(
                  value: (audioPlayerService.currentPosition.inMilliseconds /
                      audioPlayerService.totalDuration.inMilliseconds)
                      .clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}