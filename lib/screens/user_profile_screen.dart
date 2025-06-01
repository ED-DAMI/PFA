// lib/screens/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:pfa/config/api_config.dart'; // Votre config API
import 'package:pfa/models/playlist.dart';
import 'package:pfa/models/user.dart';
import 'package:provider/provider.dart';


import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/playlist_provider.dart';

import '../models/song.dart';

import '../screens/song_detail_screen.dart';
import '../screens/playlist_detail_screen.dart';
import '../widgets/common/song_list_item.dart';
import 'edit_profile_screen.dart';
import 'package:shimmer/shimmer.dart';

// --- CONSTANTES ---
const double kDefaultPadding = 16.0;
const String kSeeAllText = 'Voir tout';
const String kEditProfileText = 'Modifier le profil';
const String kLogoutText = 'Se déconnecter';
const String kRenameText = 'Renommer';
const String kDeleteText = 'Supprimer';

// --- COULEURS SUGGÉRÉES (à adapter à votre thème global si possible) ---
final Color kLightBackgroundList = Colors.grey.shade100;
final Color kSubtleTextColor = Colors.grey.shade600;

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
    _loadInitialData();
  }

  void _loadInitialData({bool isRefresh = false}) {
    Future.microtask(() {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        // Optionnel: Rafraîchir le profil utilisateur depuis l'API
        // Si les données du profil peuvent changer en arrière-plan
        // authProvider.fetchUserProfile(); // Assurez-vous que cette méthode existe dans AuthProvider

        final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
        if (isRefresh || !playlistProvider.isInitialized) {
          playlistProvider.fetchPlaylists(forceRefresh: isRefresh);
        }
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        if (isRefresh || !historyProvider.isInitialized) {
          historyProvider.fetchHistory(forceRefresh: isRefresh);
        }
      }
    });
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated && authProvider.token != null) {
      try {
        // Rafraîchir aussi le profil utilisateur si nécessaire
        // await authProvider.fetchUserProfile();

        await Future.wait([
          Provider.of<PlaylistProvider>(context, listen: false).fetchPlaylists(forceRefresh: true),
          Provider.of<HistoryProvider>(context, listen: false).fetchHistory(forceRefresh: true),
        ]);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Échec du rafraîchissement: $error'), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute des changements de AuthProvider pour reconstruire si currentUser change
    final authData = Provider.of<AuthProvider>(context);
    final User? currentUser = authData.currentUser;

    final ThemeData theme = Theme.of(context);
    final Color dominantColor = theme.primaryColor;
    final Color appBarTextColor = theme.colorScheme.onPrimary;
    final Color listBackgroundColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceVariant
        : kLightBackgroundList;
    final Color sectionTitleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.secondary
        : dominantColor;
    final Color subtleTextColor = theme.brightness == Brightness.dark
        ? Colors.grey.shade400
        : kSubtleTextColor;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil'), backgroundColor: dominantColor),
        body: const Center(child: Text('Utilisateur non trouvé. Veuillez vous connecter.')),
      );
    }

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: dominantColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverAppBar(
              expandedHeight: 260.0,
              pinned: true,
              floating: false,
              backgroundColor: dominantColor,
              iconTheme: IconThemeData(color: appBarTextColor),
              actionsIconTheme: IconThemeData(color: appBarTextColor),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: kEditProfileText,
                  onPressed: () {
                    Navigator.of(context).pushNamed(EditProfileScreen.routeName).then((_) {
                      // Optionnel: forcer un rafraîchissement si EditProfileScreen
                      // ne met pas à jour AuthProvider de manière à déclencher une reconstruction.
                      // Cependant, si AuthProvider est correctement mis à jour et notifie les listeners,
                      // UserProfileScreen (qui écoute AuthProvider) devrait se reconstruire automatiquement.
                      // setState(() {}); // Pourrait être nécessaire dans de rares cas.
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: kLogoutText,
                  onPressed: () async {
                    final bool? confirmLogout = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        title: const Text(kLogoutText),
                        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Annuler'),
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                          ),
                          TextButton(
                            child: const Text('Déconnecter'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirmLogout == true) {
                      if (!mounted) return;
                      await Provider.of<AuthProvider>(context, listen: false).logout();
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  currentUser.username,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: appBarTextColor,
                      shadows: const [Shadow(blurRadius: 2, color: Colors.black38)]
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: kDefaultPadding + 4, left: 60, right: 60),
                background: _UserProfileHeader(
                  currentUser: currentUser,
                  dominantColor: dominantColor,
                  appBarTextColor: appBarTextColor,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kDefaultPadding, 24.0, kDefaultPadding, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Historique d\'écoute',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sectionTitleColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Navigation vers l\'historique complet (TODO)')),
                        );
                      },
                      style: TextButton.styleFrom(foregroundColor: sectionTitleColor.withOpacity(0.8)),
                      child: const Text(kSeeAllText),
                    ),
                  ],
                ),
              ),
            ),
            _buildHistorySliver(listBackgroundColor, subtleTextColor),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kDefaultPadding, 24.0, kDefaultPadding, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes Playlists',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: sectionTitleColor,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.add, size: 20, color: sectionTitleColor.withOpacity(0.8)),
                      label: Text('Créer', style: TextStyle(color: sectionTitleColor.withOpacity(0.8))),
                      onPressed: () => _showCreatePlaylistDialog(context, dominantColor),
                      style: TextButton.styleFrom(foregroundColor: sectionTitleColor.withOpacity(0.8)),
                    )
                  ],
                ),
              ),
            ),
            _buildPlaylistSliver(listBackgroundColor, sectionTitleColor, subtleTextColor),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySliver(Color listItemsBackgroundColor, Color subtleTxtColor) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        if (historyProvider.isLoading && !historyProvider.isInitialized) {
          return _buildShimmerList(5, listItemsBackgroundColor);
        }
        if (historyProvider.error != null && historyProvider.history.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Erreur historique: ${historyProvider.error}'))),
          );
        }
        if (historyProvider.history.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_toggle_off_outlined, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: kDefaultPadding),
                    const Text('Aucun historique d\'écoute pour le moment.', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }

        const int historyLimit = 5;
        final historyToShow = historyProvider.history.take(historyLimit).toList();

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
              final song = historyToShow[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding / 2, vertical: 4.0),
                child: Card(
                  elevation: 1,
                  color: listItemsBackgroundColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: SongListItem(
                    song: song,
                    coverArtUrl: '${API_BASE_URL}/api/songs/${song.id}/cover', // Construit l'URL complète
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => SongDetailScreen(song: song)),
                      );
                    },
                  ),
                ),
              );
            },
            childCount: historyToShow.length,
          ),
        );
      },
    );
  }

  Widget _buildPlaylistSliver(Color listItemsBackgroundColor, Color iconColor, Color subtleTxtColor) {
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, child) {
        if (playlistProvider.isLoadingList && !playlistProvider.isInitialized) {
          return _buildShimmerList(3, listItemsBackgroundColor, isPlaylist: true);
        }
        if (playlistProvider.error != null && playlistProvider.playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Text('Erreur playlists: ${playlistProvider.error}'))),
          );
        }
        if (playlistProvider.playlists.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.playlist_add_outlined, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: kDefaultPadding),
                    const Text('Vous n\'avez pas encore créé de playlist.'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Créer ma première playlist'),
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Theme.of(context).colorScheme.onPrimary),
                      onPressed: () => _showCreatePlaylistDialog(context, Theme.of(context).primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
              final playlist = playlistProvider.playlists[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding / 2, vertical: 4.0),
                child: Card(
                  elevation: 1.5,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  color: listItemsBackgroundColor,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withOpacity(0.1),
                      child: Icon(Icons.playlist_play, color: iconColor),
                    ),
                    title: Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text('${playlist.songIds.length} chanson(s)', style: TextStyle(color: subtleTxtColor)),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color?.withOpacity(0.7)),
                      onSelected: (String value) {
                        if (value == 'rename') {
                          _showRenamePlaylistDialog(context, playlist, Theme.of(context).primaryColor);
                        } else if (value == 'delete') {
                          _showDeletePlaylistConfirmationDialog(context, playlist);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'rename',
                          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text(kRenameText)),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text(kDeleteText, style: TextStyle(color: Colors.red))),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => PlaylistDetailScreen(playlistId: playlist.id)),
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    hoverColor: iconColor.withOpacity(0.05),
                  ),
                ),
              );
            },
            childCount: playlistProvider.playlists.length,
          ),
        );
      },
    );
  }

  Widget _buildShimmerList(int count, Color baseListItemColor, {bool isPlaylist = false}) {
    final shimmerBase = Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = Theme.of(context).brightness == Brightness.dark ? Colors.grey[700]! : Colors.grey[100]!;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding, vertical: 8.0),
          child: Shimmer.fromColors(
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
            child: Container(
              padding: const EdgeInsets.all(kDefaultPadding / 2),
              decoration: BoxDecoration(
                color: baseListItemColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: Colors.grey, radius: isPlaylist ? 20 : 28),
                  const SizedBox(width: kDefaultPadding / 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: double.infinity, height: 16.0, color: Colors.grey, margin: const EdgeInsets.only(bottom: 4)),
                        Container(width: MediaQuery.of(context).size.width * 0.4, height: 12.0, color: Colors.grey),
                      ],
                    ),
                  ),
                  if (isPlaylist) ...[
                    const SizedBox(width: kDefaultPadding / 2),
                    const Icon(Icons.more_vert, color: Colors.grey),
                  ]
                ],
              ),
            ),
          ),
        ),
        childCount: count,
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context, Color dominantColor) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Créer une nouvelle playlist'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nom de la playlist", hintText: "Ex: Mes tubes de l'été"),
                  autofocus: true,
                  validator: (value) { /* ...validation... */ return null; },
                ),
                const SizedBox(height: kDefaultPadding),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "Description (optionnel)", hintText: "Ex: Pour mes sessions de sport"),
                  maxLines: 2,
                  validator: (value) { /* ...validation... */ return null; },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            Consumer<PlaylistProvider>(
              builder: (ctx, provider, _) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dominantColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: provider.isModifyingItem ? null : () async { /* ...logique de création... */ },
                  child: provider.isModifyingItem
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Créer'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenamePlaylistDialog(BuildContext context, Playlist playlist, Color dominantColor) async {
    final TextEditingController nameController = TextEditingController(text: playlist.name);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Renommer "${playlist.name}"'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nouveau nom de la playlist"),
              autofocus: true,
              validator: (value) { /* ...validation... */ return null; },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            Consumer<PlaylistProvider>(
              builder: (ctx, provider, _) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dominantColor,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: provider.isModifyingItem ? null : () async { /* ...logique de renommage... */ },
                  child: provider.isModifyingItem
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(kRenameText),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeletePlaylistConfirmationDialog(BuildContext context, Playlist playlist) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Supprimer "${playlist.name}" ?'),
          content: const Text('Cette action est irréversible. La playlist sera supprimée.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            Consumer<PlaylistProvider>(
              builder: (ctx, provider, _) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: provider.isModifyingItem ? null : () async { /* ...logique de suppression... */ },
                  child: provider.isModifyingItem
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text(kDeleteText),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// --- _UserProfileHeader ---
class _UserProfileHeader extends StatelessWidget {
  final User currentUser; // Le modèle User doit être importé
  final Color dominantColor;
  final Color appBarTextColor;

  const _UserProfileHeader({
    super.key, // Bonne pratique d'ajouter super.key pour les constructeurs const
    required this.currentUser,
    required this.dominantColor,
    required this.appBarTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final String? userEmail = currentUser.email;
    String? fullAvatarUrl; // Sera initialisé à null par défaut

    // --- SECTION DE DÉBOGAGE ---
    // Ces prints vous aideront à identifier le problème si l'image ne s'affiche pas.
    // Vous pouvez les commenter ou les supprimer une fois que tout fonctionne.
    print('-------------------------------------------');
    print('_UserProfileHeader - BUILD METHOD CALLED');
    print('_UserProfileHeader - currentUser.id: ${currentUser.id}');
    print('_UserProfileHeader - currentUser.username: ${currentUser.username}');
    print('_UserProfileHeader - currentUser.avatarUrl (relative path): "${currentUser.avatarUrl}"');
    print('_UserProfileHeader - API_BASE_URL from config: "$API_BASE_URL"');
    // --- FIN SECTION DE DÉBOGAGE ---

    // Construction de l'URL complète de l'avatar


      fullAvatarUrl = currentUser.avatarUrl; // Ex: "http://host:port" + "/api/users/id/avatar"
      // Résultat attendu: "http://host:port/api/users/id/avatar"


    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dominantColor, dominantColor.withOpacity(0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.5, 1.0], // Contrôle la transition du dégradé
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement le contenu
        children: [
          CircleAvatar(
            radius: 55, // Rayon du cercle extérieur (bordure)
            backgroundColor: appBarTextColor.withOpacity(0.2), // Couleur de la bordure semi-transparente
            child: CircleAvatar(
              radius: 50, // Rayon du cercle intérieur (image/initiales)
              backgroundColor: dominantColor.withOpacity(0.5), // Fond si l'image ne charge pas ou est transparente
              // Utilisation de fullAvatarUrl pour charger l'image
              child: (fullAvatarUrl != null && fullAvatarUrl.toLowerCase().startsWith('http'))
                  ? ClipOval( // Assure que l'image est bien ronde à l'intérieur du CircleAvatar
                child: Image.network(
                  fullAvatarUrl,
                  // Utiliser une clé unique si vous voulez forcer le rechargement
                  // lorsque l'URL est la même mais que le contenu a changé (pas typique pour les avatars où l'URL change)
                  // key: ValueKey(fullAvatarUrl + DateTime.now().millisecondsSinceEpoch.toString()),
                  key: ValueKey(fullAvatarUrl), // Suffisant si l'URL change quand l'avatar change
                  fit: BoxFit.cover, // Assure que l'image remplit le cercle
                  width: 100, // Doit être 2 * radius du CircleAvatar intérieur
                  height: 100,
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child; // L'image est chargée, afficher l'enfant (l'image)
                    return Center( // Afficher un indicateur de chargement
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null, // Indicateur indéterminé si le total n'est pas connu
                        strokeWidth: 2,
                        color: appBarTextColor.withOpacity(0.7), // Couleur de l'indicateur
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                    print('_UserProfileHeader - Erreur DANS Image.network pour "$fullAvatarUrl": $error');
                    // Afficher les initiales en cas d'erreur de chargement de l'image
                    return Text(
                      currentUser.username.isNotEmpty ? currentUser.username[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 40, color: appBarTextColor, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              )
                  : Text( // Placeholder si fullAvatarUrl est null ou n'est pas une URL HTTP valide (initiales)
                currentUser.username.isNotEmpty ? currentUser.username[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 40, color: appBarTextColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (userEmail != null && userEmail.isNotEmpty) ...[
            const SizedBox(height: 8), // Espace entre l'avatar et l'email
            Text(
              userEmail,
              style: TextStyle(
                fontSize: 13,
                color: appBarTextColor.withOpacity(0.7), // Email plus discret
              ),
            ),
          ],
          // Espace pour s'assurer que le titre de la FlexibleSpaceBar ne chevauche pas l'email/avatar
          const SizedBox(height: 55),
        ],
      ),
    );
  }
}