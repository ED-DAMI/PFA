// lib/screens/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // <<< AJOUTER CET IMPORT
import 'package:pfa/config/api_config.dart';
import 'package:pfa/screens/song_detail_screen.dart';
import 'package:provider/provider.dart';

import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/playlist_provider.dart';
import '../providers/song_provider.dart';

import '../services/audio_player_service.dart';
import '../widgets/common/song_list_item.dart';

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
    // Si vous n'avez pas initialisé les locales pour intl globalement (dans main.dart),
    // vous pourriez avoir besoin de le faire ici ou dans main.dart:
    // initializeDateFormatting('fr_FR', null).then((_) => _fetchPlaylistDetails());
    // Pour cet exemple, on suppose que c'est déjà fait ou que le format par défaut est acceptable.
    _fetchPlaylistDetails();
  }

  Future<void> _fetchPlaylistDetails() async {
    // ... (le reste de la méthode _fetchPlaylistDetails reste inchangé) ...
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
      final fetchedPlaylist = playlistProvider.getPlaylistById(widget.playlistId);

      if (fetchedPlaylist == null) {
        throw Exception("Détails de la playlist avec ID ${widget.playlistId} non trouvés.");
      }
      _playlist = fetchedPlaylist;

      if (_playlist!.songIds.isEmpty) {
        _songsInPlaylist = [];
      } else {
        final songProvider = Provider.of<SongProvider>(context, listen: false);
        List<Song> songs = [];
        for (String songId in _playlist!.songIds) {
          final song = await songProvider.getSongById(songId);
          if (song != null) {
            songs.add(song);
          } else {
            if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist?.name ?? 'Détails de la Playlist'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center( /* ... gestion de l'erreur ... */ );
    }

    if (_playlist == null) {
      return const Center(child: Text('Impossible de charger les informations de la playlist.'));
    }

    List<Widget> children = [];

    // Ajouter la description si elle existe
    if (_playlist!.description != null && _playlist!.description!.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text(
            _playlist!.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8)
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // --- MODIFICATION ICI POUR AFFICHER LA DATE DE CRÉATION ---
    if (_playlist!.createdAt != null) {
      children.add(
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16.0,
            // Si pas de description, ajouter plus de padding vertical en haut
            vertical: (_playlist!.description != null && _playlist!.description!.isNotEmpty) ? 4.0 : 12.0,
          ),
          child: Text(
            // Formatage de la date. 'fr_FR' est optionnel si vous voulez le format par défaut de la locale système.
            // Vous pouvez utiliser d'autres formats comme DateFormat.yMMMd('fr_FR') pour "7 déc. 2023"
            'Créée le ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(_playlist!.createdAt!)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // --- FIN DE LA MODIFICATION POUR LA DATE ---

    // Ajouter un séparateur si une description OU une date de création est présente
    bool hasMetadata = (_playlist!.description != null && _playlist!.description!.isNotEmpty) ||
        (_playlist!.createdAt != null);

    if (hasMetadata) {
      children.add(const Divider(height: 1, indent: 16, endIndent: 16, thickness: 0.7));
      children.add(const SizedBox(height: 10)); // Un peu d'espace après le séparateur
    }


    if (_songsInPlaylist.isEmpty) {
      children.add(
        Expanded(
            child: Center( /* ... message playlist vide ... */ )
        ),
      );
    } else {
      children.add(
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchPlaylistDetails,
            child: ListView.builder(
              itemCount: _songsInPlaylist.length,
              itemBuilder: (context, index) {
                final song = _songsInPlaylist[index];
                return SongListItem(
                  song: song,
                  coverArtUrl: API_BASE_URL+'/api/songs/'+song.id+'/cover',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => SongDetailScreen(song: song),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
                    tooltip: 'Retirer de la playlist',
                    onPressed: () async {
                      // ... (logique de suppression de chanson reste inchangée) ...
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
                      ) ?? false;

                      if (confirm) {
                        bool success = await Provider.of<PlaylistProvider>(context, listen: false)
                            .removeSongFromPlaylist(widget.playlistId, song.id);
                        if (success) {
                          _fetchPlaylistDetails();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('"${song.title}" retiré de la playlist.'), backgroundColor: Colors.green)
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(Provider.of<PlaylistProvider>(context, listen: false).error ?? 'Erreur lors du retrait de la chanson.'), backgroundColor: Theme.of(context).colorScheme.error)
                            );
                          }
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}