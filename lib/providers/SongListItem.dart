// lib/widgets/song_list_item.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../screens/now_playing_screen.dart'; // Assurez-vous que l'écran existe
import '../services/audio_player_service.dart';
import '../providers/auth_provider.dart'; // Importer le provider Auth

class SongListItem extends StatelessWidget {
  final Song song;
  final String baseUrl; // Requis pour l'URL de l'image

  const SongListItem({
    Key? key,
    required this.song,
    required this.baseUrl,
  }) : super(key: key);

  // Widget image avec gestion asynchrone du token
  Widget _buildLeadingImage(BuildContext context, AuthProvider authProvider) {
    final String imageUrl = '$baseUrl/api/songs/${song.id}/image';
    return SizedBox(
      width: 50,
      height: 50,
      child: FutureBuilder<String?>(
        // Appelle la méthode asynchrone pour obtenir le token
        future: authProvider.getToken(),
        builder: (context, tokenSnapshot) {
          // Indicateur pendant chargement token
          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          // Placeholder si pas de token
          if (!tokenSnapshot.hasData || tokenSnapshot.data == null) {
            return const Center(child: Icon(Icons.music_note));
          }

          // Token obtenu, préparer headers et charger image
          final token = tokenSnapshot.data!;
          // IMPORTANT: S'assurer que le format du token est correct (avec ou sans 'Bearer ')
          // final headers = {'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token'};
          final headers = {'Authorization': token }; // Supposant que le token inclut déjà 'Bearer ' si nécessaire

          return Image.network(
            imageUrl,
            headers: headers, // Envoyer le token
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (ctx, error, stackTrace) {
              print("[SongListItem] Error loading image $imageUrl: $error");
              // Gérer l'erreur (ex: afficher une icône différente si 401 vs 404)
              // if (error.toString().contains('401') || error.toString().contains('403')) {
              //   return const Center(child: Icon(Icons.lock_outline)); // Non autorisé
              // }
              return const Center(child: Icon(Icons.broken_image)); // Erreur générique
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Accéder aux services via Provider
    final audioService = context.watch<AudioPlayerService>();
    // Utiliser 'read' pour authProvider car on n'a besoin du token que dans le FutureBuilder
    final authProvider = context.read<AuthProvider>();

    // Déterminer l'état pour l'UI (identique)
    final bool isCurrentSong = audioService.currentSong?.id == song.id;
    final bool isLoading = isCurrentSong && audioService.isLoading;
    final bool isPlaying = isCurrentSong && audioService.isPlaying;

    return ListTile(
      leading: _buildLeadingImage(context, authProvider), // Utilise le builder d'image
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        // Icône et état (identique)
        icon: isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        iconSize: 40.0,
        tooltip: isPlaying ? 'Mettre en pause' : 'Lire',
        color: isCurrentSong ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color,
        // Actions Play/Pause (identique)
        onPressed: isLoading ? null : () {
          if (isPlaying) { audioService.pause(); }
          else if (isCurrentSong) { audioService.resume(); }
          else { audioService.play(song); }
        },
      ),
      onTap: () {
        print("[SongListItem] Tapped on song: ${song.title} (ID: ${song.id})");
        // Lance la lecture via le service global
        context.read<AudioPlayerService>().play(song);
        // Navigue vers NowPlayingScreen en passant l'URL de base
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => NowPlayingScreen(baseUrl: baseUrl) // PASSER baseUrl
        ));
      },
    );
  }
}