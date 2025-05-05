// lib/widgets/song_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';                 // Votre modèle Song (sans URLs)
import '../providers/auth_provider.dart';      // Pour obtenir le token pour l'image
import '../services/audio_player_service.dart'; // Pour l'état et les actions de lecture
import '../screens/now_playing_screen.dart';   // Pour la navigation au clic

class SongCard extends StatelessWidget {
  /// La chanson à afficher.
  final Song song;
  /// L'URL de base du backend, nécessaire pour construire l'URL de l'image.
  final String baseUrl;

  const SongCard({
    Key? key,
    required this.song,
    required this.baseUrl,
  }) : super(key: key);

  /// Construit le widget affichant l'image de couverture.
  /// Utilise un FutureBuilder pour obtenir le token d'authentification de manière asynchrone
  /// avant de lancer la requête Image.network avec les headers appropriés.
  Widget _buildCoverImage(BuildContext context, AuthProvider authProvider) {
    // Construit l'URL complète vers l'endpoint de l'image sur le backend.
    final String imageUrl = '$baseUrl/api/songs/${song.id}/image';
    // Taille définie pour l'image dans la carte.
    const double imageSize = 110.0;

    // Widget affiché par défaut ou pendant le chargement/erreur.
    Widget placeholder = Container(
      height: imageSize,
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3), // Couleur de fond placeholder légère
      child: Center(child: Icon(Icons.music_note, size: 40, color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.5))),
    );

    return SizedBox(
      height: imageSize,
      width: double.infinity,
      child: FutureBuilder<String?>(
        // Appelle la méthode asynchrone pour récupérer le token.
        future: authProvider.getToken(),
        builder: (context, tokenSnapshot) {
          // 1. Gérer l'état de chargement du token
          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return placeholder; // Ou un spinner plus explicite: Center(child: CircularProgressIndicator(strokeWidth: 2))
          }

          // 2. Gérer le cas où le token n'est pas disponible (non connecté, erreur token)
          if (!tokenSnapshot.hasData || tokenSnapshot.data == null) {
            // Logguer l'absence de token pour le débogage.
            if (tokenSnapshot.connectionState == ConnectionState.done) {
              print("[SongCard] Token non disponible pour l'image: ${song.id}");
            }
            return placeholder;
          }

          // 3. Token obtenu, préparer les headers et charger l'image réelle.
          final token = tokenSnapshot.data!;
          // S'assurer que le format du token est correct (ex: ajouter 'Bearer ' si nécessaire)
          // final headers = {'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token'};
          final headers = {'Authorization': token }; // Supposant que getToken retourne le header formaté

          return Image.network(
            imageUrl,
            headers: headers, // <-- Le token est envoyé ici
            height: imageSize,
            width: double.infinity,
            fit: BoxFit.cover, // S'assure que l'image remplit l'espace
            // Widget affiché pendant le chargement de l'image
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child; // Image chargée
              return Container(
                  height: imageSize, width: double.infinity, color: Colors.grey.shade300,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2))
              );
            },
            // Widget affiché en cas d'erreur de chargement de l'image
            errorBuilder: (ctx, error, stackTrace) {
              print("[SongCard] Erreur chargement image $imageUrl: $error");
              // Afficher une icône d'erreur distincte.
              return Container(
                  height: imageSize, width: double.infinity, color: Colors.grey.shade300,
                  child: Center(child: Icon(Icons.error_outline, size: 40, color: Colors.grey.shade600))
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Accéder aux services via Provider.
    // 'watch' écoute les changements de AudioPlayerService pour mettre à jour l'UI (ex: icône play/pause).
    final audioService = context.watch<AudioPlayerService>();
    // 'read' est suffisant pour AuthProvider car on a besoin du token seulement dans le FutureBuilder.
    final authProvider = context.read<AuthProvider>();

    // Déterminer l'état de lecture pour cette chanson spécifique.
    final bool isCurrentSong = audioService.currentSong?.id == song.id;
    final bool isLoading = isCurrentSong && audioService.isLoading;
    final bool isPlaying = isCurrentSong && audioService.isPlaying;

    return Container(
      width: 150, // Largeur fixe pour chaque carte dans la liste horizontale.
      margin: const EdgeInsets.only(right: 12.0), // Espacement à droite des cartes.
      child: Card(
        elevation: 3, // Ombre portée.
        clipBehavior: Clip.antiAlias, // Pour que l'image respecte les coins arrondis.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Coins arrondis.
        child: InkWell( // Rend toute la carte cliquable pour lancer la lecture/navigation.
          onTap: () {
            print("[SongCard] Carte cliquée pour : ${song.title} (ID: ${song.id})");
            // Demande au service audio de jouer cette chanson.
            context.read<AudioPlayerService>().play(song);
            // Navigue vers l'écran de lecture en cours.
            Navigator.push(context, MaterialPageRoute(
              // Passe l'URL de base nécessaire à NowPlayingScreen pour charger l'image.
                builder: (_) => NowPlayingScreen(baseUrl: baseUrl)
            ));
          },
          child: Column( // Structure verticale : Image > Texte > Bouton
            crossAxisAlignment: CrossAxisAlignment.start, // Aligner le texte à gauche.
            children: [
              // --- Zone Image ---
              _buildCoverImage(context, authProvider),

              // --- Zone Texte ---
              Padding(
                padding: const EdgeInsets.fromLTRB(10.0, 8.0, 10.0, 0), // Padding pour le texte
                child: Text(
                  song.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold, // Titre en gras
                      fontSize: 13 // Taille légèrement ajustée
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  song.artist, // Assurez-vous que 'artist' est dans votre modèle Song
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600, // Couleur plus discrète
                      fontSize: 11 // Taille légèrement ajustée
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // --- Zone Bouton Play/Pause ---
              const Spacer(), // Occupe l'espace vertical restant pour pousser le bouton en bas.
              Padding(
                padding: const EdgeInsets.only(right: 4.0, bottom: 4.0), // Léger padding autour du bouton.
                child: Align( // Aligner le bouton à droite.
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    iconSize: 34.0, // Taille de l'icône.
                    // Affiche un indicateur de chargement si l'audio de CETTE chanson charge.
                    icon: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                    // Sinon, affiche l'icône Play ou Pause.
                        : Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, // Icônes arrondies
                      color: isCurrentSong ? Theme.of(context).colorScheme.primary : Theme.of(context).iconTheme.color?.withOpacity(0.8), // Couleur différente si active
                    ),
                    tooltip: isPlaying ? 'Mettre en pause' : 'Lire ${song.title}', // Tooltip dynamique.
                    // Action déclenchée au clic sur le bouton.
                    onPressed: isLoading ? null : () { // Désactiver le bouton pendant le chargement.
                      if (isPlaying) {
                        audioService.pause(); // Demande de pause au service global.
                      } else if (isCurrentSong) {
                        audioService.resume(); // Demande de reprise si c'est la chanson actuelle en pause.
                      } else {
                        audioService.play(song); // Demande de jouer cette nouvelle chanson.
                      }
                    },
                  ), // Fin IconButton
                ), // Fin Align
              ), // Fin Padding
            ], // Fin children Column
          ), // Fin Column
        ), // Fin InkWell
      ), // Fin Card
    ); // Fin Container
  }
}