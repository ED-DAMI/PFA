// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/auth_provider.dart';
import '../services/audio_player_service.dart';

import '../widgets/common/search_bar_widget.dart';
import '../widgets/home/song_list_widget.dart';
import '../widgets/home/tag_list_widget.dart';
import '../widgets/player/mini_player_widget.dart';

// Importer l'écran de profil utilisateur
import '../screens/user_profile_screen.dart'; // Assurez-vous que ce chemin est correct

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ... (initState et _handleRefresh restent les mêmes) ...
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      if (!songProvider.isInitialized && !songProvider.isLoading) {
        songProvider.initialize(forceRefresh: false).catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors du chargement initial: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    });
  }

  Future<void> _handleRefresh() async {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    try {
      await songProvider.initialize(forceRefresh: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du rafraîchissement: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false); // Pour l'avatar dans l'icône

    Widget bodyContent;

    if (!songProvider.isInitialized && songProvider.isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (songProvider.error != null && !songProvider.isInitialized) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur de chargement: ${songProvider.error}', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  songProvider.clearError();
                  songProvider.initialize(forceRefresh: true);
                },
                child: const Text("Réessayer"),
              )
            ],
          ),
        ),
      );
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TagListWidget(),
            Expanded(
              child: SongListWidget(),
            ),
          ],
        ),
      );
      if (songProvider.error != null && songProvider.isInitialized && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && songProvider.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${songProvider.error}'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: "OK",
                  onPressed: () => songProvider.clearError(),
                ),
              ),
            );
          }
        });
      }
    }

    // Récupérer l'utilisateur actuel pour afficher son avatar (si disponible)
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music App'), // Ou un logo/nom plus spécifique
        actions: [
          // --- AJOUT DE L'ICÔNE DE PROFIL ICI ---
          IconButton(
            icon: (currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty)
                ? CircleAvatar(
              radius: 18, // Ajustez la taille selon vos préférences
              backgroundImage: NetworkImage(currentUser.avatarUrl!),
              backgroundColor: Colors.transparent, // Pour éviter un fond si l'image est transparente
            )
                : const Icon(Icons.account_circle, size: 28), // Icône par défaut si pas d'avatar
            tooltip: "Profil",
            onPressed: () {
              // Vérifier si l'utilisateur est authentifié avant de naviguer
              if (authProvider.isAuthenticated) {
                Navigator.of(context).pushNamed(UserProfileScreen.routeName);
              } else {
                // Optionnel: Rediriger vers l'écran de connexion si pas authentifié
                // ou afficher un message. Pour l'instant, on ne fait rien si pas authentifié
                // car l'accès au profil est généralement pour les utilisateurs connectés.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Veuillez vous connecter pour voir votre profil.")),
                );
              }
            },
          ),
          // --- FIN DE L'AJOUT ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Déconnexion",
            onPressed: () {
              authProvider.logout();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
            child: SearchBarWidget(
              onSearchChanged: (query) {
                Provider.of<SongProvider>(context, listen: false).searchSongs(query);
              },
            ),
          ),
        ),
      ),
      body: bodyContent,
      bottomNavigationBar: audioPlayerService.currentSong != null && audioPlayerService.showPlayer
          ? MiniPlayerWidget()
          : const SizedBox.shrink(),
    );
  }
}