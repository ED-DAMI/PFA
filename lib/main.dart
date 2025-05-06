// lib/main.dart

import 'package:flutter/material.dart';
import 'package:pfa/screens/auth_screen.dart'; // Assurez-vous d'importer AuthScreen
import 'package:pfa/services/ApiService.dart';
import 'package:provider/provider.dart';


import 'config/api_config.dart';
import 'services/audio_player_service.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/PlaylistProvider.dart';

import 'screens/home_screen.dart';
import 'screens/now_playing_screen.dart';
// Importez d'autres écrans utilisés dans les routes si nécessaire

// --- Définir l'URL de base du Backend ---
// !! IMPORTANT : MODIFIEZ CECI AVEC VOTRE VRAIE URL !!
const String API_BASE_URL1 = API_BASE_URL; // Utilisez votre constante existante

void main() {

  runApp(
    MultiProvider(
      providers: [
        // 1. Services de base
        Provider<ApiService>(
          create: (_) => ApiService(),
        ),

        // 2. Providers qui dépendent des services de base
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<ApiService>(),
          ),

        ),
        ChangeNotifierProvider<AudioPlayerService>(
          create: (_) => AudioPlayerService(baseUrl: API_BASE_URL),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create: (context) => HomeProvider(
            context.read<ApiService>(),
          ),
        ),

        // 3. Providers qui dépendent d'autres Providers
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (context) => PlaylistProvider(
            context.read<ApiService>(),
            context.read<AuthProvider>(),
          ),
          update: (context, authProvider, previousPlaylistProvider) {
            print("[MultiProvider] AuthProvider changed, updating PlaylistProvider.");
            // Crée une nouvelle instance pour s'assurer qu'elle utilise le nouvel authProvider
            // Si PlaylistProvider a une méthode pour mettre à jour authProvider, utilisez-la
            return PlaylistProvider(
              context.read<ApiService>(),
              authProvider,
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// --- Classe Principale de l'Application ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- POINT CLÉ : Écouter l'état d'authentification ---
    // context.watch<AuthProvider>() permet au widget MyApp de se reconstruire
    // lorsque AuthProvider appelle notifyListeners() après un login/logout.
    final authProvider = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      // --- DÉCISION DE L'ÉCRAN D'ACCUEIL ---
      // Si l'utilisateur est authentifié, aller à HomeScreen, sinon à AuthScreen.
      home: authProvider.isAuthenticated
          ? const HomeScreen()
          : const AuthScreen(),

      // Les routes restent les mêmes pour la navigation interne
      routes: {
        // Ajoutez '/' ou '/home' si vous voulez pouvoir y naviguer explicitement
        '/home': (context) => const HomeScreen(), // Exemple
        // '/login': (context) => LoginScreen(), // Pas nécessaire si AuthScreen gère tout
        // '/signup': (context) => SignupScreen(), // Pas nécessaire si AuthScreen gère tout
        '/now_playing': (context) => const NowPlayingScreen(baseUrl: API_BASE_URL),
        // '/playlist_detail': (context) => ...
      },
    );
  }
}