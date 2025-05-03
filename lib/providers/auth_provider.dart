// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/APIservice.dart';       // Importez le modèle User

class AuthProvider with ChangeNotifier {
  final ApiService _apiService; // Accepte ApiService via le constructeur
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _authError;

  // Constructeur pour recevoir l'instance de ApiService
  AuthProvider(this._apiService);

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  // --- Méthodes pour modifier l'état ---

  Future<bool> login(String email, String password) async {
    _setLoading(true); // Démarre le chargement et notifie
    _authError = null; // Réinitialiser l'erreur précédente

    try {
      // Appeler ApiService (qui lèvera une exception en cas d'erreur HTTP)
      final responseData = await _apiService.loginUser(email, password);

      // Si l'appel réussit et retourne des données valides
      if (responseData != null && responseData['user'] != null) {
        _currentUser = User.fromJson(responseData['user']);
        _token = responseData['token']; // Stocker le token (peut être null)
        _setLoading(false); // Arrête le chargement et notifie
        // notifyListeners(); // Déjà appelé dans _setLoading(false)
        return true; // Succès
      } else {
        // Cas où l'API retourne 2xx mais sans les données attendues (peu probable si _handleResponse est strict)
        _authError = 'Réponse inattendue du serveur après connexion.';
        _setLoading(false); // Arrête le chargement et notifie
        return false; // Échec logique
      }
    } catch (e) {
      // Attraper les exceptions levées par ApiService ou http
      print("Login Error in Provider: $e");
      _authError = e.toString(); // Utiliser le message de l'exception
      _setLoading(false); // Arrête le chargement et notifie
      return false; // Échec
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _setLoading(true);
    _authError = null;

    try {
      final responseData = await _apiService.signupUser(name, email, password);

      if (responseData != null && responseData['user'] != null) {
        _currentUser = User.fromJson(responseData['user']);
        _token = responseData['token'];
        _setLoading(false);
        return true;
      } else {
        _authError = 'Réponse inattendue du serveur après inscription.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("Signup Error in Provider: $e");
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    // Optionnel : Appeler une API de déconnexion
    // try {
    //   if (_token != null) {
    //     await _apiService.logout(_token!); // Assurez-vous que la méthode logout existe dans ApiService
    //   }
    // } catch (e) {
    //    print("Erreur lors de l'appel API de déconnexion: $e");
    //    // Peut-être afficher un message, mais continuer la déconnexion locale
    // }

    // Réinitialiser l'état local
    _currentUser = null;
    _token = null;
    _authError = null;
    _isLoading = false; // Assurer que le chargement est arrêté
    notifyListeners(); // Notifier que l'utilisateur est déconnecté
  }

  // Helper pour gérer l'état de chargement et notifier
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners(); // Notifier immédiatement du changement d'état de chargement
    }
  }
}