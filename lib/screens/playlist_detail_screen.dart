// lib/screens/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:pfa/screens/user_profile_screen.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/playlist_provider.dart';
import '../providers/song_provider.dart';
import '../services/audio_player_service.dart';
import '../widgets/common/song_list_item.dart';
 // Assurez-vous que ce chemin est correct

class PlaylistDetailScreen extends StatefulWidget {
  static const routeName = '/playlist-detail';
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLoading = true;
  Playlist? _playlist;
  List<Song> _songsInPlaylist = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlaylistDetails();
  }

  Future<void> _fetchPlaylistDetails() async {
    if (!mounted) return; // Vérifier si le widget est toujours monté
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
      // Récupérer l'objet Playlist depuis le provider (qui le tient en cache)
      final fetchedPlaylist = playlistProvider.getPlaylistById(widget.playlistId);

      if (fetchedPlaylist == null) {
        // Si la playlist n'est pas dans le cache du provider, c'est une situation anormale
        // car l'utilisateur y a accédé depuis une liste de playlists.
        // On pourrait ajouter une logique pour la récupérer de l'API ici si nécessaire.
        throw Exception("Détails de la playlist avec ID ${widget.playlistId} non trouvés.");
      }
      _playlist = fetchedPlaylist;

      if (_playlist!.songIds.isEmpty) {
        _songsInPlaylist = []; // La playlist est vide, pas besoin de chercher des chansons
      } else {
        final songProvider = Provider.of<SongProvider>(context, listen: false);
        List<Song> songs = [];

        // Itérer sur les IDs des chansons et les récupérer
        // Pour une meilleure performance avec de nombreuses chansons, SongProvider
        // pourrait avoir une méthode fetchSongsByIds(List<String> ids)
        for (String songId in _playlist!.songIds) {
          // getSongById doit pouvoir récupérer une chanson (du cache de SongProvider ou via API)
          final song = await songProvider.getSongById(songId);
          if (song != null) {
            songs.add(song);
          } else {
            // Gérer le cas où une chanson référencée n'est pas trouvée
            // Peut-être qu'elle a été supprimée ?
            if (mounted) { // Vérifier `mounted` avant d'utiliser `context` dans des callbacks async
              print("Avertissement: Chanson avec ID $songId non trouvée pour la playlist ${_playlist?.name}");
            }
          }
        }
        _songsInPlaylist = songs;
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erreur de chargement des détails de la playlist: ${e.toString()}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist?.name ?? 'Détails de la Playlist'),
        // Optionnel: Actions comme "Lire tout", "Modifier la playlist", "Supprimer la playlist"
        // actions: _playlist != null && _songsInPlaylist.isNotEmpty ? [
        //   IconButton(
        //     icon: Icon(Icons.play_arrow),
        //     tooltip: 'Lire tout',
        //     onPressed: () {
        //       // TODO: Implémenter la lecture de toute la playlist
        //       if (_songsInPlaylist.isNotEmpty) {
        //         audioPlayerService.playPlaylist(_songsInPlaylist); // Méthode à ajouter dans AudioPlayerService
        //       }
        //     },
        //   ),
        // ] : null,
      ),
      body: _buildBody(audioPlayerService),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // TODO: Logique pour naviguer vers un écran de recherche/ajout de chansons
      //     // Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSongsToPlaylistScreen(playlistId: widget.playlistId)));
      //   },
      //   tooltip: 'Ajouter des chansons',
      //   child: const Icon(Icons.add),
      // ),
    );
  }

  Widget _buildBody(AudioPlayerService audioPlayerService) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
                onPressed: _fetchPlaylistDetails,
              )
            ],
          ),
        ),
      );
    }

    if (_playlist == null) {
      // Ce cas ne devrait pas être atteint si _fetchPlaylistDetails lève une exception
      // mais c'est une bonne sécurité.
      return const Center(child: Text('Impossible de charger les informations de la playlist.'));
    }

    if (_songsInPlaylist.isEmpty) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_off, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Cette playlist est vide.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon( // Bouton pour ajouter des chansons
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Ajouter des chansons"),
                  onPressed: () {
                    // TODO: Naviguer vers un écran de recherche/sélection de chansons
                    // Exemple: Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddSongsToPlaylistScreen(playlistId: widget.playlistId)));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fonctionnalité d'ajout de chansons non implémentée."))
                    );
                  },
                )
              ],
            )
        ),
      );
    }

    // Afficher la liste des chansons
    return RefreshIndicator( // Permet de rafraîchir la liste
      onRefresh: _fetchPlaylistDetails,
      child: ListView.builder(
        itemCount: _songsInPlaylist.length,
        itemBuilder: (context, index) {
          final song = _songsInPlaylist[index];
          return SongListItem( // Utilisation du widget partagé
            song: song,
            onTap: () {
              audioPlayerService.play(song);
              // Optionnel: Afficher un feedback ou naviguer vers un écran de lecture complet
            },
            // Optionnel: Ajouter une action pour supprimer la chanson de la playlist
            trailing: IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
              tooltip: 'Retirer de la playlist',
              onPressed: () async {
                // Logique pour retirer la chanson de la playlist
                bool confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmer la suppression'),
                    content: Text('Voulez-vous vraiment retirer "${song.title}" de cette playlist ?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Annuler'),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      TextButton(
                        child: Text('Retirer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ],
                  ),
                ) ?? false; // Si le dialogue est fermé sans choix, considérer comme false

                if (confirm) {
                  bool success = await Provider.of<PlaylistProvider>(context, listen: false)
                      .removeSongFromPlaylist(widget.playlistId, song.id); // Méthode à ajouter à PlaylistProvider
                  if (success) {
                    // Rafraîchir les détails pour mettre à jour la liste des chansons
                    _fetchPlaylistDetails();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('"${song.title}" retiré de la playlist.'), backgroundColor: Colors.green)
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur lors du retrait de la chanson.'), backgroundColor: Theme.of(context).colorScheme.error)
                      );
                    }
                  }
                }
              },
            ),
          );
        },
      ),
    );
  }
}