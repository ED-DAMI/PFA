import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'widgets/services/ApiService.dart';
import 'widgets/services/audio_player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/song_provider.dart';
import 'providers/interaction_provider.dart';
import 'providers/history_provider.dart';   // <-- IMPORTER HISTORY_PROVIDER
import 'providers/playlist_provider.dart'; // <-- IMPORTER PLAYLIST_PROVIDER

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  runApp(
    MultiProvider(
      providers: [
        // 1. ApiService
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // 2. AudioPlayerService
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => AudioPlayerService(),
        ),

        // 3. AuthProvider (dépend d'ApiService)
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(Provider.of<ApiService>(ctx, listen: false)),
        ),

        // 4. SongProvider (dépend d'ApiService et AuthProvider)
        ChangeNotifierProxyProvider<AuthProvider, SongProvider>(
          create: (ctx) => SongProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false), // AuthProvider initial
          ),
          update: (ctx, auth, previousSongProvider) {
            // Assurez-vous que SongProvider a une méthode updateAuthProvider
            previousSongProvider?.updateAuthProvider(auth);
            return previousSongProvider ?? SongProvider(
                Provider.of<ApiService>(ctx, listen: false),
                auth
            );
          },
        ),

        // 5. InteractionProvider (dépend d'ApiService, AuthProvider, SongProvider)
        ChangeNotifierProxyProvider2<AuthProvider, SongProvider, InteractionProvider>(
          create: (ctx) => InteractionProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
            Provider.of<SongProvider>(ctx, listen: false),
          ),
          update: (ctx, auth, song, previousInteractionProvider) {
            // Assurez-vous qu'InteractionProvider a une méthode updateAuthProvider
            // et potentiellement updateSongProvider si nécessaire
            previousInteractionProvider?.updateAuthProvider(auth);
            // previousInteractionProvider?.updateSongProvider(song);
            return previousInteractionProvider ?? InteractionProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
              song,
            );
          },
        ),

        // --- AJOUT DE HISTORY_PROVIDER ET PLAYLIST_PROVIDER ---
        // 6. HistoryProvider (dépend d'ApiService et AuthProvider)
        ChangeNotifierProxyProvider<AuthProvider, HistoryProvider>(
          create: (ctx) => HistoryProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false), // AuthProvider initial
          ),
          update: (ctx, auth, previousHistoryProvider) {
            // HistoryProvider a déjà une méthode updateAuthProvider
            previousHistoryProvider?.updateAuthProvider(auth);
            return previousHistoryProvider ?? HistoryProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
            );
          },
        ),

        // 7. PlaylistProvider (dépend d'ApiService et AuthProvider)
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (ctx) => PlaylistProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false), // AuthProvider initial
          ),
          update: (ctx, auth, previousPlaylistProvider) {
            // Assurez-vous que PlaylistProvider a une méthode updateAuthProvider
            previousPlaylistProvider?.updateAuthProvider(auth);
            return previousPlaylistProvider ?? PlaylistProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
            );
          },
        ),
        // --- FIN DE L'AJOUT ---
      ],
      child: const MyApp(),
    ),
  );
}