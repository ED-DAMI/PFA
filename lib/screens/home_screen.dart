// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Providers et Modèles (vérifiez les chemins et la casse !)
import '../config/api_config.dart';
import '../providers/SongListItem.dart';
import '../providers/home_provider.dart'; // Pour les données d'accueil
import '../models/playlist.dart';       // Modèle Playlist
import '../models/song.dart';          // Modèle Song (SANS urlAudio/coverImage)
// import '../providers/auth_provider.dart'; // Pas besoin ici si SongListItem le gère
// import '../services/audio_player_service.dart'; // Pas besoin ici si SongListItem le gère

// Widgets et Écrans
// <-- LE WIDGET CORRIGÉ À UTILISER
import 'playlist_detail_screen.dart';   // Écran détail playlist
import 'now_playing_screen.dart';      // Écran lecture en cours

class HomeScreen extends StatelessWidget {

  final String baseUrl = API_BASE_URL; // !! ADAPTER CETTE URL !!

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accéder au HomeProvider pour obtenir les listes de données
    final homeProvider = Provider.of<HomeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Musique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            // Désactiver pendant le chargement pour éviter appels multiples
            onPressed: homeProvider.isLoading ? null : () => homeProvider.refreshHomeData(),
          ),
        ],
      ),
      // Le corps est construit par _buildBody qui gère les états
      body: _buildBody(context, homeProvider),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Lecture en cours',
        child: const Icon(Icons.play_arrow_rounded), // Icône plus adaptée
        onPressed: () {
          // Naviguer vers NowPlayingScreen en passant l'URL de base
          Navigator.push(context, MaterialPageRoute(
            // Passer baseUrl, car NowPlayingScreen en a besoin pour charger l'image
              builder: (_) => NowPlayingScreen(baseUrl: baseUrl)
          ));
        },
      ),
    );
  }

  // Construit le corps principal en fonction de l'état du HomeProvider
  Widget _buildBody(BuildContext context, HomeProvider homeProvider) {
    // --- Gestion état chargement/erreur/vide (Logique inchangée) ---
    if (homeProvider.isLoading && !homeProvider.isInitialLoadComplete) {
      return const Center(child: CircularProgressIndicator());
    }
    if (homeProvider.errorMessage != null && !homeProvider.isInitialLoadComplete) {
      return _buildErrorWidget(context, homeProvider.errorMessage!, () => homeProvider.fetchHomeData());
    }
    final bool isEmpty = homeProvider.recommendations.isEmpty &&
        homeProvider.popularPlaylists.isEmpty &&
        homeProvider.newReleases.isEmpty;
    if (!homeProvider.isLoading && homeProvider.errorMessage == null && isEmpty) {
      return _buildEmptyContentWidget(context, () => homeProvider.refreshHomeData());
    }
    // --- Fin gestion état ---

    // --- Affichage du Contenu Principal ---
    return RefreshIndicator(
      onRefresh: homeProvider.refreshHomeData,
      child: ListView( // Liste verticale pour les sections
        // Utiliser padding vertical seulement, le padding horizontal sera dans les listes internes
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: <Widget>[
          // --- Section: Recommandations (Chansons) ---
          if (homeProvider.recommendations.isNotEmpty) ...[
            // Ajouter le titre DANS la zone de padding horizontal de la liste
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionTitle(context, 'Recommandé pour vous'),
            ),
            // Appel à la méthode qui utilise SongListItem
            _buildHorizontalSongList(context, homeProvider.recommendations),
            const SizedBox(height: 24.0), // Espace entre sections
          ],

          // --- Section: Playlists Populaires ---
          if (homeProvider.popularPlaylists.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionTitle(context, 'Playlists populaires'),
            ),
            // Appel à la méthode qui utilise _PlaylistCardItem
            _buildHorizontalPlaylistList(context, homeProvider.popularPlaylists),
            const SizedBox(height: 24.0),
          ],

          // --- Section: Nouveautés (Chansons) ---
          if (homeProvider.newReleases.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildSectionTitle(context, 'Nouveautés'),
            ),
            // Réutilise la méthode qui utilise SongListItem
            _buildHorizontalSongList(context, homeProvider.newReleases),
            const SizedBox(height: 24.0),
          ],
          // Ajoutez d'autres sections si nécessaire...
        ],
      ),
    );
  }

  // --- Widgets Helpers ---

  // Helper pour les titres de section
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0), // Espacement vertical titre
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // **** MÉTHODE MISE À JOUR POUR UTILISER SongListItem ****
  /// Construit la liste horizontale de chansons en utilisant le widget externe [SongListItem].
  Widget _buildHorizontalSongList(BuildContext context, List<Song> songs) {
    // Hauteur typique pour un ListTile standard. Ajustez si votre SongListItem a une taille différente.
    const double itemHeight = 72.0;

    return SizedBox(
      height: itemHeight, // Contraint la hauteur de la liste horizontale
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Padding horizontal pour que les items ne collent pas aux bords de l'écran
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          // Chaque élément de la liste est maintenant un SongListItem.
          // SongListItem gère l'affichage de son image (avec token)
          // et le déclenchement de la lecture via AudioPlayerService.
          return Container(
            // Donner une largeur à chaque item pour le défilement horizontal
            width: MediaQuery.of(context).size.width * 0.8, // Ex: 80% de la largeur écran
            padding: const EdgeInsets.only(right: 8.0), // Espace entre les items
            child: SongListItem(
              song: song,
              baseUrl: baseUrl, // Passe l'URL de base, nécessaire pour l'image dans SongListItem
            ),
          );
        },
      ),
    );
  }

  // Helper pour construire la liste horizontale de playlists
  Widget _buildHorizontalPlaylistList(
      BuildContext context, List<Playlist> playlists) {
    const double listHeight = 190; // Hauteur pour les cartes playlist

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding pour la liste
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          // Utilise le widget _PlaylistCardItem (supposé défini et correct)
          return _PlaylistCardItem(
              playlist: playlist,
              onCardTap: (pl) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaylistDetailScreen(
                      playlistId: pl.id,
                      playlistName: pl.name,
                      baseUrl: baseUrl, // Passer baseUrl aussi
                    ),
                  ),
                );
              });
        },
      ),
    );
  }

  // Helper pour afficher l'état d'erreur (inchangé)
  Widget _buildErrorWidget(BuildContext context, String errorMessage, VoidCallback onRetry) {
    return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 50), const SizedBox(height: 16),
      Text('Erreur', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)), const SizedBox(height: 20),
      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Réessayer'), onPressed: onRetry)
    ],),));
  }

  // Helper pour afficher l'état vide (inchangé)
  Widget _buildEmptyContentWidget(BuildContext context, VoidCallback onRefresh) {
    return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
      const Icon(Icons.cloud_off, size: 50, color: Colors.grey), const SizedBox(height: 16), // Icône différente
      Text('Rien à afficher', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      const Text('Le contenu se chargera ici.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center), const SizedBox(height: 20),
      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Rafraîchir'), onPressed: onRefresh)
    ])));
  }

