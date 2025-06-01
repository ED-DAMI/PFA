import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/ApiService.dart';
import 'services/audio_player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/song_provider.dart';
import 'providers/interaction_provider.dart';
import 'providers/history_provider.dart';
import 'providers/playlist_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  runApp(
    MultiProvider(
      providers: [
        // 1. ApiService (Aucun changement)
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // 2. AuthProvider (dépend d'ApiService - Aucun changement ici, mais son ordre est important)
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(Provider.of<ApiService>(ctx, listen: false)),
        ),

        // 3. AudioPlayerService (MAINTENANT DÉPEND D'APISERVICE ET AUTHPROVIDER)
        ChangeNotifierProxyProvider<AuthProvider, AudioPlayerService>(
          create: (ctx) => AudioPlayerService(
            apiService: Provider.of<ApiService>(ctx, listen: false),
            authProvider: Provider.of<AuthProvider>(ctx, listen: false), // AuthProvider initial
          ),
          update: (ctx, auth, previousAudioPlayerService) {
            // Si AudioPlayerService avait besoin d'être mis à jour quand AuthProvider change (ce n'est pas le cas ici
            // car il prend juste une référence au moment de la création), vous le feriez ici.
            // Pour l'instant, on retourne l'instance existante ou une nouvelle si elle n'existe pas.
            return previousAudioPlayerService ?? AudioPlayerService(
              apiService: Provider.of<ApiService>(ctx, listen: false),
              authProvider: auth, // Utiliser l'AuthProvider mis à jour
            );
            // Note: Une approche plus simple si AudioPlayerService n'a pas besoin de réagir aux *changements*
            // d'AuthProvider après sa création (juste besoin de la référence initiale):
            // return previousAudioPlayerService!; // Ou le créer s'il est null, comme ci-dessus.
            // Pour être sûr, il est bon de recréer ou de fournir le nouvel auth.
          },
        ),

        // 4. SongProvider (dépend d'ApiService et AuthProvider - Aucun changement)
        ChangeNotifierProxyProvider<AuthProvider, SongProvider>(
          create: (ctx) => SongProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
          ),
          update: (ctx, auth, previousSongProvider) {
            previousSongProvider?.updateAuthProvider(auth);
            return previousSongProvider ?? SongProvider(
                Provider.of<ApiService>(ctx, listen: false),
                auth
            );
          },
        ),

        // 5. InteractionProvider (dépend d'ApiService, AuthProvider, SongProvider - Aucun changement)
        ChangeNotifierProxyProvider2<AuthProvider, SongProvider, InteractionProvider>(
          create: (ctx) => InteractionProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
            Provider.of<SongProvider>(ctx, listen: false),
          ),
          update: (ctx, auth, song, previousInteractionProvider) {
            previousInteractionProvider?.updateAuthProvider(auth);
            return previousInteractionProvider ?? InteractionProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
              song,
            );
          },
        ),

        // 6. HistoryProvider (dépend d'ApiService et AuthProvider - Aucun changement)
        ChangeNotifierProxyProvider<AuthProvider, HistoryProvider>(
          create: (ctx) => HistoryProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
          ),
          update: (ctx, auth, previousHistoryProvider) {
            previousHistoryProvider?.updateAuthProvider(auth);
            return previousHistoryProvider ?? HistoryProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
            );
          },
        ),

        // 7. PlaylistProvider (dépend d'ApiService et AuthProvider - Aucun changement)
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (ctx) => PlaylistProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
          ),
          update: (ctx, auth, previousPlaylistProvider) {
            previousPlaylistProvider?.updateAuthProvider(auth);
            return previousPlaylistProvider ?? PlaylistProvider(
              Provider.of<ApiService>(ctx, listen: false),
              auth,
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}