// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

// Providers et Modèles (vérifiez la casse des imports !)
import '../providers/home_provider.dart';
import '../models/playlist.dart';
import '../models/song.dart'; // Assurez-vous que c'est 'song.dart' (minuscule s)

// Écrans pour la navigation
import 'playlist_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  /// Constructeur constant pour HomeScreen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Récupère l'instance de HomeProvider. L'écoute des changements (`Provider.of`)
    // provoquera la reconstruction de cet écran (ou de ses parties dépendantes)
    // lorsque les données du provider changent (ex: fin de chargement, erreur).
    final homeProvider = Provider.of<HomeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          // Bouton optionnel pour rafraîchir manuellement les données
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir', // Texte d'aide pour l'accessibilité
            // Appelle la méthode refreshHomeData définie dans le HomeProvider
            onPressed: () => homeProvider.refreshHomeData(),
          ),
        ],
      ),
      // Le corps principal est construit par la méthode privée _buildBody
      body: _buildBody(context, homeProvider),
    );
  }

  /// Construit le widget principal du corps de l'écran.
  /// Gère l'affichage conditionnel basé sur l'état du [homeProvider]:
  /// 1. Indicateur de chargement initial.
  /// 2. Message d'erreur si le chargement initial échoue.
  /// 3. Message "Vide" si aucune donnée n'est disponible après le chargement.
  /// 4. Contenu principal (ListView avec sections) si des données sont disponibles.
  Widget _buildBody(BuildContext context, HomeProvider homeProvider) {
    // --- 1. Gestion de l'état de chargement initial ---
    // Affiche l'indicateur seulement si en chargement ET si le chargement initial
    // n'est pas encore terminé (pour ne pas l'afficher pendant un simple refresh).
    if (homeProvider.isLoading && !homeProvider.isInitialLoadComplete) {
      return const Center(child: CircularProgressIndicator());
    }

    // --- 2. Gestion de l'état d'erreur (après chargement initial échoué) ---
    // Affiche le message d'erreur seulement si une erreur existe,
    // que le chargement est terminé, ET que le chargement initial a échoué.
    if (homeProvider.errorMessage != null &&
        !homeProvider.isLoading &&
        !homeProvider.isInitialLoadComplete) {
      return _buildErrorWidget(context, homeProvider.errorMessage!, () {
        // Action pour réessayer de charger les données
        homeProvider.fetchHomeData();
      });
    }

    // --- 3. Gestion de l'état "Vide" (après chargement réussi mais sans données) ---
    // Affiche ce message si le chargement est terminé, qu'il n'y a pas d'erreur,
    // mais que toutes les listes de contenu sont vides.
    final bool isEmpty = homeProvider.recommendations.isEmpty &&
        homeProvider.popularPlaylists.isEmpty &&
        homeProvider.newReleases.isEmpty;

    if (!homeProvider.isLoading && homeProvider.errorMessage == null && isEmpty) {
      return _buildEmptyContentWidget(context, () {
        // Action pour rafraîchir les données
        homeProvider.refreshHomeData();
      });
    }

    // --- 4. Affichage du contenu principal ---
    // Utilise RefreshIndicator pour permettre le "pull-to-refresh" (tirer pour rafraîchir).
    return RefreshIndicator(
      // Associe le geste de rafraîchissement à l'action du provider
      onRefresh: homeProvider.refreshHomeData,
      child: ListView(
        padding: const EdgeInsets.all(16.0), // Espace autour de la liste
        children: <Widget>[
          // --- Section: Recommandations (Chansons) ---
          // Affiche cette section seulement si la liste des recommandations n'est pas vide.
          if (homeProvider.recommendations.isNotEmpty) ...[
            _buildSectionTitle(context, 'Recommandé pour vous'),
            _buildHorizontalSongList( // Construit la liste horizontale de chansons
              context,
              homeProvider.recommendations, // Passe les données
              onTapSong: (song) { // Définit l'action lors du clic sur une carte chanson
                print("Clic sur Recommandation: ${song.title} par ${song.artist}");
                // TODO: Implémenter la navigation vers l'écran de détail de la chanson/album
                // Exemple: Navigator.push(context, MaterialPageRoute(builder: (_) => SongDetailScreen(song: song)));
                _showTemporaryMessage(context, "Clic sur Recommandation: ${song.title}");
              },
            ),
            const SizedBox(height: 24), // Espace vertical après la section
          ],

          // --- Section: Playlists Populaires ---
          if (homeProvider.popularPlaylists.isNotEmpty) ...[
            _buildSectionTitle(context, 'Playlists populaires'),
            _buildHorizontalPlaylistList( // Construit la liste horizontale de playlists
              context,
              homeProvider.popularPlaylists,
              onTapPlaylist: (playlist) { // Action lors du clic sur une carte playlist
                print("Clic sur Playlist: ${playlist.name}");
                // Navigue vers l'écran de détail de la playlist
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(
                      playlistId: playlist.id,
                      playlistName: playlist.name,
                      // Ajoutez d'autres données nécessaires ici (ex: playlist.imageUrl)
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24), // Espace vertical après la section
          ],

          // --- Section: Nouveautés (Chansons) ---
          if (homeProvider.newReleases.isNotEmpty) ...[
            _buildSectionTitle(context, 'Nouveautés'),
            _buildHorizontalSongList( // Réutilise le widget de liste de chansons
              context,
              homeProvider.newReleases, // Passe les données des nouveautés
              onTapSong: (song) { // Action lors du clic sur une carte nouveauté
                print("Clic sur Nouveauté: ${song.title} par ${song.artist}");
                // TODO: Implémenter la navigation vers l'écran de détail de la chanson/album
                // Exemple: Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: song.albumId)));
                _showTemporaryMessage(context, "Clic sur Nouveauté: ${song.title}");
              },
            ),
            const SizedBox(height: 24), // Espace vertical après la section
          ],

          // Ajoutez d'autres sections ici si nécessaire...
        ],
      ),
    );
  }

  /// Helper Widget pour afficher le titre stylisé d'une section.
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0), // Espacement vertical
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge // Utilise un style de texte plus grand pour les titres
            ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5), // Gras et léger espacement
      ),
    );
  }

  /// Helper Widget pour construire une liste horizontale de [Song]s.
  Widget _buildHorizontalSongList(
      BuildContext context, List<Song> songs,
      {required Function(Song) onTapSong}) {
    // Définit une hauteur fixe pour contraindre la ListView horizontale.
    const double listHeight = 210; // Hauteur ajustée pour les cartes de chansons

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, // Permet le défilement horizontal
        itemCount: songs.length, // Nombre total d'éléments à construire
        itemBuilder: (context, index) {
          final song = songs[index]; // Récupère la chanson pour cet index
          // Pour chaque chanson, crée une _SongCardItem.
          // Ce widget enfant gérera l'état de lecture audio individuellement.
          return _SongCardItem(song: song, onCardTap: onTapSong);
        },
      ),
    );
  }

  /// Helper Widget pour construire une liste horizontale de [Playlist]s.
  Widget _buildHorizontalPlaylistList(
      BuildContext context, List<Playlist> playlists,
      {required Function(Playlist) onTapPlaylist}) {
    // Définit une hauteur fixe pour contraindre la ListView horizontale.
    const double listHeight = 190; // Hauteur ajustée pour les cartes de playlists

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index]; // Récupère la playlist pour cet index
          // Pour chaque playlist, crée une _PlaylistCardItem (widget stateless).
          return _PlaylistCardItem(playlist: playlist, onCardTap: onTapPlaylist);
        },
      ),
    );
  }

  /// Helper Widget pour afficher l'état d'erreur.
  Widget _buildErrorWidget(BuildContext context, String errorMessage, VoidCallback onRetry) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage, // Affiche le message d'erreur spécifique
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: onRetry, // Appelle la fonction de rechargement
              )
            ],
          ),
        )
    );
  }

  /// Helper Widget pour afficher l'état de contenu vide.
  Widget _buildEmptyContentWidget(BuildContext context, VoidCallback onRefresh) {
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              Icon(Icons.music_off_outlined, size: 60, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'Aucun contenu disponible',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Revenez plus tard ou essayez de rafraîchir.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Rafraîchir'),
                onPressed: onRefresh, // Appelle la fonction de rafraîchissement
              )
            ]
        )
    );
  }

  /// Helper simple pour afficher un message temporaire (SnackBar).
  void _showTemporaryMessage(BuildContext context, String message){
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Cache l'ancienne si elle existe
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
    ));
  }
}


