import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'utils/app_theme.dart'; // Assure-toi d’avoir ce fichier

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      theme: AppTheme.lightTheme, // Thème clair personnalisé
      darkTheme: AppTheme.darkTheme, // Thème sombre personnalisé
      themeMode: ThemeMode.system, // Utilise le thème du système (ou forcez ThemeMode.light/dark)
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.authState) {
            case AuthState.uninitialized:
              return const SplashScreen(); // À afficher au démarrage
            case AuthState.unauthenticated:
              return const LoginScreen(); // Utilisateur non connecté
            case AuthState.authenticated:
              return const HomeScreen(); // Utilisateur connecté
            default:
              return const LoginScreen(); // Fallback de sécurité
          }
        },
      ),
    );
  }
}
