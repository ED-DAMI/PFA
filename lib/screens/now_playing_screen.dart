// lib/screens/now_playing_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart'; // Votre service audio
import '../providers/auth_provider.dart';      // Votre provider d'authentification
import '../models/song.dart';                 // Votre modèle Song (SANS coverImage URL)

class NowPlayingScreen extends StatelessWidget {
  // --- REQUIS: L'URL de base du backend ---
  // Doit être passée lors de la navigation vers cet écran.
  final String baseUrl;

  const NowPlayingScreen({
    Key? key,
    required this.baseUrl, // Accepter baseUrl
  }) : super(key: key);

  // Helper pour formater la durée (inchangé)
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // --- Widget pour afficher l'image de couverture via API ---
  Widget _buildCoverArt(BuildContext context, Song currentSong, AuthProvider authProvider) {
    // Construire l'URL de l'endpoint image
    final String imageUrl = '$baseUrl/api/songs/${currentSong.id}/image';
    final double imageSize = MediaQuery.of(context).size.width * 0.7; // Taille de l'image

    // Widget placeholder affiché pendant le chargement ou en cas d'erreur
    Widget placeholder = Container(
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5), // Fond semi-transparent
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(color: Colors.white24), // Légère bordure
      ),
      child: const Center(child: Icon(Icons.music_note, size: 100, color: Colors.white70)),
    );

    return ClipRRect( // Pour les coins arrondis
      borderRadius: BorderRadius.circular(15.0),
      child: FutureBuilder<String?>(
        // 1. Obtenir le token de manière asynchrone
        future: authProvider.getToken(), // Utilise la méthode du provider
        builder: (context, tokenSnapshot) {
          // Afficher placeholder pendant la récupération du token
          if (tokenSnapshot.connectionState == ConnectionState.waiting) {
            return placeholder; // Ou un spinner si préféré
          }

          // Afficher placeholder si pas de token (non authentifié ou erreur)
          if (!tokenSnapshot.hasData || tokenSnapshot.data == null) {
            print("[NowPlayingScreen] No token available for image request.");
            return placeholder;
          }

          // 2. Token obtenu, construire les headers et charger l'image
          final token = tokenSnapshot.data!;
          // Assurer le format correct du token (ex: ajouter 'Bearer ')
          // final headers = {'Authorization': token.startsWith('Bearer ') ? token : 'Bearer $token'};
          final headers = {'Authorization': token }; // Supposant que getToken retourne le header complet

          print("[NowPlayingScreen] Fetching image: $imageUrl with token.");

          return Image.network(
            imageUrl,
            headers: headers, // <-- PASSER LE TOKEN DANS LES HEADERS
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            // Widget affiché pendant le chargement de l'image elle-même
            loadingBuilder: (ctx, child, loadingProgress) {
              if (loadingProgress == null) return child; // Image chargée
              // Afficher un indicateur de progression pendant le chargement de l'image
              return Container(
                width: imageSize,
                height: imageSize,
                color: Colors.grey.shade700, // Fond pendant le chargement
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null, // Progression si disponible
                  ),
                ),
              );
            },
            // Widget affiché si le chargement de l'image échoue
            errorBuilder: (ctx, error, stackTrace) {
              print("[NowPlayingScreen] Error loading cover image $imageUrl: $error");
              // Gérer différents types d'erreur si nécessaire
              // Par exemple, si c'est une erreur 401/403 vs 404 vs autre
              return Container( // Afficher une icône d'erreur
                width: imageSize,
                height: imageSize,
                color: Colors.grey.shade600,
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 80, color: Colors.white60)),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Accéder aux Providers ---
    final audioService = context.watch<AudioPlayerService>(); // Écoute les changements audio
    final authProvider = context.read<AuthProvider>();      // Lit une seule fois pour le token
    final currentSong = audioService.currentSong;           // La chanson en cours

    // --- Définir un dégradé par défaut ---
    // Réagir au chargement de l'image pour changer le fond est complexe ici.
    final List<Color> gradientColors = [
      Colors.deepPurple.shade700, // Couleur de départ par défaut
      Colors.black87              // Couleur de fin par défaut
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSong?.title ?? 'Lecture en cours'), // Titre dynamique ou par défaut
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new), // Icône retour plus standard
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true, // Le corps passe derrière l'AppBar
      body: Container(
        width: double.infinity, // Pleine largeur
        height: double.infinity, // Pleine hauteur
        decoration: BoxDecoration(
          gradient: LinearGradient( // Utilise le dégradé défini
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        // Utiliser SafeArea pour éviter que le contenu passe sous la barre de statut/notch
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 20.0), // Ajouter padding en bas
            child: Center(
              child: currentSong == null
              // Affichage si aucune chanson n'est sélectionnée/en cours
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
              // Affichage principal quand une chanson est chargée
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1), // Moins d'espace en haut

                  // --- Image de Couverture (via le helper) ---
                  _buildCoverArt(context, currentSong, authProvider),

                  const SizedBox(height: 35), // Augmenter espace

                  // --- Titre et Artiste ---
                  Text(
                    currentSong.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, // Permettre 2 lignes pour le titre
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentSong.artist, // Assurez-vous que `artist` est dans le modèle Song
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1,
                  ),
                  const SizedBox(height: 35), // Augmenter espace

                  // --- Barre de Progression ---
                  Column(
                    children: [
                      SliderTheme( // Style (inchangé)
                        data: SliderTheme.of(context).copyWith( /* ... styles ... */ trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 15.0), activeTrackColor: Colors.white, inactiveTrackColor: Colors.white.withOpacity(0.3), thumbColor: Colors.white, overlayColor: Colors.white.withAlpha(80)),
                        child: Slider(
                          value: (audioService.currentPosition.inMilliseconds > 0 && audioService.totalDuration.inMilliseconds > 0 && audioService.currentPosition <= audioService.totalDuration)
                              ? audioService.currentPosition.inMilliseconds.toDouble() : 0.0,
                          min: 0.0,
                          max: audioService.totalDuration.inMilliseconds > 0
                              ? audioService.totalDuration.inMilliseconds.toDouble() : 1.0, // Max 1.0 si durée inconnue
                          onChanged: (value) {
                            // Permettre le seek seulement si une durée est connue
                            if (audioService.totalDuration > Duration.zero) {
                              context.read<AudioPlayerService>().seek(Duration(milliseconds: value.toInt()));
                            }
                          },
                        ),
                      ),
                      Padding( // Temps (inchangé)
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(_formatDuration(audioService.currentPosition), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(_formatDuration(audioService.totalDuration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25), // Augmenter espace

                  // --- Contrôles de Lecture ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Mieux espacer les boutons
                    children: [
                      // Bouton Précédent
                      IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), tooltip: 'Précédent', onPressed: () { /* TODO */ },),
                      // Bouton Play/Pause/Loading
                      IconButton(
                        iconSize: 75.0, // Légèrement plus grand
                        icon: audioService.isLoading
                            ? const SizedBox(width: 65, height: 65, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) // Indicateur plus visible
                            : Icon(audioService.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white), // Icônes arrondies
                        tooltip: audioService.isPlaying ? 'Mettre en pause' : 'Lire',
                        onPressed: audioService.isLoading ? null : () { // Action inchangée
                          if (audioService.isPlaying) { audioService.pause(); } else { audioService.resume(); }
                        },
                      ),
                      // Bouton Suivant
                      IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), tooltip: 'Suivant', onPressed: () { /* TODO */ },),
                    ],
                  ),
                  const Spacer(flex: 2), // Moins d'espace en bas
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}