import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart'; // Assurez-vous que ce fichier existe et contient MyApp
import 'services/ApiService.dart';
import 'services/audio_player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/song_provider.dart';
import 'providers/interaction_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialiser les données de formatage pour 'fr_FR'
  await initializeDateFormatting('fr_FR', null);



  runApp(
    MultiProvider(
      providers: [
        // 1. Fournir ApiService. Il est généralement indépendant.
        // Puisque ApiService n'est pas un ChangeNotifier, utilisez Provider.
        Provider<ApiService>(
          create: (_) => ApiService(), // Crée une nouvelle instance ici ou utilise celle ci-dessus
        ),

        // 2. Fournir AudioPlayerService.
        // Si AudioPlayerService est un ChangeNotifier, utilisez ChangeNotifierProvider.
        // S'il n'est pas un ChangeNotifier mais a une méthode dispose(), utilisez Provider avec dispose.
        // S'il est un ChangeNotifier et vous avez déjà une instance:
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => AudioPlayerService(), // Crée une nouvelle instance ou:
          // value: audioPlayerService, // Si vous avez créé `audioPlayerService` plus haut et voulez utiliser cette instance
        ),
        // Ou si ce n'est PAS un ChangeNotifier mais a une méthode dispose :
        // Provider<AudioPlayerService>(
        //   create: (_) => AudioPlayerService(), // ou `create: (_) => audioPlayerService,`
        //   dispose: (_, service) => service.dispose(),
        // ),


        // 3. AuthProvider dépend d'ApiService.
        ChangeNotifierProvider<AuthProvider>(
          // Utilise Provider.of pour obtenir l'instance d'ApiService fournie ci-dessus.
          create: (ctx) => AuthProvider(Provider.of<ApiService>(ctx, listen: false)),
        ),

        // 4. SongProvider dépend d'ApiService et AuthProvider.
        ChangeNotifierProxyProvider<AuthProvider, SongProvider>(
          create: (ctx) => SongProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
          ),
          update: (ctx, authProvider, previousSongProvider) {
            previousSongProvider?.updateAuthProvider(authProvider);
            // Il est important de recréer avec le nouveau authProvider si previous est null
            // ou de mettre à jour l'existant.
            return previousSongProvider ?? SongProvider(
                Provider.of<ApiService>(ctx, listen: false),
                authProvider
            );
          },
        ),

        // 5. InteractionProvider dépend d'ApiService, AuthProvider, et potentiellement SongProvider.
        // J'ajoute SongProvider comme dépendance au cas où vous en auriez besoin.
        ChangeNotifierProxyProvider2<AuthProvider, SongProvider, InteractionProvider>(
          create: (ctx) => InteractionProvider(
            Provider.of<ApiService>(ctx, listen: false),
            Provider.of<AuthProvider>(ctx, listen: false),
            Provider.of<SongProvider>(ctx, listen: false), // Ajouté ici
          ),
          update: (ctx, authProvider, songProvider, previousInteractionProvider) {
            previousInteractionProvider?.updateAuthProvider(authProvider);
            // Mettre à jour/recréer InteractionProvider
            return previousInteractionProvider ?? InteractionProvider(
              Provider.of<ApiService>(ctx, listen: false),
              authProvider,
              songProvider, // Ajouté ici
            );
          },
        ),
      ],
      child: const MyApp(), // Assurez-vous que MyApp est défini dans app.dart
    ),
  );
}