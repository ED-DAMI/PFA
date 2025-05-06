// lib/screens/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
// Correction du chemin pour SongListItem si ce n'est pas un provider mais un widget
// Si SongListItem est un widget dans lib/widgets/song_list_item.dart
import '../providers/SongListItem.dart';
// Assurez-vous que ce chemin est correct
import '../services/ApiService.dart';
import '../providers/auth_provider.dart';
// AudioPlayerService n'est pas directement utilisé dans build ici, donc pas besoin de le récupérer dans build à moins d'une action spécifique.

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  final String baseUrl;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.baseUrl,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Playlist? _playlist; // Peut être null

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      // Optionnel: réinitialiser _playlist à null ici pour forcer le rechargement complet de l'UI
      // _playlist = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? authToken = await authProvider.getToken();

      // if (authToken == null) { // Décommenter si le token est absolument requis
      //   if (mounted) {
      //     setState(() {
      //       _errorMessage = "Authentification requise pour voir les détails de la playlist.";
      //       _isLoading = false;
      //     });
      //   }
      //   return;
      // }

      final playlistData = await apiService.fetchPlaylistDetails(widget.playlistId, authToken: authToken);

      if (mounted) {
        setState(() {
          _playlist = playlistData; // playlistData peut être null si l'API retourne null ou une erreur gérée
        });
      }
    } catch (e) {
      print("Error fetching playlist details: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Impossible de charger les détails : ${e.toString()}";
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

  // _removeSong reste inchangé pour l'instant, mais assurez-vous que la logique
  // de récupération du token et d'appel API est correcte.

  Future<void> _removeSong(String songId) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tentative de suppression...'), duration: Duration(seconds: 1)));

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final String? authToken = await authProvider.getToken();

      if (authToken == null) {
        throw Exception("Authentification requise pour supprimer la chanson.");
      }

      bool success = await apiService.removeSongFromPlaylist(
          widget.playlistId,
          songId,
          authToken: authToken
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chanson retirée avec succès'),
          backgroundColor: Colors.green,
        ));
        _fetchDetails();
      } else if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la suppression de la chanson'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      print("Error removing song: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Utiliser le nom de la playlist chargée si disponible, sinon le nom passé en widget
        title: Text(_playlist?.name ?? widget.playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _isLoading ? null : _fetchDetails,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erreur: $_errorMessage', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Réessayer"),
                onPressed: _fetchDetails,
              )
            ],
          ),
        ),
      );
    }

    // --- MODIFICATION CRUCIALE ICI ---
    // Vérifier si _playlist est null OU si _playlist.songs est null (si le modèle le permet)
    // ou vide. Il est préférable que _playlist.songs soit toujours une liste (même vide)
    // et non nullable dans le modèle Playlist.
    if (_playlist == null) {
      return const Center(
        child: Text('Playlist non trouvée ou les données sont indisponibles.'),
      );
    }

    // À ce stade, _playlist n'est PAS null.
    // Si votre modèle Playlist garantit que `songs` n'est jamais null (initialisé à `[]`),
    // vous n'avez pas besoin de vérifier `_playlist!.songs == null`.
    // Sinon, ajoutez une vérification ou utilisez l'opérateur `?.`

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.playlist_play, size: 100, color: Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _playlist!.name, // Safe, _playlist is not null here
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_playlist!.description != null && _playlist!.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_playlist!.description!), // Safe
                    ],
                    const SizedBox(height: 8),
                    Text(
                      // Safe, _playlist is not null. Si _playlist.songs peut être null:
                      // '${_playlist!.songs?.length ?? 0} morceau${(_playlist!.songs?.length ?? 0) == 1 ? "" : "x"}',
                      // Mais il est préférable que _playlist.songs soit List<Song> et non List<Song>?
                      '${_playlist!.songs.length} morceau${_playlist!.songs.length == 1 ? "" : "x"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Morceaux',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          // Safe, _playlist is not null.
          // Si _playlist.songs peut être null: if (_playlist!.songs == null || _playlist!.songs!.isEmpty)
          child: _playlist!.songs.isEmpty
              ? const Center(child: Text('Cette playlist est vide.'))
              : ListView.builder(
            // Safe, _playlist.songs n'est pas null ici (si le modèle est bien fait) et n'est pas vide.
            itemCount: _playlist!.songs.length,
            itemBuilder: (context, index) {
              final song = _playlist!.songs[index];
              return SongListItem( // Assurez-vous que SongListItem est importé correctement
                song: song,
                baseUrl: widget.baseUrl,
                // key: ValueKey(song.id), // Optionnel: ajouter une clé si la liste peut être modifiée dynamiquement
              );
            },
          ),
        ),
      ],
    );
  }
}