// -----------------------------------------------------------------------------
// --- Widget Carte Chanson (Stateful pour gérer l'AudioPlayer) ---
// -----------------------------------------------------------------------------

class _SongCardItem extends StatefulWidget {
  /// La chanson à afficher.
  final Song song;
  /// La fonction à appeler lorsque l'utilisateur clique sur la carte (pour la navigation).
  final Function(Song) onCardTap;

  /// Constructeur pour _SongCardItem.
  const _SongCardItem({
    required this.song,
    required this.onCardTap,
    super.key, // Bonne pratique: inclure la Key
  });

  @override
  _SongCardItemState createState() => _SongCardItemState();
}

class _SongCardItemState extends State<_SongCardItem> {
  // Instance d'AudioPlayer spécifique à cette carte.
  final AudioPlayer _audioPlayer = AudioPlayer();
  // Variables d'état pour suivre la lecture.
  PlayerState? _playerState; // État détaillé du lecteur (playing, paused, etc.)
  bool _isPlaying = false;    // Indicateur simplifié: lecture en cours ou non
  bool _isLoading = false; // Indicateur pour le chargement initial de l'audio

  @override
  void initState() {
    super.initState();


    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // --- Écouteurs pour les changements d'état de l'AudioPlayer ---

    // Écouteur principal pour les changements d'état (play, pause, stop, etc.)
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      // Vérifie si le widget est toujours 'monté' (affiché à l'écran)
      // avant d'appeler setState pour éviter les erreurs.
      if (mounted) {
        setState(() {
          _playerState = state;
          _isPlaying = state == PlayerState.playing;
          // Masque l'indicateur de chargement dès que la lecture démarre
          // ou s'arrête (pause, stop, complété).
          if (state != PlayerState.completed && state != PlayerState.stopped) { // Ajusté pour plus de précision
            _isLoading = false;
          }
        });
      }
    }, onError: (message) { // Gestion des erreurs du lecteur
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isLoading = false; // Arrête le chargement en cas d'erreur
          print("Audio Player Error (Song: ${widget.song.id}): $message");
          // Affiche un message d'erreur concis à l'utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur de lecture audio.'), duration: Duration(seconds: 3))
          );
        });
      }
    });

    // Écouteur pour la fin de la lecture
    _audioPlayer.onPlayerComplete.listen((event) {
      if(mounted){
        setState(() {
          // Réinitialise l'état lorsque la chanson est terminée
          _isPlaying = false;
          _isLoading = false;
          _playerState = PlayerState.completed;
        });
      }
    });
  }

  @override
  void dispose() {
    // --- TRÈS IMPORTANT: Libération des ressources ---
    // Libère les ressources natives et Dart associées à cet AudioPlayer
    // lorsque le widget _SongCardItem est retiré de l'arbre des widgets.
    // Oublier cette étape peut causer des fuites de mémoire et des comportements inattendus.
    _audioPlayer.release(); // Libère les ressources natives (appelle stop())
    _audioPlayer.dispose(); // Libère les ressources Dart
    super.dispose();
  }

  /// Gère l'action de cliquer sur le bouton Play/Pause.
  Future<void> _playPause() async {
    // Si une autre chanson joue via un autre player, elle ne sera pas arrêtée ici.
    // La gestion globale nécessite un state manager (Provider, Riverpod, Bloc...).

    if (_isPlaying) {
      // Si la chanson est en cours de lecture -> Mettre en Pause
      try {
        await _audioPlayer.pause();
        // L'état (_isPlaying, _isLoading) sera mis à jour par le listener onPlayerStateChanged
      } catch (e) {
        print("Error pausing audio (Song: ${widget.song.id}): $e");
        if (mounted) setState(() => _isLoading = false); // Assure que loading disparaît
      }
    } else {
      // Si la chanson n'est pas en cours de lecture -> Lancer la Lecture
      // Vérifie d'abord si une URL audio valide est disponible
      if (widget.song.urlAudio.isNotEmpty) {
        if(mounted) setState(() => _isLoading = true); // Affiche l'indicateur de chargement
        try {
          // Lance la lecture depuis l'URL fournie
          await _audioPlayer.play(UrlSource(widget.song.urlAudio));
          // L'état (_isPlaying, _isLoading) sera mis à jour par le listener onPlayerStateChanged
        } catch (e) {
          print("Error playing audio (Song: ${widget.song.id}): $e");
          if (mounted) {
            setState(() => _isLoading = false); // Masque l'indicateur en cas d'erreur
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Erreur: Impossible de charger l\'audio.'))
            );
          }
        }
      } else {
        // Gère le cas où l'URL audio est manquante ou invalide
        print("Cannot play song '${widget.song.title}': Audio URL is empty or invalid.");
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('URL audio manquante ou invalide.'))
          );
          // S'assure que l'indicateur de chargement est caché si on n'a pas pu jouer
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Récupère l'URL de l'image de couverture, peut être null.
    final String? imageUrl = widget.song.coverImage;
    // Icône à afficher si l'image n'est pas disponible.
    const IconData fallbackIcon = Icons.music_note;

    return Container(
      width: 150, // Largeur fixe pour chaque carte dans la liste horizontale
      margin: const EdgeInsets.only(right: 12.0), // Marge à droite pour espacer les cartes
      child: Card(
        elevation: 3, // Légère ombre portée pour détacher la carte
        clipBehavior: Clip.antiAlias, // Assure que l'image est coupée aux coins arrondis
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Coins arrondis
        child: InkWell( // Rend la carte entière cliquable pour la navigation
          onTap: () => widget.onCardTap(widget.song), // Appelle la fonction de navigation fournie
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Aligne les textes à gauche
            children: [
              // --- Zone de l'Image de Couverture ---
              SizedBox(
                height: 110, // Hauteur définie pour l'image
                width: double.infinity, // L'image prend toute la largeur de la carte
                child: (imageUrl != null && imageUrl.isNotEmpty)
                // Si une URL d'image existe, tente de la charger depuis le réseau
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover, // Redimensionne l'image pour remplir la zone
                  // Widget à afficher pendant le chargement de l'image
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child; // Image chargée
                    // Affiche un indicateur de progression circulaire
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        // Calcule la progression si la taille totale est connue
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null, // Sinon, indicateur indéterminé
                      ),
                    );
                  },
                  // Widget à afficher si le chargement de l'image échoue
                  errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
                )
                // Si l'URL de l'image est nulle ou vide, affiche l'icône par défaut
                    : Center(
                    child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
              ),

              // --- Zone d'Information (Titre et Artiste) ---
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0), // Espacement interne
                child: Text(
                  widget.song.title, // Affiche le titre de la chanson
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), // Style du titre
                  maxLines: 1, // Limite à une seule ligne
                  overflow: TextOverflow.ellipsis, // Ajoute "..." si le texte est trop long
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0), // Espacement horizontal
                child: Text(
                  // Affiche le nom de l'artiste (vient du champ 'artist' du modèle Song)
                  widget.song.artist,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]), // Style pour l'artiste
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // --- Zone du Bouton Play/Pause ---
              // Utilise Spacer pour pousser le bouton vers le bas dans l'espace restant.
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 4.0), // Petite marge à droite du bouton
                child: Align( // Aligne le bouton sur le côté droit de la carte
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    // Affiche un indicateur de chargement si _isLoading est true
                    icon: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    // Sinon, affiche l'icône Play ou Pause en fonction de _isPlaying
                        : Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      // Utilise la couleur primaire définie dans le thème de l'application
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    iconSize: 36.0, // Taille de l'icône du bouton
                    tooltip: _isPlaying ? 'Mettre en pause' : 'Lire', // Texte d'aide
                    onPressed: _playPause, // Appelle la fonction _playPause lors du clic
                  ),
                ),
              ),
              // Petit espace en bas de la carte pour l'esthétique
              const SizedBox(height: 4)
            ],
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// --- Widget Carte Playlist (Stateless car simple affichage) ---
// -----------------------------------------------------------------------------

