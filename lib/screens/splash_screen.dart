import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
    // Si vous voulez forcer une vérification ici:
    // Future.microtask(() => Provider.of<AuthProvider>(context, listen: false).tryAutoLogin());
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Chargement de l'application..."),
          ],
        ),
      ),
    );
  }
}