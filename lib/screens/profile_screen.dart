// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importer Provider
import '../providers/auth_provider.dart'; // Importer AuthProvider
import '../models/user.dart';           // Importer le modèle User
import 'settings_screen.dart';
// Ne plus importer AuthScreen directement ici pour le logout, la logique est dans le provider

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _logout(BuildContext context) {
    // Appeler la méthode logout du provider
    // listen: false car c'est une action
    Provider.of<AuthProvider>(context, listen: false).logout();

    // La navigation vers AuthScreen est maintenant gérée automatiquement par MyApp
    // car l'état isAuthenticated a changé.
    // Plus besoin de Navigator.pushAndRemoveUntil ici.
  }

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de AuthProvider pour obtenir l'utilisateur actuel
    // listen: true (par défaut) car l'UI doit se reconstruire si l'utilisateur change
    final authProvider = Provider.of<AuthProvider>(context);
    final User? user = authProvider.currentUser; // Obtenir l'utilisateur actuel (peut être null)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => _navigateToSettings(context),
          ),
        ],
      ),
      body: user == null // Vérifier si l'utilisateur est connecté
          ? const Center(child: Text("Vous n'êtes pas connecté.")) // Ou un autre indicateur
          : SingleChildScrollView( // Afficher le profil si l'utilisateur existe
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Profile Picture (Utiliser une image de l'utilisateur si disponible)
            CircleAvatar(
              radius: 50,
              // backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null, // Exemple si photoUrl existe
              backgroundImage: const NetworkImage('https://via.placeholder.com/150'), // Placeholder
              backgroundColor: Colors.grey,
              child: user.photoUrl == null ? const Icon(Icons.person, size: 50) : null, // Icône si pas d'image
            ),
            const SizedBox(height: 16),

            // Username (Utiliser le nom de l'utilisateur connecté)
            Text(
              user.name, // Afficher le nom réel
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            // Email (Utiliser l'email de l'utilisateur connecté)
            Text(
              user.email, // Afficher l'email réel
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 30),
            const Divider(),

            // Section: Playlists favorites
            ListTile( /* ... comme avant ... */ ),

            // Section: Écoutés récemment
            ListTile( /* ... comme avant ... */ ),

            // Section: Préférences
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('Préférences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToSettings(context),
            ),

            const Divider(),
            const SizedBox(height: 20),

            // Logout Button
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              onPressed: () => _logout(context), // Appelle la nouvelle fonction _logout
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ajouter ce champ `photoUrl` au modèle User si votre API le fournit
// // Dans lib/models/user.dart
// class User {
//   final String id;
//   final String email;
//   final String name;
//   final String? photoUrl; // Champ optionnel pour l'URL de l'image
//
//   User({required this.id, required this.email, required this.name, this.photoUrl});
//
//   factory User.fromJson(Map<String, dynamic> json) {
//     return User(
//       id: json['_id'] ?? json['id'] ?? '',
//       email: json['email'] ?? '',
//       name: json['name'] ?? 'Utilisateur',
//       photoUrl: json['photoUrl'], // Récupérer l'URL de la photo
//     );
//   }
// }