/// Un widget représentant une carte cliquable pour une playlist.
/// C'est un [StatelessWidget] car il n'a pas besoin de gérer d'état interne complexe.
class _PlaylistCardItem extends StatelessWidget {
  /// La playlist à afficher.
  final Playlist playlist;
  /// La fonction à appeler lorsque l'utilisateur clique sur la carte (pour la navigation).
  final Function(Playlist) onCardTap;

  /// Constructeur pour _PlaylistCardItem.
  const _PlaylistCardItem({
    required this.playlist,
    required this.onCardTap,
    super.key, // Bonne pratique
  });

  @override
  Widget build(BuildContext context) {
    // Récupère l'URL de l'image de la playlist (suppose que le modèle Playlist a ce champ).
    final String? imageUrl = playlist.imageUrl;
    // Icône à afficher si l'image n'est pas disponible.
    const IconData fallbackIcon = Icons.playlist_play;

    return Container(
      width: 140, // Largeur fixe pour chaque carte
      margin: const EdgeInsets.only(right: 12.0), // Marge à droite pour espacer les cartes
      child: Card(
        elevation: 2, // Légère ombre
        clipBehavior: Clip.antiAlias, // Coupe l'image aux coins arrondis
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Coins arrondis
        child: InkWell( // Rend la carte cliquable
          onTap: () => onCardTap(playlist), // Appelle la fonction de navigation
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Aligne les textes à gauche
            children: [
              // --- Zone de l'Image ---
              SizedBox(
                height: 100, // Hauteur définie pour l'image
                width: double.infinity, // Prend toute la largeur
                child: (imageUrl != null && imageUrl.isNotEmpty)
                // Charge l'image si l'URL existe
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  // Widget affiché pendant le chargement
                  loadingBuilder:(context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  // Widget affiché en cas d'erreur de chargement
                  errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
                )
                // Affiche l'icône par défaut si pas d'URL d'image
                    : Center(
                    child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
              ),
              // --- Zone d'Information (Titre et Description/Nombre) ---
              Padding(
                padding: const EdgeInsets.all(8.0), // Espacement interne
                child: Text(
                  playlist.name, // Affiche le nom de la playlist
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                // Espacement horizontal et un peu d'espace en bas
                padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 8.0),
                child: Text(
                  // Affiche la description si elle existe, sinon le nombre de chansons ou un texte par défaut.
                  playlist.description ?? (playlist.songs.isNotEmpty ? '${playlist.songs.length} morceaux' : 'Playlist'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}