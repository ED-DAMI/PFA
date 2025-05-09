// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert'; // Pour encoder/décoder le User en JSON pour SharedPreferences
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/ApiService.dart';
 // Correction du nom du fichier

// Enum pour gérer les états d'authentification de manière claire
enum AuthState {
  uninitialized, // État initial, vérification en cours
  authenticated, // Utilisateur connecté
  unauthenticated, // Utilisateur non connecté ou déconnecté
  authenticating, // En cours de connexion ou d'inscription
}

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  User? _currentUser;
  String? _token;
  AuthState _authState = AuthState.uninitialized;
  String? _errorMessage;
  // Timer? _authTimer; // Pour gérer l'expiration du token (fonctionnalité avancée)

  AuthProvider(this._apiService) {
    _tryAutoLogin(); // Tenter de connecter l'utilisateur automatiquement au démarrage
  }

  // --- Getters ---
  User? get currentUser => _currentUser;
  String? get token => _token; // Token actuel (pourrait être null)
  AuthState get authState => _authState;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  String? get errorMessage => _errorMessage; // Renommé pour cohérence

  // Utile pour les appels API qui nécessitent un token potentiellement valide
  Future<String?> getValidToken() async {
    if (_token != null) {
      // TODO: Implémenter la vérification de l'expiration du token ici
      // Si le token est sur le point d'expirer ou a expiré, tenter de le rafraîchir.
      // Pour l'instant, nous retournons simplement le token s'il existe.
      // Exemple:
      // if (isTokenExpired(_tokenExpiryDate)) {
      //   await refreshToken();
      // }
      return _token;
    }
    return null;
  }

  // --- Logique d'authentification ---

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('authData')) {
      _updateAuthState(AuthState.unauthenticated);
      return;
    }

    try {
      final extractedAuthData = prefs.getString('authData');
      if (extractedAuthData == null) {
        _updateAuthState(AuthState.unauthenticated);
        return;
      }
      final authData = json.decode(extractedAuthData) as Map<String, dynamic>;

      final token = authData['token'] as String?;
      // Optionnel: Vérifier la date d'expiration si elle est stockée
      // final expiryDateString = authData['expiryDate'] as String?;
      // if (expiryDateString != null) {
      //   final expiryDate = DateTime.parse(expiryDateString);
      //   if (expiryDate.isBefore(DateTime.now())) {
      //     await logout(); // Le token a expiré
      //     return;
      //   }
      // }

      if (token != null && authData['user'] != null) {
        _token = token;
        _currentUser = User.fromJson(authData['user'] as Map<String, dynamic>);
        _updateAuthState(AuthState.authenticated);
        // _autoLogout(); // Si vous gérez l'expiration
        print("[AuthProvider] Auto-login successful for: ${_currentUser?.email}");
      } else {
        _updateAuthState(AuthState.unauthenticated);
      }
    } catch (e) {
      print("[AuthProvider] Error during auto-login: $e");
      _updateAuthState(AuthState.unauthenticated); // En cas d'erreur de parsing, etc.
      await prefs.remove('authData'); // Nettoyer les données corrompues
    }
  }

  Future<bool> login(String email, String password) async {
    _updateAuthState(AuthState.authenticating, error: null); // Met à jour l'état et nettoie l'erreur

    try {
      final responseData = await _apiService.loginUser(email, password);

      if (responseData != null &&
          responseData['user'] != null &&
          responseData['token'] != null) {
        _currentUser = User.fromJson(responseData['user'] as Map<String, dynamic>);
        _token = responseData['token'] as String?;

        await _persistAuthData();
        _updateAuthState(AuthState.authenticated);
        print("[AuthProvider] Login successful for: ${currentUser?.email}. Token stored: ${_token != null}");
        // _autoLogout(); // Si vous gérez l'expiration
        return true;
      } else {
        final message = responseData?['message'] as String? ?? 'Réponse invalide du serveur après connexion.';
        _updateAuthState(AuthState.unauthenticated, error: message);
        return false;
      }
    } catch (e) {
      print("[AuthProvider] Login Error: $e");
      _updateAuthState(AuthState.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _updateAuthState(AuthState.authenticating, error: null);

    try {
      final responseData = await _apiService.signupUser(name, email, password);

      // Adaptez cette condition à la réponse de votre API après l'inscription
      // Certaines API connectent l'utilisateur directement et retournent un token,
      // d'autres retournent juste un message de succès.
      if (responseData != null && responseData['user'] != null) {
        // Si l'API retourne l'utilisateur et potentiellement un token (connexion auto)
        _currentUser = User.fromJson(responseData['user'] as Map<String, dynamic>);
        _token = responseData['token'] as String?; // Peut être null si pas de login auto

        if (_token != null) {
          await _persistAuthData();
          _updateAuthState(AuthState.authenticated);
          print("[AuthProvider] Signup successful and logged in: ${currentUser?.email}. Token stored: ${_token != null}");
          // _autoLogout();
        } else {
          // L'utilisateur est inscrit mais pas connecté, il devra se logger.
          _updateAuthState(AuthState.unauthenticated); // Ou un état "needsLoginAfterSignup"
          print("[AuthProvider] Signup successful for: $email. User needs to login.");
        }
        return true; // Inscription réussie
      } else {
        final message = responseData?['message'] as String? ?? 'Réponse invalide du serveur après inscription.';
        _updateAuthState(AuthState.unauthenticated, error: message);
        return false;
      }
    } catch (e) {
      print("[AuthProvider] Signup Error: $e");
      _updateAuthState(AuthState.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    print("[AuthProvider] Logging out user: ${_currentUser?.email}");
    // TODO: Appeler une API de logout si elle existe pour invalider le token côté serveur
    // try { if (_token != null) await _apiService.logoutUser(_token!); } catch (e) { print("Error on API logout: $e"); }

    _currentUser = null;
    _token = null;
    // if (_authTimer != null) {
    //   _authTimer!.cancel();
    //   _authTimer = null;
    // }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authData');
    // prefs.clear(); // Si vous voulez tout effacer

    _updateAuthState(AuthState.unauthenticated, error: null); // Mettre à jour l'état après le nettoyage
  }

  // --- Helpers ---

  Future<void> _persistAuthData() async {
    if (_token == null || _currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final authData = json.encode({
      'token': _token,
      'user': _currentUser!.toJson(), // Assurez-vous que User a une méthode toJson()
      // Optionnel: Stocker la date d'expiration pour une gestion côté client
      // 'expiryDate': DateTime.now().add(Duration(hours: 24)).toIso8601String(), // Exemple
    });
    await prefs.setString('authData', authData);
  }

  void _updateAuthState(AuthState newState, {String? error}) {
    // Mettre à jour l'erreur seulement si elle est fournie, sinon la garder ou la nettoyer
    if (error != null || newState != AuthState.authenticating) {
      _errorMessage = error;
    }

    if (_authState != newState) {
      _authState = newState;
      notifyListeners();
    } else if (error != null && _errorMessage != error) {
      // Si l'état n'a pas changé mais l'erreur oui, notifier quand même
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  bool hasAuthChangedSignificantly() {
    return false;
  }

// --- Gestion de l'expiration du token (optionnel, à implémenter) ---
// void _autoLogout() {
//   if (_authTimer != null) {
//     _authTimer!.cancel();
//   }
//   // Récupérez la durée de validité du token depuis votre API ou une config
//   // final timeToExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
//   // _authTimer = Timer(Duration(seconds: timeToExpiry), logout);
// }

// Future<void> refreshToken() async {
//   // Logique pour rafraîchir le token
// }
}