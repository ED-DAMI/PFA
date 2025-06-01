// lib/app.dart
import 'package:flutter/material.dart';
import 'package:pfa/screens/edit_profile_screen.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart'; // Assurez-vous que le nom du fichier et de la classe est correct
import 'providers/auth_provider.dart';
import 'utils/app_theme.dart';

// Importer les écrans pour les routes nommées
import 'screens/user_profile_screen.dart'; // <-- IMPORTANT : IMPORTER L'ÉCRAN
import 'screens/song_detail_screen.dart';   // <-- Si vous avez aussi une route pour cela

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.authState) {
            case AuthState.uninitialized:
              return const SplashScreen();
            case AuthState.unauthenticated:
              return const LoginScreen(); // Assurez-vous que LoginScreen est bien le nom de la classe
            case AuthState.authenticated:
              return const HomeScreen();
            default:
              return const LoginScreen(); // Assurez-vous que LoginScreen est bien le nom de la classe
          }
        },
      ),
      // ---- AJOUTEZ LA TABLE DES ROUTES ICI ----
      routes: {
        // Vous pouvez aussi définir des routes pour HomeScreen et LoginScreen ici
        // si vous voulez pouvoir y naviguer par nom depuis d'autres endroits,
        // bien que ce soit moins courant si elles sont gérées par la logique 'home'.
        // HomeScreen.routeName: (ctx) => const HomeScreen(),
        // LoginScreen.routeName: (ctx) => const LoginScreen(), // Assurez-vous que LoginScreen a un routeName

        UserProfileScreen.routeName: (ctx) => const UserProfileScreen(),
        EditProfileScreen.routeName: (ctx) => const EditProfileScreen(),
        // <-- LA ROUTE MANQUANTE
           // <-- Exemple pour une autre route

      },
      // -----------------------------------------
    );
  }
}