// Helper SnackBar (peut être retiré si le TODO utilisant onTapSong est enlevé)
// void _showTemporaryMessage(BuildContext context, String message){ ... }

} // Fin de HomeScreen


// -----------------------------------------------------------------------------
// --- !!! SECTION _SongCardItem et _SongCardItemState DOIT ÊTRE SUPPRIMÉE !!! ---
// -----------------------------------------------------------------------------


// --- Widget Carte Playlist (Garder s'il est utilisé et correct) ---
// Assurez-vous que ce widget existe, est stateless et utilise playlist.imageUrl
class _PlaylistCardItem extends StatelessWidget {
  final Playlist playlist; // Assurez-vous que Playlist a le champ imageUrl
  final Function(Playlist) onCardTap;

  const _PlaylistCardItem({required this.playlist, required this.onCardTap, super.key});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = playlist.imageUrl; // Utiliser le champ du modèle
    const IconData fallbackIcon = Icons.playlist_play;
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12.0),
      child: Card( elevation: 2, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(onTap: () => onCardTap(playlist),
          child: Column( crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox( height: 100, width: double.infinity,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? Image.network( imageUrl, fit: BoxFit.cover,
                  loadingBuilder:(ctx, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(strokeWidth: 2, value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                  errorBuilder: (ctx, error, stackTrace) => Center(child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
                )
                    : Center( child: Icon(fallbackIcon, size: 40, color: Colors.grey[600])),
              ),
              Padding(padding: const EdgeInsets.all(8.0),
                child: Text(playlist.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis,), // Permettre 2 lignes pour le nom
              ),
              Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 8.0),
                child: Text( playlist.description ?? (playlist.songs.length == 1 ? '1 titre' : '${playlist.songs.length} titres'), // Afficher nombre de titres
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis,),
              ),
            ],
          ),
        ),
      ),
    );
  }
}