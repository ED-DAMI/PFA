import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/song_provider.dart';
import 'song_list_item_widget.dart';

class SongListWidget extends StatelessWidget {
  const SongListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    // Utiliser songsToDisplay au lieu de songs
    final songs = songProvider.songsToDisplay;

    if (!songProvider.isInitialized && songProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Si initialisé mais actuellement
    // en train de recharger
    //(ex: après un pull-to-refresh manuel non implémenté ici)
    // Ou si le filtrage prend du temps (moins probable pour le filtrage local)
    // if (songProvider.isLoading && songs.isEmpty) {
    //   return const Center(child: CircularProgressIndicator());
    // }


    if (songs.isEmpty) {
      if (songProvider.searchQuery.isNotEmpty || songProvider.selectedTag != null) {
        return const Center(child: Text('Aucune chanson trouvée pour votre sélection.'));
      }
      if (songProvider.error == null && songProvider.isInitialized) { // Si initialisé et pas d'erreur, mais vide
        return const Center(child: Text('Aucune chanson disponible.'));
      }
      // Si pas initialisé et pas d'erreur (ex: utilisateur non connecté et données protégées),
      // le message d'erreur de SongProvider (ex: "Veuillez vous connecter") sera affiché dans HomeScreen.
      // Ou ici, vous pouvez afficher un message générique si error est null.
      if (songProvider.error == null && !songProvider.isInitialized) {
        return const Center(child: Text('Chargement des chansons...')); // Ou rien, HomeScreen gère l'erreur/loading global
      }
      // Le cas d'erreur est géré dans HomeScreen
    }


    // Si une erreur s'est produite pendant le chargement initial, HomeScreen l'affichera.
    // Ce widget ne devrait s'afficher que si les données sont prêtes ou si une recherche/filtre ne donne rien.
    if (songProvider.error != null && !songProvider.isInitialized) {
      // Ne rien afficher ici, HomeScreen gère l'erreur principale
      return const SizedBox.shrink();
    }


    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (ctx, index) {
        final song = songs[index];
        return SongListItemWidget(song: song); // Assurez-vous que SongListItemWidget est prêt
      },
    );
  }
}