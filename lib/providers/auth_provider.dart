// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Importé
import 'package:jwt_decode/jwt_decode.dart';

import '../models/user.dart';
import '../services/ApiService.dart';


enum AuthState { uninitialized, authenticated, unauthenticated, authenticating, tokenRefreshing }

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  User? _currentUser;
  String? _token;
  String? _refreshToken; // Pour le rafraîchissement du token
  DateTime? _tokenExpiryDate;
  AuthState _authState = AuthState.uninitialized;
  String? _errorMessage;
  Timer? _authTimer;

  final _secureStorage = const FlutterSecureStorage();
  static const _tokenKey = 'authToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _userDataKey = 'userData'; // Pour SharedPreferences (données non sensibles de l'utilisateur)


  AuthProvider(this._apiService) {
    _tryAutoLogin();
  }

  User? get currentUser => _currentUser;
  String? get token => _token;
  AuthState get authState => _authState;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  String? get errorMessage => _errorMessage;

  Future<String?> getValidToken() async {
    if (_token == null) return null;
    if (_tokenExpiryDate != null && _tokenExpiryDate!.isBefore(DateTime.now())) {
      if (kDebugMode) print("[AuthProvider] Token expired. Attempting refresh.");
      bool refreshed = await attemptRefreshToken();
      return refreshed ? _token : null;
    }
    return _token;
  }

  Future<void> _tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = await _secureStorage.read(key: _tokenKey);
    final storedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final storedUserData = prefs.getString(_userDataKey);

    if (storedToken == null || storedUserData == null) {
      _updateAuthState(AuthState.unauthenticated);
      return;
    }

    try {
      _token = storedToken;
      _refreshToken = storedRefreshToken;
      _currentUser = User.fromJson(json.decode(storedUserData) as Map<String, dynamic>);

      Map<String, dynamic>? decodedToken = _decodeToken(_token!);
      if (decodedToken != null && decodedToken.containsKey('exp')) {
        _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
        if (_tokenExpiryDate!.isBefore(DateTime.now())) {
          if(kDebugMode) print("[AuthProvider] Auto-login: Token expired, attempting refresh.");
          if (!await attemptRefreshToken()) { // Si le refresh échoue
            await logout(); // Déconnecter complètement
            return;
          }
          // Si refresh réussi, le token et expiryDate sont mis à jour dans attemptRefreshToken
        }
      } else { // Token non décodable ou sans date d'expiration
        await logout(); return;
      }

      _updateAuthState(AuthState.authenticated);
      _autoLogoutTimer(); // Programmer la déconnexion ou le rafraîchissement
      if (kDebugMode) print("[AuthProvider] Auto-login successful for: ${_currentUser?.email}");

    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Error during auto-login: $e");
      await _clearAuthData();
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  Map<String, dynamic>? _decodeToken(String token) {
    try {
      return Jwt.parseJwt(token);
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Failed to decode token: $e");
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    _updateAuthState(AuthState.authenticating, error: null);
    try {
      final responseData = await _apiService.loginUser(email, password);
      if (responseData != null && responseData['user'] != null && responseData['token'] != null) {
        _currentUser = User.fromJson(responseData['user'] as Map<String, dynamic>);
        _token = responseData['token'] as String?;
        _refreshToken = responseData['refreshToken'] as String?; // Supposant que l'API retourne un refresh token

        Map<String, dynamic>? decodedToken = _decodeToken(_token!);
        if (decodedToken != null && decodedToken.containsKey('exp')) {
          _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
        } else {
          _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1)); // fallback
        }

        await _persistAuthData();
        _updateAuthState(AuthState.authenticated);
        _autoLogoutTimer();
        if (kDebugMode) print("[AuthProvider] Login successful for: ${currentUser?.email}");
        return true;
      } else {
        _updateAuthState(AuthState.unauthenticated, error: responseData?['message'] ?? 'Réponse invalide.');
        return false;
      }
    } catch (e) {
      _updateAuthState(AuthState.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    // ... Logique similaire à login, en supposant que signup retourne aussi user, token, refreshToken
    // Pour la simplicité, je ne le réécris pas entièrement ici.
    // Adaptez en fonction de la réponse de votre API de signup.
    _updateAuthState(AuthState.authenticating, error: null);
    try {
      // ... appel à _apiService.signupUser ...
      // ... traitement de la réponse, _persistAuthData, _updateAuthState, _autoLogoutTimer ...
      return true; // si succès
    } catch (e) {
      _updateAuthState(AuthState.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    if (kDebugMode) print("[AuthProvider] Logging out user: ${_currentUser?.email}");
    if (_token != null) {
      try {
        await _apiService.logoutUser(_token!); // Tenter d'invalider le token côté serveur
      } catch(e) {
        if (kDebugMode) print("[AuthProvider] API Logout error (ignoring): $e");
      }
    }

    _currentUser = null;
    _token = null;
    _refreshToken = null;
    _tokenExpiryDate = null;
    _authTimer?.cancel();
    _authTimer = null;

    await _clearAuthData();
    _updateAuthState(AuthState.unauthenticated, error: null);
  }

  Future<bool> attemptRefreshToken() async {
    if (_refreshToken == null) {
      if (kDebugMode) print("[AuthProvider] No refresh token available.");
      _updateAuthState(AuthState.unauthenticated);
      return false;
    }

    final previousState = _authState;
    _updateAuthState(AuthState.tokenRefreshing);

    try {
      final responseData = await _apiService.refreshToken(_refreshToken!);
      if (responseData != null && responseData['token'] != null) {
        _token = responseData['token'] as String?;
        // Optionnel: l'API de refresh peut aussi retourner un nouveau refresh token
        if (responseData.containsKey('refreshToken')) {
          _refreshToken = responseData['refreshToken'] as String?;
        }

        Map<String, dynamic>? decodedToken = _decodeToken(_token!);
        if (decodedToken != null && decodedToken.containsKey('exp')) {
          _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch(decodedToken['exp'] * 1000);
        } else {
          _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1)); // fallback
        }

        await _persistAuthData(); // Sauvegarder les nouveaux tokens
        _updateAuthState(AuthState.authenticated);
        _autoLogoutTimer();
        if (kDebugMode) print("[AuthProvider] Token refreshed successfully.");
        return true;
      } else {
        if (kDebugMode) print("[AuthProvider] Refresh token failed: Invalid response from server.");
        await logout(); // Si le refresh échoue, déconnexion complète
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Refresh token error: $e");
      await logout(); // Si le refresh échoue, déconnexion complète
      return false;
    }
  }


  Future<void> _persistAuthData() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, json.encode(_currentUser!.toJson()));

    if (_token != null) await _secureStorage.write(key: _tokenKey, value: _token);
    else await _secureStorage.delete(key: _tokenKey);

    if (_refreshToken != null) await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);
    else await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  void _autoLogoutTimer() {
    _authTimer?.cancel();
    if (_tokenExpiryDate == null) return;

    final timeToExpiry = _tokenExpiryDate!.difference(DateTime.now());
    if (timeToExpiry.isNegative) {
      attemptRefreshToken().then((refreshed) {
        if(!refreshed) logout();
      });
    } else {
      // Planifier un refresh un peu avant l'expiration, ou un logout
      // Pour cet exemple, on planifie un check à l'expiration.
      // Une logique plus fine pourrait rafraichir X minutes avant.
      _authTimer = Timer(timeToExpiry, () {
        attemptRefreshToken().then((refreshed) {
          if(!refreshed) logout();
        });
      });
    }
  }

  void _updateAuthState(AuthState newState, {String? error}) {
    if (error != null || newState != AuthState.authenticating && newState != AuthState.tokenRefreshing) {
      _errorMessage = error;
    }
    if (_authState != newState) {
      _authState = newState;
      notifyListeners();
    } else if (error != null && _errorMessage != error) {
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}