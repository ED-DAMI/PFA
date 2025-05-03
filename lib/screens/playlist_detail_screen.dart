// lib/screens/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Pour accéder au token si besoin
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/ApiService.dart'; // Besoin d'ApiService
import '../providers/auth_provider.dart'; // Pour le token

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName; // Garder le nom passé pour l'affichage initial

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Playlist? _playlist;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    // Récupérer l'instance ApiService via Provider ou la créer directement
    // Ici, on la récupère de façon simple, mais idéalement via Provider/injection
    _apiService = ApiService();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Récupérer le token de AuthProvider
      final authToken = Provider.of<AuthProvider>(context, listen: false).token;
      // Appeler l'API
      final playlistData = await _apiService.fetchPlaylistDetails(widget.playlistId, authToken: authToken);
      setState(() {
        _playlist = playlistData;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Impossible de charger les détails palaylist: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeSong(String songId) async {
    // Afficher un indicateur de chargement ou désactiver le bouton
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression de la chanson...')));

    try {
      final authToken = Provider.of<AuthProvider>(context, listen: false).token;
      bool success;
      if(authToken!= null)
        success = await _apiService.removeSongFromPlaylist(widget.playlistId, songId, authToken: authToken);
      else
        success=false;
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chanson retirée avec succès')));
        _fetchDetails(); // Recharger les détails pour mettre à jour la liste
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Utiliser le nom chargé si disponible, sinon celui passé en paramètre
        title: Text(_playlist?.name ?? widget.playlistName),
        actions: [ /* Vos actions existantes */ ],
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
          child: Text('Erreur: $_errorMessage', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        // Optionnel: Bouton Réessayer
        // ElevatedButton(onPressed: _fetchDetails, child: Text("Réessayer"))
      );
    }

    if (_playlist == null) {
      return const Center(child: Text('Aucune donnée pour cette playlist.'));
    }

    // Afficher les détails et la liste des chansons
    return Column(
      children: [
        // Optionnel : Afficher l'image et la description de la playlist
        if (_playlist!.imageUrl != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.network(_playlist!.imageUrl!, height: 150, fit: BoxFit.cover),
          ),
        if (_playlist!.description != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(_playlist!.description!),
          ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Morceaux (${_playlist!.songs.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: _playlist!.songs.isEmpty
              ? const Center(child: Text('Cette playlist est vide.'))
              : ListView.builder(
            itemCount: _playlist!.songs.length,
            itemBuilder: (context, index) {
              final song = _playlist!.songs[index];
              return ListTile(
                leading: song.coverImageUrl != null
                    ? Image.network(song.coverImageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.music_note),
                title: Text(song.title),
                subtitle: Text(song.artist), // Assurez-vous que le modèle Song a 'artist'
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  tooltip: 'Retirer le morceau',
                  onPressed: () => _removeSong(song.id), // Appeler la suppression
                ),
                onTap: () {
                  // TODO: Jouer la chanson (Interaction avec PlayerProvider)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Jouer ${song.title} (à implémenter)')),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}