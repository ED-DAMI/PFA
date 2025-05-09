import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/ApiService.dart';
import 'services/audio_player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/song_provider.dart';
import 'providers/interaction_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialiser les données de formatage pour 'fr_FR'
  await initializeDateFormatting('fr_FR', null);

  final apiService = ApiService();
  final audioPlayerService = AudioPlayerService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AudioPlayerService>.value(
          value: audioPlayerService,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(apiService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SongProvider>(
          create: (ctx) => SongProvider(apiService, Provider.of<AuthProvider>(ctx, listen: false)),
          update: (ctx, authProvider, previous) {
            previous?.updateAuthProvider(authProvider);
            return previous ?? SongProvider(apiService, authProvider);
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, InteractionProvider>(
          create: (ctx) => InteractionProvider(apiService, Provider.of<AuthProvider>(ctx, listen: false)),
          update: (ctx, authProvider, previous) {
            previous?.updateAuthProvider(authProvider);
            return previous ?? InteractionProvider(apiService, authProvider);
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}
