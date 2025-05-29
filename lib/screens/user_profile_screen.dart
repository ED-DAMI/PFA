// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/playlist_provider.dart';

import '../models/song.dart';
// import '../models/playlist.dart'; // Playlist n'est plus directement utilisé pour type ici

import '../screens/song_detail_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../widgets/common/song_list_item.dart';

class UserProfileScreen extends StatefulWidget {
  static const routeName = '/user-profile';
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Le chargement initial se fait ici
    _loadInitialData();
  }

  // Méthode pour le chargement initial des données
  void _loadInitialData({bool isRefresh = false}) {
    // Utiliser Future.microtask pour s'assurer que le contexte est disponible
    // et éviter les erreurs de "setState() or markNeedsBuild() called during build".
    Future.microtask(() {
      if (!mounted) return; // Vérifier si le widget est toujours monté

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && authProvider.token != null) {
        final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
        // Si c'est un rafraîchissement ou si non initialisé, on fetch
        if (isRefresh || !playlistProvider.isInitialized) {
          playlistProvider.fetchPlaylists(forceRefresh: isRefresh);
        }

        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        // Si c'est un rafraîchissement ou si non initialisé, on fetch
        if (isRefresh || !historyProvider.isInitialized) {
          historyProvider.fetchHistory(forceRefresh: isRefresh);
        }
      }
    });
  }

  // --- MODIFICATION ICI : Méthode pour le Pull to Refresh ---
  Future<void> _refreshData() async {
    // S'assurer que l'utilisateur est authentifié avant de tenter de rafraîchir
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.token != null) {
      // Utiliser await pour attendre que les deux opérations soient terminées.
      // On peut les lancer en parallèle avec Future.wait si on le souhaite
      // pour un léger gain de performance, mais pour la simplicité, séquentiel est ok.
      await Provider.of<PlaylistProvider>(context, listen: false).fetchPlaylists(forceRefresh: true);
      await Provider.of<HistoryProvider>(context, listen: false).fetchHistory(forceRefresh: true);
    }
    // Pas besoin de setState ici, les providers notifieront les listeners.
  }
  // --- FIN DE LA MODIFICATION ---

  @override
  Widget build(BuildContext context) {
    final authData = Provider.of<AuthProvider>(context);
    final currentUser = authData.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Utilisateur non trouvé. Veuillez vous connecter.')),
      );
    }

    return Scaffold(
      // --- MODIFICATION ICI : Ajout du RefreshIndicator ---
      body: RefreshIndicator(
        onRefresh: _refreshData, // La fonction à appeler lors du "pull"
        color: Theme.of(context).primaryColor, // Couleur de l'indicateur
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Important pour que RefreshIndicator fonctionne même si le contenu est petit
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 220.0,
              pinned: true,
              floating: false,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(currentUser.username, style: const TextStyle(shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16.0),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Theme.of(context).primaryColor.withOpacity(0.8), Theme.of(context).colorScheme.secondary.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40.0), // Ajusté pour laisser de la place au titre de la FlexibleSpaceBar
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.white54,
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: (currentUser.avatarUrl != null && currentUser.avatarUrl!.isNotEmpty)
                                ? NetworkImage(currentUser.avatarUrl!)
                                : null,
                            child: (currentUser.avatarUrl == null || currentUser.avatarUrl!.isEmpty)
                                ? Text(
                              currentUser.username.isNotEmpty ? currentUser.username[0].toUpperCase() : 'U',
                              style: TextStyle(fontSize: 40, color: Theme.of(context).primaryColorDark),
                            )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historique d\'écoute',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Optionnel: Bouton pour voir tout l'historique
                    // TextButton(onPressed: () { /* Naviguer vers écran historique complet */ }, child: Text('Voir tout')),
                  ],
                ),
              ),
            ),
            _buildHistorySliver(),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes Playlists',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Créer'),
                      onPressed: () {
                        _showCreatePlaylistDialog(context);
                      },
                    )
                  ],
                ),
              ),
            ),
            _buildPlaylistSliver(),

            const SliverToBoxAdapter(child: SizedBox(height: 30)), // Espace en bas
          ],
        ),
      ),
      // --- FIN DE LA MODIFICATION ---
    );
  }

  Widget _buildHistorySliver() {
    // ... (Le reste de _buildHistorySliver reste inchangé)
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        if (historyProvider.isLoading && !historyProvider.isInitialized) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())),
          );
        }
        if (historyProvider.error != null && historyProvider.history.isEmpty) { // Afficher l'erreur seulement si pas de données
          return SliverToBoxAdapter(
            child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Erreur historique: ${historyProvider.error}'))),
          );
        }
        if (historyProvider.history.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('Aucun historique trouvé.'))),
          );
        }

        const int historyLimit = 5;
        final historyToShow = historyProvider.history.take(historyLimit).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
              final song = historyToShow[index];
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
              );
            },
            childCount: historyToShow.length,
          ),
        );
      },
    );
  }

  Widget _buildPlaylistSliver() {
    // ... (Le reste de _buildPlaylistSliver reste inchangé)
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, child) {
        if (playlistProvider.isLoadingList && !playlistProvider.isInitialized) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())),
          );
        }
        if (playlistProvider.error != null && playlistProvider.playlists.isEmpty) { // Afficher l'erreur seulement si pas de données
          return SliverToBoxAdapter(
            child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Erreur playlists: ${playlistProvider.error}'))),
          );
        }
        if (playlistProvider.playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aucune playlist créée.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Créer une playlist'),
                      onPressed: () {
                        _showCreatePlaylistDialog(context);
                      },
                    ),
                  ],
                ))),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
              final playlist = playlistProvider.playlists[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(Icons.playlist_play),
                ),
                title: Text(playlist.name),
                subtitle: Text('${playlist.songIds.length} chanson(s)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PlaylistDetailScreen(playlistId: playlist.id),
                    ),
                  );
                },
              );
            },
            childCount: playlistProvider.playlists.length,
          ),
        );
      },
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    // ... (Le reste de _showCreatePlaylistDialog reste inchangé)
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final playlistProvider = Provider.of<PlaylistProvider>(dialogContext, listen: false);
        final authProvider = Provider.of<AuthProvider>(dialogContext, listen: false); // Pour le token

        return AlertDialog(
          title: const Text('Créer une nouvelle playlist'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: "Nom de la playlist",
                      hintText: "Ex: Mes tubes de l'été"
                  ),
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer un nom.';
                    }
                    if (value.length > 100) {
                      return 'Le nom est trop long (max 100 caractères).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: "Description (optionnel)",
                      hintText: "Ex: Pour mes sessions de sport"
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value != null && value.length > 255) {
                      return 'La description est trop longue (max 255 caractères).';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            // Bouton pour la création, utilise maintenant Consumer pour l'état de chargement
            Consumer<PlaylistProvider>( // Pour réagir à l'état isModifyingItem
                builder: (ctx, provider, _) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: provider.isModifyingItem ? Colors.grey : null, // Optionnel: changer l'apparence pendant le chargement
                    ),
                    onPressed: provider.isModifyingItem ? null : () async { // Désactiver pendant le chargement
                      if (formKey.currentState!.validate()) {
                        final name = nameController.text.trim();
                        final description = descriptionController.text.trim().isNotEmpty
                            ? descriptionController.text.trim()
                            : null;

                        // Le token est nécessaire pour createPlaylist
                        if (authProvider.token == null) {
                          if (!dialogContext.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Erreur: Authentification requise.'), backgroundColor: Colors.red,)
                          );
                          return;
                        }

                        bool success = await playlistProvider.createPlaylist(
                          name: name,
                          description: description,
                          // authToken: authProvider.token!, // createPlaylist prend déjà le token du AuthProvider injecté dans PlaylistProvider
                        );

                        if (!dialogContext.mounted) return;

                        if (success) {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text('Playlist créée !'), backgroundColor: Colors.green,)
                          );
                        } else {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(playlistProvider.error ?? 'Erreur lors de la création.'), backgroundColor: Colors.red,)
                          );
                        }
                      }
                    },
                    child: provider.isModifyingItem
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Créer'),
                  );
                }
            ),
          ],
        );
      },
    );
  }
}