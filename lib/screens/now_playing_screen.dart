// lib/screens/now_playing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- NOUVEL IMPORT
import '../services/audio_player_service.dart';
import '../providers/auth_provider.dart';
import '../models/song.dart';

class NowPlayingScreen extends StatelessWidget {
  final String baseUrl;

  const NowPlayingScreen({
    Key? key,
    required this.baseUrl,
  }) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // --- MODIFIÉ: Widget pour afficher l'image de couverture via API avec CachedNetworkImage ---
  Widget _buildCoverArt(BuildContext context, Song currentSong, AuthProvider authProvider, String pBaseUrl /* Ajout de baseUrl ici aussi */) {
    final String imageUrl = '$pBaseUrl/api/songs/${currentSong.id}/image'; // Utiliser pBaseUrl
    final double imageSize = MediaQuery.of(context).size.width * 0.7;

    // Widget placeholder commun pour chargement du token OU erreur de token
    Widget tokenPlaceholder = Container(
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.white24),
      ),
      child: const Center(child: Icon(Icons.music_note, size: 100, color: Colors.white70)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: FutureBuilder<String?>(
        future: authProvider.getToken(),
        builder: (context, tokenSnapshot) {
          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return tokenPlaceholder;
          }
          if (!tokenSnapshot.hasData || tokenSnapshot.data == null) {
            print("[NowPlayingScreen] No token available for image request.");
            return tokenPlaceholder;
          }

          final token = tokenSnapshot.data!;
          final headers = {'Authorization': token};

          print("[NowPlayingScreen] Fetching image: $imageUrl with token using CachedNetworkImage.");

          // --- UTILISATION DE CachedNetworkImage ---
          return CachedNetworkImage(
            imageUrl: imageUrl,
            httpHeaders: headers,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container( // Placeholder pendant le chargement de l'image
              width: imageSize,
              height: imageSize,
              color: Colors.grey.shade700,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
            errorWidget: (context, url, error) { // Widget en cas d'erreur de chargement de l'image
              print("[NowPlayingScreen] Error loading cover image $imageUrl with CachedNetworkImage: $error");
              return Container(
                width: imageSize,
                height: imageSize,
                color: Colors.grey.shade600,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 80, color: Colors.white60)),
              );
            },
            fadeInDuration: const Duration(milliseconds: 300), // Optionnel: effet de fondu
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- MODIFIÉ: Utiliser context.select pour currentSong ---
    // Cela garantit que _buildCoverArt et les textes Titre/Artiste ne sont reconstruits
    // que si la chanson elle-même change, et non à chaque mise à jour de la position de lecture.
    final currentSong = context.select((AudioPlayerService service) => service.currentSong);

    // authProvider est lu une seule fois, donc context.read est toujours approprié ici.
    final authProvider = context.read<AuthProvider>();

    final List<Color> gradientColors = [
      Colors.deepPurple.shade700,
      Colors.black87
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSong?.title ?? 'Lecture en cours'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 20.0),
            child: Center(
              child: currentSong == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, color: Colors.white70, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Aucune chanson en cours',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // --- Image de Couverture (via le helper) ---
                  // currentSong est obtenu via context.select, donc cette partie
                  // ne sera pas reconstruite inutilement.
                  _buildCoverArt(context, currentSong, authProvider, baseUrl),

                  const SizedBox(height: 35),

                  // --- Titre et Artiste (ne dépendent que de currentSong) ---
                  Text(
                    currentSong.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentSong.artist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1,
                  ),
                  const SizedBox(height: 35),

                  // --- MODIFIÉ: Utiliser Consumer pour les parties qui changent avec l'état de lecture ---
                  Consumer<AudioPlayerService>(
                      builder: (context, audioService, child) {
                        // audioService ici est mis à jour lorsque AudioPlayerService notifie
                        return Column(
                          children: [
                            // --- Barre de Progression ---
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 15.0), activeTrackColor: Colors.white, inactiveTrackColor: Colors.white.withOpacity(0.3), thumbColor: Colors.white, overlayColor: Colors.white.withAlpha(80)),
                              child: Slider(
                                value: (audioService.currentPosition.inMilliseconds > 0 && audioService.totalDuration.inMilliseconds > 0 && audioService.currentPosition <= audioService.totalDuration)
                                    ? audioService.currentPosition.inMilliseconds.toDouble() : 0.0,
                                min: 0.0,
                                max: audioService.totalDuration.inMilliseconds > 0
                                    ? audioService.totalDuration.inMilliseconds.toDouble() : 1.0,
                                onChanged: (value) {
                                  if (audioService.totalDuration > Duration.zero) {
                                    // Utiliser context.read ici car l'action ne nécessite pas de reconstruction immédiate
                                    // de cette partie de l'arbre. Le service notifiera les changements.
                                    context.read<AudioPlayerService>().seek(Duration(milliseconds: value.toInt()));
                                  }
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 25.0),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(_formatDuration(audioService.currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text(_formatDuration(audioService.totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ]),
                            ),
                            const SizedBox(height: 25),

                            // --- Contrôles de Lecture ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), tooltip: 'Précédent', onPressed: () { /* TODO */ }),
                                IconButton(
                                  iconSize: 75.0,
                                  icon: audioService.isLoading
                                      ? const SizedBox(width: 65, height: 65, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                      : Icon(audioService.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white),
                                  tooltip: audioService.isPlaying ? 'Mettre en pause' : 'Lire',
                                  onPressed: audioService.isLoading ? null : () {
                                    // Utiliser context.read ici aussi pour les actions
                                    final service = context.read<AudioPlayerService>();
                                    if (service.isPlaying) { service.pause(); } else { service.resume(); }
                                  },
                                ),
                                IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), tooltip: 'Suivant', onPressed: () { /* TODO */ }),
                              ],
                            ),
                          ],
                        );
                      }
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}