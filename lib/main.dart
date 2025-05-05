// lib/main.dart

import 'package:flutter/material.dart';
import 'package:pfa/services/ApiService.dart';



import 'package:provider/provider.dart';

// --- Importez TOUS vos modèles, services et providers ---
// (Assurez-vous que les chemins et la casse sont corrects)
import 'config/api_config.dart'; // Service API
import 'services/audio_player_service.dart'; // Service Audio
import 'providers/auth_provider.dart';       // Provider Auth
import 'providers/home_provider.dart';       // Provider Home
import 'providers/PlaylistProvider.dart';   // Provider Playlist

// --- Importez vos écrans principaux ---
import 'screens/home_screen.dart';
import 'screens/now_playing_screen.dart';
// Importez d'autres écrans utilisés dans les routes si nécessaire

// --- Définir l'URL de base du Backend ---
// !! IMPORTANT : MODIFIEZ CECI AVEC VOTRE VRAIE URL !!
const String API_BASE_URL1 =API_BASE_URL ;

void main() {
// Optionnel: assure l'initialisation si des plugins l'exigent avant runApp
// WidgetsFlutterBinding.ensureInitialized();

  runApp(
// Fournir tous les services et états globaux à l'application
    MultiProvider(
      providers: [
// 1. Services de base (pas de dépendances inter-providers)
        Provider<ApiService>(
          create: (_) => ApiService(), // Instance unique d'ApiService
// lazy: false, // Décommentez si vous voulez le créer immédiatement
        ),

// 2. Providers qui dépendent des services de base
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<ApiService>() // Injecte ApiService
          ),
        ),

        ChangeNotifierProvider<AudioPlayerService>(
// Injecte l'URL de base nécessaire au service audio
          create: (_) => AudioPlayerService(baseUrl: API_BASE_URL),
        ),

        ChangeNotifierProvider<HomeProvider>(
          create: (context) => HomeProvider(
            context.read<ApiService>() , // Injecte ApiService
// Injectez AuthProvider si HomeProvider en a besoin:
// context.read<AuthProvider>(),
          ),
        ),

// 3. Providers qui dépendent d'autres Providers (ProxyProvider est utile ici)
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
// Crée l'instance initiale
            create: (context) => PlaylistProvider(
              context.read<ApiService>(), // Injecte ApiService
              context.read<AuthProvider>(), // Injecte AuthProvider initial
            ),
// Met à jour PlaylistProvider quand AuthProvider notifie un changement
            update: (context, authProvider, previousPlaylistProvider) {
// Crée une nouvelle instance ou met à jour l'ancienne
// Ici, on en crée une nouvelle qui s'abonne au nouvel AuthProvider
// (S'assure que le constructeur et dispose gèrent bien l'abonnement/désabonnement)
              print("[MultiProvider] AuthProvider changed, updating PlaylistProvider.");
              return PlaylistProvider(
                context.read<ApiService>(), // ApiService ne change pas
                authProvider, // Passe la NOUVELLE instance/état d'AuthProvider
              );
            }
        ),

// Ajoutez d'autres providers globaux ici si nécessaire...

      ],
      child: const MyApp(), // Le widget racine de votre application
    ),
  );
}

// --- Classe Principale de l'Application ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App', // Changez le nom de votre application
      debugShowCheckedModeBanner: false, // Masquer la bannière "Debug"
      theme: ThemeData(
// Définissez votre thème principal
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple, // Couleur de base pour générer la palette
          brightness: Brightness.dark, // Thème sombre (ou Brightness.light pour clair)
        ),
        useMaterial3: true, // Activer le style Material 3
// Personnalisez d'autres aspects du thème si nécessaire
// appBarTheme: AppBarTheme(...)
// elevatedButtonTheme: ElevatedButtonThemeData(...)
      ),

// Écran de démarrage de l'application
// HomeScreen n'a plus besoin de `baseUrl` car ses enfants (SongListItem)
// le récupèrent du constructeur ou d'un Provider/config.
      home: const HomeScreen(),

// Définir les routes nommées pour la navigation
      routes: {
// '/login': (context) => LoginScreen(), // Exemple
// '/signup': (context) => SignupScreen(), // Exemple
// NowPlayingScreen a besoin de baseUrl. Si on utilise une route nommée,
// il faut un moyen de lui passer (via arguments ou un Provider de config).
// Si vous naviguez toujours avec MaterialPageRoute, c'est géré directement.
        '/now_playing': (context) => const NowPlayingScreen(baseUrl: API_BASE_URL),
// La route pour PlaylistDetailScreen nécessiterait de passer des arguments (id, name, baseUrl)
// '/playlist_detail': (context) => ... // Gérer les arguments
      },

// Optionnel: Gérer les routes inconnues
// onUnknownRoute: (settings) { ... }

// Optionnel: Observer de navigation
// navigatorObservers: [ ... ]
    );
  }
}