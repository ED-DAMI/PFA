// lib/widgets/home/song_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import 'song_list_item_widget.dart';
// Optionnel: Pour l'effet Shimmer
// import 'package:shimmer/shimmer.dart';

class SongListWidget extends StatelessWidget {
  const SongListWidget({super.key});

  // Optionnel: Widget pour l'effet Shimmer (nécessite le package shimmer)
  /*
  Widget _buildShimmerItem(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 65, height: 65, color: Colors.white, margin: const EdgeInsets.only(right: 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(width: double.infinity, height: 18.0, color: Colors.white),
                    const SizedBox(height: 6.0),
                    Container(width: MediaQuery.of(context).size.width * 0.5, height: 14.0, color: Colors.white),
                    const SizedBox(height: 6.0),
                    Container(width: MediaQuery.of(context).size.width * 0.3, height: 12.0, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  */

  Widget _buildEmptyState(BuildContext context, String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: Theme.of(context).disabledColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).hintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final songs = songProvider.songsToDisplay;

    // --- MODIFICATION ICI: Gestion plus fine des états de chargement et d'erreur ---
    if (!songProvider.isInitialized && songProvider.isLoading) {
      // return ListView.builder( // Optionnel: Afficher des placeholders Shimmer
      //   itemCount: 5,
      //   itemBuilder: (ctx, index) => _buildShimmerItem(context),
      // );
      return const Center(child: CircularProgressIndicator()); // Garder simple pour l'instant
    }

    if (songProvider.error != null && !songProvider.isInitialized) {
      // L'erreur principale est gérée par HomeScreen, donc ici on peut juste retourner un SizedBox
      return const SizedBox.shrink();
    }

    if (songs.isEmpty) {
      if (songProvider.searchQuery.isNotEmpty || songProvider.selectedTag != null) {
        return _buildEmptyState(
          context,
          'Aucun résultat',
          'Nous n\'avons trouvé aucune chanson correspondant à votre recherche ou filtre.',
          Icons.search_off_rounded,
        );
      }
      if (songProvider.isInitialized) { // Initialisé, pas d'erreur, mais vide
        return _buildEmptyState(
          context,
          'Aucune chanson',
          'Il n\'y a pas encore de chansons disponibles. Revenez bientôt !',
          Icons.music_off_rounded,
        );
      }
      // Cas par défaut (devrait être couvert par les conditions ci-dessus ou HomeScreen)
      return const Center(child: Text('Chargement...'));
    }
    // --- FIN DE LA MODIFICATION ---

    return ListView.builder(
      itemCount: songs.length,
      padding: const EdgeInsets.only(bottom: 80), // Pour que le mini-player ne cache pas le dernier item
      itemBuilder: (ctx, index) {
        final song = songs[index];
        return SongListItemWidget(song: song);
      },
    );
  }
}