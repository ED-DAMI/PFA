// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Importer Provider
import '../providers/auth_provider.dart'; // Importer AuthProvider
// Ne plus importer ApiService directement ici

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  // bool _isLoading = false; // L'état de chargement est maintenant dans AuthProvider

  // final ApiService _apiService = ApiService(); // Supprimer l'instance directe

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitAuthForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save(); // Bonne pratique

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Accéder à AuthProvider pour appeler les méthodes login/signup
    // listen: false car on appelle une action, on ne reconstruit pas le widget basé sur un changement ici
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = false;
    if (_isLogin) {
      success = await authProvider.login(email, password);
    } else {
      final name = 'NomUtilisateur'; // Récupérez le nom d'un champ si vous l'ajoutez
      success = await authProvider.signup(name, email, password);
    }

    // La navigation est gérée par MyApp en fonction de authProvider.isAuthenticated
    // On peut afficher un message d'erreur si l'authentification a échoué
    if (!success && mounted) { // 'mounted' vérifie si le widget est toujours dans l'arbre
      final error = authProvider.authError ?? 'Une erreur inconnue est survenue.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
    // Pas besoin de setState(() => _isLoading = false) ici
    // Pas besoin de Navigator.pushReplacementNamed('/home') ici non plus
  }

  @override
  Widget build(BuildContext context) {
    // Écouter les changements de AuthProvider pour isLoading et authError
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centrer verticalement
              children: [
                Icon(Icons.music_note, size: 80, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(_isLogin ? 'Connexion' : 'Inscription', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 30),

                // Champ Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value == null || !value.contains('@') ? 'Entrez un email valide' : null,
                ),
                const SizedBox(height: 16),

                // Champ Mot de passe
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (value) => value == null || value.length < 6 ? 'Au moins 6 caractères' : null,
                ),
                const SizedBox(height: 16),

                // Champ Confirmer Mot de passe (si inscription)
                if (!_isLogin)
                  TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', prefixIcon: Icon(Icons.lock_outline), border: OutlineInputBorder()),
                      obscureText: true,
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      }
                  ),
                const SizedBox(height: 24),

                // Afficher l'indicateur de chargement ou le bouton
                if (authProvider.isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)), // Bouton plus large
                    onPressed: _submitAuthForm,
                    child: Text(_isLogin ? 'Se connecter' : 'S\'inscrire'),
                  ),
                const SizedBox(height: 16),

                // Afficher le message d'erreur s'il y en a un (optionnel ici, déjà géré par SnackBar)
                // if (authProvider.authError != null)
                //   Padding(
                //     padding: const EdgeInsets.only(top: 8.0),
                //     child: Text(
                //       authProvider.authError!,
                //       style: TextStyle(color: Theme.of(context).colorScheme.error),
                //     ),
                //   ),

                // Bouton pour basculer entre Connexion et Inscription
                TextButton(
                  onPressed: authProvider.isLoading ? null : () { // Désactiver si en chargement
                    setState(() => _isLogin = !_isLogin);
                  },
                  child: Text(_isLogin
                      ? 'Pas encore de compte ? S\'inscrire'
                      : 'Déjà un compte ? Se connecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}