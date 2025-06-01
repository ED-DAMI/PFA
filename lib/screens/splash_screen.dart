// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // Pas directement utilisé ici pour l'UI
// import '../providers/auth_provider.dart'; // Pas directement utilisé ici pour l'UI

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // L'appel à _tryAutoLogin est déjà dans le constructeur de AuthProvider
    // On s'assure juste que le build de MyApp s'occupe de la redirection
    // basé sur AuthState.uninitialized.
    // Future.microtask(() => Provider.of<AuthProvider>(context, listen: false).tryAutoLogin());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- MODIFICATION ICI ---
            // Remplacez FlutterLogo par votre propre logo
            FlutterLogo(size: 80, style: FlutterLogoStyle.stacked, textColor: Theme.of(context).primaryColor),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 25),
            Text(
              "Chargement de l'application...",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            // --- FIN DE LA MODIFICATION ---
          ],
        ),
      ),
    );
  }
}