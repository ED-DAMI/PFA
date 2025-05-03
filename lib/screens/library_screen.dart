// lib/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/PlaylistProvider.dart';
import 'playlist_detail_screen.dart'; // Pour la navigation

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Écouter PlaylistProvider
    final playlistProvider = Provider.of<PlaylistProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothèque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Créer une playlist',
            onPressed: () {
              // TODO: Afficher une Dialog pour créer une playlist
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Créer playlist (à implémenter)')),
              );
            },
          ),
        ],
      ),
      body: _buildBody(context, playlistProvider),
    );
  }

  Widget _buildBody(BuildContext context, PlaylistProvider playlistProvider) {
    if (playlistProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (playlistProvider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Erreur: ${playlistProvider.errorMessage}\nVeuillez réessayer.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        // Optionnel : Bouton pour réessayer
        // ElevatedButton(onPressed: () => playlistProvider.fetchMyPlaylists(), child: Text("Réessayer"))
      );
    }

    if (playlistProvider.userPlaylists.isEmpty) {
      return const Center(
        child: Text('Vous n\'avez pas encore de playlist.\nCréez-en une avec le bouton + !'),
      );
    }

    // Afficher la liste des playlists
    return ListView.builder(
      itemCount: playlistProvider.userPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = playlistProvider.userPlaylists[index];
        return ListTile(
          leading: playlist.imageUrl != null
              ? Image.network(playlist.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
              : const Icon(Icons.music_note, size: 40), // Placeholder icon
          title: Text(playlist.name),
          subtitle: Text('${playlist.songCount} morceau(x)'), // Attention: ne fonctionnera que si l'API renvoie le nombre ou la liste
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlaylistDetailScreen(
                  playlistId: playlist.id, // Passer l'ID réel
                  playlistName: playlist.name, // Passer le nom réel
                ),
              ),
            );
          },
          // Optionnel: onLongPress pour options (supprimer, renommer)
        );
      },
    );
  }
}