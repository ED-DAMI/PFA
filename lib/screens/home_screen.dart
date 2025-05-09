import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/auth_provider.dart';
import '../services/audio_player_service.dart';

import '../widgets/common/search_bar_widget.dart';
import '../widgets/home/song_list_widget.dart';
import '../widgets/home/tag_list_widget.dart';
import '../widgets/player/mini_player_widget.dart'; // À créer

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  void initState() {
    super.initState();
    // L'initialisation de SongProvider est gérée par ChangeNotifierProxyProvider
    // et la méthode updateAuthProvider/initialize dans SongProvider.
    // Si vous avez besoin de déclencher un chargement spécifique à l'entrée de cet écran
    // (par exemple, si les données peuvent devenir obsolètes et que vous ne voulez pas
    // vous fier uniquement aux changements d'AuthProvider), vous pourriez le faire ici.
    // Mais pour le chargement initial, ce n'est généralement pas nécessaire avec la config actuelle.
    // Future.microtask(() {
    //   Provider.of<SongProvider>(context, listen: false).initialize();
    // });
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final audioPlayerService = Provider.of<AudioPlayerService>(context); // listen: true par défaut, ok pour rebuild si état change

    Widget bodyContent;

    if (!songProvider.isInitialized && songProvider.isLoading) {
      // Chargement initial, avant que isInitialized ne soit vrai
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (songProvider.error != null && !songProvider.isInitialized) {
      // Erreur pendant le chargement initial
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Erreur: ${songProvider.error}'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                songProvider.clearError(); // Optionnel: efface l'erreur avant de réessayer
                songProvider.initialize(); // Réessayer l'initialisation complète
              },
              child: const Text("Réessayer"),
            )
          ],
        ),
      );
    } else {
      // Données initialisées (avec ou sans chansons) ou erreur après initialisation (moins probable pour fetch global)
      // La logique pour "aucune chanson" etc. est dans SongListWidget
      bodyContent = Column(
        children: [
          TagListWidget(), // Affiche les tags et gère la sélection
          Expanded(
            child: SongListWidget(), // Affiche les chansons filtrées ou les messages appropriés
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              // La navigation est gérée par le Consumer/Selector dans MyApp/app.dart
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: SearchBarWidget(
              onSearchChanged: (query) {
                // Pas besoin d'écouter les changements ici, SearchBarWidget est indépendant
                Provider.of<SongProvider>(context, listen: false).searchSongs(query);
              },
            ),
          ),
        ),
      ),
      body: bodyContent,
      bottomNavigationBar: audioPlayerService.currentSong != null
          ? MiniPlayerWidget() // Assurez-vous que MiniPlayerWidget est implémenté
          : null, // Ou const SizedBox.shrink() si vous préférez un widget
    );
  }
}