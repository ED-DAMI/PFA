// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/ApiService.dart'; // Assurez-vous que ce modèle existe
 // Correction: APIservice -> ApiService (Casse)

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  User? _currentUser;
  String? _token; // Le token réel
  bool _isLoading = false;
  String? _authError;

  AuthProvider(this._apiService);

  // Getters
  User? get currentUser => _currentUser;
  // String? get token => _token; // Getter direct peut être moins sûr si token expire
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  // --- NOUVELLE MÉTHODE ASYNCHRONE POUR OBTENIR LE TOKEN ---
  // Nécessaire pour FutureBuilder et pour gérer la logique d'expiration potentielle
  Future<String?> getToken() async {
    if (_token != null) {
      // TODO: Ajouter ici une logique pour vérifier si le token est expiré.
      // Si expiré, tenter de le rafraîchir ou forcer la déconnexion.
      // Pour l'instant, on retourne le token s'il existe.
      return _token;
    }
    return null; // Retourne null si pas de token
  }

  // --- Méthodes existantes (login, signup, logout) ---

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _authError = null;
    try {
      final responseData = await _apiService.loginUser(email, password);
      if (responseData != null && responseData['user'] != null) {
        // S'assurer que le parsing est correct
        _currentUser = User.fromJson(responseData['user'] as Map<String, dynamic>);
        // S'assurer que la clé 'token' existe et est une String
        _token = responseData['token'] as String?;
        print("[AuthProvider] Login successful. Token stored: ${_token != null}");
        _setLoading(false);
        return true;
      } else {
        _authError = 'Réponse invalide après connexion.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("[AuthProvider] Login Error: $e");
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _setLoading(true);
    _authError = null;
    try {
      final responseData = await _apiService.signupUser(name, email, password);
      if (responseData != null && responseData['user'] != null) {
        _currentUser = User.fromJson(responseData['user'] as Map<String, dynamic>);
        _token = responseData['token'] as String?;
        print("[AuthProvider] Signup successful. Token stored: ${_token != null}");
        _setLoading(false);
        return true;
      } else {
        _authError = 'Réponse invalide après inscription.';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print("[AuthProvider] Signup Error: $e");
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    print("[AuthProvider] Logging out.");
    // TODO: Appeler API de logout si elle existe et invalider le token côté serveur
    // try { if (_token != null) await _apiService.logout(_token!); } catch (e) {}
    _currentUser = null;
    _token = null;
    _authError = null;
    _isLoading = false;
    notifyListeners();
  }

  // Helper inchangé
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
}