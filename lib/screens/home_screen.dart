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

import '../screens/user_profile_screen.dart';

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
    Future.microtask(() {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      if (!songProvider.isInitialized && !songProvider.isLoading) {
        songProvider.initialize(forceRefresh: false).catchError((error) {
          if (mounted) {
            _showErrorSnackBar('Erreur lors du chargement initial: $error');
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
        _showErrorSnackBar('Erreur lors du rafraîchissement: $error', isRefreshError: true);
      }
    }
  }

  void _showErrorSnackBar(String message, {bool isRefreshError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isRefreshError ? Icons.warning_amber_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isRefreshError
            ? const Color(0xFFFF8A65)
            : const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 6,
        action: SnackBarAction(
          label: "OK",
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = Provider.of<SongProvider>(context);
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final theme = Theme.of(context);

    Widget bodyContent;

    if (!songProvider.isInitialized && songProvider.isLoading) {
      // Design amélioré pour le loading
      bodyContent = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Chargement de votre musique...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (songProvider.error != null && !songProvider.isInitialized) {
      // Design amélioré pour l'état d'erreur
      bodyContent = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.colorScheme.errorContainer.withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.error.withOpacity(0.1),
                        theme.colorScheme.error.withOpacity(0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.error.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Oups, une erreur est survenue',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        songProvider.error ?? 'Impossible de charger les données pour le moment.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      "Réessayer",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      songProvider.clearError();
                      songProvider.initialize(forceRefresh: true);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: _handleRefresh,
        color: theme.primaryColor,
        backgroundColor: theme.scaffoldBackgroundColor,
        strokeWidth: 3,
        displacement: 60,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.scaffoldBackgroundColor,
                theme.scaffoldBackgroundColor.withOpacity(0.95),
              ],
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TagListWidget(),
              Expanded(
                child: SongListWidget(),
              ),
            ],
          ),
        ),
      );

      if (songProvider.error != null && songProvider.isInitialized && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showErrorSnackBar('Erreur: ${songProvider.error}', isRefreshError: true);
          songProvider.clearError();
        });
      }
    }

    return Scaffold(
      // AppBar avec design moderne et dégradé
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primaryColor,
                theme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'My Music',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          // Bouton profil avec design amélioré
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: IconButton(
              icon: (currentUser?.avatarUrl != null && currentUser!.avatarUrl!.isNotEmpty)
                  ? CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(currentUser.avatarUrl!),
                backgroundColor: Colors.transparent,
              )
                  : const Icon(Icons.account_circle_outlined, size: 26, color: Colors.white),
              tooltip: "Profil",
              onPressed: () {
                if (authProvider.isAuthenticated) {
                  Navigator.of(context).pushNamed(UserProfileScreen.routeName);
                } else {
                  _showErrorSnackBar("Veuillez vous connecter pour voir votre profil.");
                }
              },
            ),
          ),
          // Bouton déconnexion avec design amélioré
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_outlined, size: 24, color: Colors.white),
              tooltip: "Déconnexion",
              onPressed: () async {
                bool? confirmLogout = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: theme.colorScheme.surface,
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Déconnexion'),
                      ],
                    ),
                    content: const Text(
                      'Êtes-vous sûr de vouloir vous déconnecter ?',
                      style: TextStyle(height: 1.4),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Annuler'),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.error,
                              theme.colorScheme.error.withOpacity(0.8),
                            ],
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Déconnexion',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmLogout == true) {
                  authProvider.logout();
                }
              },
            ),
          ),
        ],
        // Barre de recherche avec design amélioré
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.primaryColor.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SearchBarWidget(
                onSearchChanged: (query) {
                  Provider.of<SongProvider>(context, listen: false).searchSongs(query);
                },
              ),
            ),
          ),
        ),
      ),
      body: bodyContent,
      // Mini player avec animation améliorée
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: audioPlayerService.currentSong != null && audioPlayerService.showPlayer ? null : 0,
        child: audioPlayerService.currentSong != null && audioPlayerService.showPlayer
            ? Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.scaffoldBackgroundColor.withOpacity(0.95),
                theme.scaffoldBackgroundColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: MiniPlayerWidget(),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}