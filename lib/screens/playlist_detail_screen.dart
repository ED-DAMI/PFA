// lib/screens/playlist_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart'; // Assurez-vous que ce modèle est correct
import '../models/song.dart';     // Assurez-vous que ce modèle est correct
import '../providers/SongListItem.dart';
import '../services/ApiService.dart'; // Correction du nom du fichier/classe si nécessaire
import '../providers/auth_provider.dart';
import '../services/audio_player_service.dart'; // Pour jouer la musique
     // Utiliser SongListItem pour l'affichage

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  // Récupérer baseUrl si les images sont chargées via /api/songs/{id}/image
  final String baseUrl; // = "http://192.168.1.125:8080"; // A PASSER OU RECUPERER

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.baseUrl, // Ajouter baseUrl requis
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Playlist? _playlist;

  // Il est MIEUX d'obtenir ApiService via Provider, mais on le garde direct pour l'instant
  // late ApiService _apiService;
  // Tardif si obtenu via Provider dans didChangeDependencies ou build

  @override
  void initState() {
    super.initState();
    // Ne pas initialiser _apiService ici si on utilise Provider
    // _apiService = ApiService(); // À éviter si possible

    // Utiliser addPostFrameCallback pour accéder au Provider après la construction initiale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On récupère le token ici pour le premier fetch
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    // Vérifier si le widget est toujours monté
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Accéder aux providers DANS la méthode (ou via didChangeDependencies)
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // --- CORRECTION ICI ---
      // Récupérer le token de manière asynchrone
      final String? authToken = await authProvider.getToken();

      // Vérifier si le token est disponible (utilisateur connecté ?)
      // fetchPlaylistDetails pourrait nécessiter un token non-null ?
      // if (authToken == null) {
      //    throw Exception("Authentification requise pour voir les détails de la playlist.");
      // }

      // Appeler l'API avec le token résolu (qui peut être null si fetchPlaylistDetails l'accepte)
      final playlistData = await apiService.fetchPlaylistDetails(widget.playlistId, authToken: authToken);

      // Vérifier si le widget est toujours monté avant d'appeler setState
      if (mounted) {
        setState(() {
          _playlist = playlistData; // Peut être null si l'API retourne null
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

  Future<void> _removeSong(String songId) async {
    // Vérifier si le widget est toujours monté
    if (!mounted) return;

    // Afficher un indicateur (ex: SnackBar)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tentative de suppression...'), duration: Duration(seconds: 1)));

    try {
      // Accéder aux providers
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // --- CORRECTION ICI ---
      // Récupérer le token de manière asynchrone
      final String? authToken = await authProvider.getToken();

      // Vérifier si l'utilisateur est authentifié
      if (authToken == null) {
        throw Exception("Authentification requise pour supprimer la chanson.");
      }

      // Appeler l'API avec le token résolu (non-nul ici car vérifié)
      bool success = await apiService.removeSongFromPlaylist(
          widget.playlistId,
          songId,
          authToken: authToken // Passer le String obtenu
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Cache le message précédent
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chanson retirée avec succès'),
          backgroundColor: Colors.green,
        ));
        _fetchDetails(); // Recharger les détails pour mettre à jour la liste
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
    } finally {
      // Optionnel: masquer un indicateur de chargement spécifique à la suppression si utilisé
    }
  }

  @override
  Widget build(BuildContext context) {
    // Il est préférable d'accéder au provider ici si des actions dépendent de son état
    // final audioPlayerService = Provider.of<AudioPlayerService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist?.name ?? widget.playlistName), // Nom dynamique
        actions: [
          // Bouton de rafraîchissement
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _isLoading ? null : _fetchDetails, // Désactivé pendant le chargement
          ),
          // TODO: Ajouter d'autres actions (ex: modifier, supprimer playlist)
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
          child: Column( // Pour le bouton Réessayer
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

    if (_playlist == null) {
      return const Center(child: Text('Playlist non trouvée ou vide.'));
    }

    // Afficher les détails et la liste
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Aligner le titre des morceaux
      children: [
        // --- En-tête de la Playlist (Image, Nom, Description) ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image (si disponible, avec gestion du token si nécessaire)
              // Note: Le modèle Playlist actuel n'a pas imageUrl, il faudrait l'ajouter
              // if (_playlist!.imageUrl != null)
              //   _buildPlaylistImage(context, _playlist!.imageUrl!), // Utiliser un helper
              // else
              const Icon(Icons.playlist_play, size: 100, color: Colors.grey), // Placeholder
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _playlist!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_playlist!.description != null && _playlist!.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_playlist!.description!),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${_playlist!.songs.length} morceau${_playlist!.songs.length == 1 ? "" : "x"}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // TODO: Ajouter créateur, date, etc. si disponible
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(), // Séparateur

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Morceaux',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // --- Liste des Chansons ---
        Expanded(
          child: _playlist!.songs.isEmpty
              ? const Center(child: Text('Cette playlist est vide.'))
          // Utiliser SongListItem pour chaque chanson
              : ListView.builder(
            itemCount: _playlist!.songs.length,
            itemBuilder: (context, index) {
              final song = _playlist!.songs[index];
              // Utiliser le widget SongListItem qui gère son affichage et le play
              return SongListItem(
                song: song,
                baseUrl: widget.baseUrl, // Passer baseUrl
              );
            },
          ),
        ),
      ],
    );
  }

// --- Helper pour l'image de Playlist (si nécessaire) ---
// Widget _buildPlaylistImage(BuildContext context, String imageUrl) {
//    // Logique similaire à SongListItem pour récupérer le token et afficher
//    // avec Image.network(headers:...) si l'URL de l'image playlist est protégée.
//    // Sinon, juste Image.network(imageUrl).
//    return Image.network(imageUrl, width: 100, height: 100, fit: BoxFit.cover,
//        errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image, size: 100),
//    );
// }

}