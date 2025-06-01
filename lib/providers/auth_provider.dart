// lib/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http; // Pour les requêtes HTTP, notamment MultipartRequest

import '../models/user.dart';
import '../services/ApiService.dart'; // Suppose que cela contient les méthodes d'API comme loginUser, etc.
import '../config/api_config.dart';   // Pour API_BASE_URL

enum AuthState {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
  tokenRefreshing,
  profileUpdating // Nouvel état pour la mise à jour du profil
}

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  User? _currentUser;
  String? _token;
  String? _refreshToken;
  DateTime? _tokenExpiryDate;
  AuthState _authState = AuthState.uninitialized;
  String? _errorMessage;
  Timer? _authTimer;

  // Clés pour le stockage
  final _secureStorage = const FlutterSecureStorage();
  static const _tokenKey = 'authToken_v2';
  static const _refreshTokenKey = 'refreshToken_v2';
  static const _userDataKey = 'userData_v2';

  AuthProvider(this._apiService) {
    _tryAutoLogin();
  }

  // --- Getters ---
  User? get currentUser => _currentUser;
  String? get token => _token;
  AuthState get authState => _authState;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  String? get error => _errorMessage;
  // Pour que EditProfileScreen sache si le profil est en cours de mise à jour
  bool get isUpdatingProfile => _authState == AuthState.profileUpdating;


  // --- Logique d'authentification et de session ---

  Future<String?> getValidToken() async {
    if (_token == null) {
      if (kDebugMode) print("[AuthProvider] getValidToken: No token available.");
      return null;
    }
    // Vérifier si le token est sur le point d'expirer (par exemple, dans les 30 prochaines secondes)
    if (_tokenExpiryDate != null && _tokenExpiryDate!.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      if (kDebugMode) print("[AuthProvider] getValidToken: Token expired or about to expire. Attempting refresh.");
      bool refreshed = await attemptRefreshToken();
      return refreshed ? _token : null;
    }
    return _token;
  }

  Future<void> _tryAutoLogin() async {
    if (kDebugMode) print("[AuthProvider] Attempting auto-login...");
    // Ne pas changer l'état ici pour éviter des rebuilds inutiles si déjà uninitialized
    // _updateAuthState(AuthState.uninitialized);

    final prefs = await SharedPreferences.getInstance();
    final storedToken = await _secureStorage.read(key: _tokenKey);
    final storedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final storedUserDataString = prefs.getString(_userDataKey);

    if (storedToken == null || storedUserDataString == null) {
      if (kDebugMode) print("[AuthProvider] Auto-login: No token or user data in storage.");
      _updateAuthState(AuthState.unauthenticated);
      return;
    }

    try {
      _token = storedToken;
      _refreshToken = storedRefreshToken;

      final dynamic decodedUserDataRaw = json.decode(storedUserDataString); // Peut lever une FormatException
      if (decodedUserDataRaw is Map<String, dynamic>) {
        _currentUser = User.fromJson(decodedUserDataRaw);
      } else {
        if (kDebugMode) print("[AuthProvider] Auto-login: Invalid stored user data format.");
        await logout(); // Nettoyer et déconnecter
        return;
      }

      Map<String, dynamic>? decodedToken = _decodeToken(_token!); // _token est non-null ici
      if (decodedToken != null && decodedToken['exp'] is int) {
        _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch((decodedToken['exp'] as int) * 1000);
        if (kDebugMode) print("[AuthProvider] Auto-login: Token expiry: $_tokenExpiryDate");

        if (_tokenExpiryDate!.isBefore(DateTime.now())) {
          if(kDebugMode) print("[AuthProvider] Auto-login: Token expired, attempting refresh.");
          if (!await attemptRefreshToken()) {
            await logout(); // Déconnecter complètement si le refresh échoue
            return;
          }
          // Si refresh réussi, le token et expiryDate sont mis à jour dans attemptRefreshToken
        }
      } else {
        if (kDebugMode) print("[AuthProvider] Auto-login: Invalid token (cannot decode, no 'exp' field, or 'exp' is not int).");
        await logout(); return;
      }

      _updateAuthState(AuthState.authenticated);
      _autoLogoutTimer();
      if (kDebugMode) print("[AuthProvider] Auto-login successful for: ${_currentUser?.username}");

    } on FormatException catch (e) {
      if (kDebugMode) print("[AuthProvider] Error during auto-login (FormatException on user data): $e");
      await _clearAuthData();
      _updateAuthState(AuthState.unauthenticated);
    }
    catch (e) { // Autres exceptions
      if (kDebugMode) print("[AuthProvider] Error during auto-login (general exception: $e).");
      await _clearAuthData();
      _updateAuthState(AuthState.unauthenticated);
    }
  }

  Map<String, dynamic>? _decodeToken(String tokenToDecode) {
    try {
      // Jwt.parseJwt peut lancer une exception si le token est malformé
      return Jwt.parseJwt(tokenToDecode);
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Failed to decode token '$tokenToDecode': $e");
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    _updateAuthState(AuthState.authenticating, error: null);
    try {
      final Map<String, dynamic>? responseData = await _apiService.loginUser(email, password);

      if (responseData != null &&
          responseData['user'] is Map<String, dynamic> &&
          responseData['token'] is String) {
        _processAuthResponse(responseData); // responseData est non-null et contient les clés attendues
        if (_authState == AuthState.authenticated) { // Vérifie si _processAuthResponse a réussi
          if (kDebugMode) print("[AuthProvider] Login successful for: ${_currentUser?.username}");
          return true;
        }
        // Si _authState n'est pas authenticated, _processAuthResponse a dû mettre une erreur
        return false;
      } else {
        String errorMsg = "Réponse de connexion invalide.";
        if (responseData != null && responseData['message'] is String) {
          errorMsg = responseData['message'] as String;
        } else if (responseData == null) {
          errorMsg = "Aucune réponse du serveur.";
        }
        _updateAuthState(AuthState.unauthenticated, error: errorMsg);
        return false;
      }
    } catch (e) {
      _updateAuthState(AuthState.unauthenticated, error: "Erreur de connexion: ${e.toString()}");
      return false;
    }
  }

  Future<bool> signup(String username, String email, String password) async {
    _updateAuthState(AuthState.authenticating, error: null);
    try {
      final Map<String, dynamic>? responseData = await _apiService.signupUser(username, email, password);
      if (responseData != null &&
          responseData['user'] is Map<String, dynamic> &&
          responseData['token'] is String) {
        _processAuthResponse(responseData);
        if (_authState == AuthState.authenticated) {
          if (kDebugMode) print("[AuthProvider] Signup successful for: ${_currentUser?.username}");
          return true;
        }
        return false;
      } else {
        String errorMsg = "Réponse d'inscription invalide.";
        if (responseData != null && responseData['message'] is String) {
          errorMsg = responseData['message'] as String;
        } else if (responseData == null) {
          errorMsg = "Aucune réponse du serveur.";
        }
        _updateAuthState(AuthState.unauthenticated, error: errorMsg);
        return false;
      }
    } catch (e) {
      _updateAuthState(AuthState.unauthenticated, error: "Erreur d'inscription: ${e.toString()}");
      return false;
    }
  }

  void _processAuthResponse(Map<String, dynamic> responseData) {
    // À ce stade, on assume que responseData n'est pas null et que 'user' et 'token' existent et ont les bons types
    final Map<String, dynamic> userDataMap = responseData['user'] as Map<String, dynamic>;
    try {
      _currentUser = User.fromJson(userDataMap);
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Error parsing user from JSON in _processAuthResponse: $e. Data: $userDataMap");
      _updateAuthState(AuthState.unauthenticated, error: "Format de données utilisateur JSON invalide.");
      return; // Important d'arrêter ici
    }

    _token = responseData['token'] as String; // Cast sûr
    _refreshToken = responseData['refreshToken'] as String?;

    Map<String, dynamic>? decodedToken = _decodeToken(_token!); // _token est non-null
    if (decodedToken != null && decodedToken['exp'] is int) {
      _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch((decodedToken['exp'] as int) * 1000);
    } else {
      _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1)); // Fallback
      if (kDebugMode) {
        if (decodedToken == null) print("[AuthProvider] _processAuthResponse: Token decoding failed.");
        else if (!decodedToken.containsKey('exp')) print("[AuthProvider] _processAuthResponse: Token decoded but no 'exp' field. Using fallback.");
        else if (decodedToken['exp'] is! int) print("[AuthProvider] _processAuthResponse: Token 'exp' field is not an int (${decodedToken['exp']?.runtimeType}). Using fallback.");
      }
    }
    if (kDebugMode) print("[AuthProvider] _processAuthResponse: Token expiry set to: $_tokenExpiryDate");

    _persistAuthData();
    _updateAuthState(AuthState.authenticated);
    _autoLogoutTimer();
  }

  Future<void> logout() async {
    if (kDebugMode) print("[AuthProvider] Logging out user: ${_currentUser?.username}");
    if (_token != null) {
      try {
        await _apiService.logoutUser(_token!);
      } catch(e) {
        if (kDebugMode) print("[AuthProvider] API Logout error (ignoring, client-side logout will proceed): $e");
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
      if (kDebugMode) print("[AuthProvider] AttemptRefreshToken: No refresh token available.");
      return false; // Important: ne pas changer l'état ici, l'appelant gérera le logout
    }
    // Éviter les appels multiples si un refresh est déjà en cours
    if (_authState == AuthState.tokenRefreshing) {
      if (kDebugMode) print("[AuthProvider] AttemptRefreshToken: Token refresh already in progress.");
      // Pourrait retourner un Future qui se complète quand le refresh en cours est terminé
      // Pour la simplicité, on retourne true en supposant que l'appelant attendra.
      // Ou false si on veut que l'appelant gère un échec immédiat.
      // Retourner false est plus sûr pour éviter une boucle.
      return false;
    }
    _updateAuthState(AuthState.tokenRefreshing);

    try {
      final Map<String, dynamic>? responseData = await _apiService.refreshToken(_refreshToken!);
      // Vérifier que responseData n'est pas null et contient un token valide
      if (responseData != null && responseData['token'] is String) {
        _token = responseData['token'] as String;
        if (responseData['refreshToken'] is String) { // L'API peut optionnellement retourner un nouveau refresh token
          _refreshToken = responseData['refreshToken'] as String;
        }

        Map<String, dynamic>? decodedToken = _decodeToken(_token!);
        if (decodedToken != null && decodedToken['exp'] is int) {
          _tokenExpiryDate = DateTime.fromMillisecondsSinceEpoch((decodedToken['exp'] as int) * 1000);
        } else {
          _tokenExpiryDate = DateTime.now().add(const Duration(hours: 1)); // Fallback
          if (kDebugMode) { /* ... logs pour fallback ... */ }
        }
        if (kDebugMode) print("[AuthProvider] Token refreshed. New expiry: $_tokenExpiryDate");
        await _persistAuthData();
        _updateAuthState(AuthState.authenticated); // Retour à l'état authentifié
        _autoLogoutTimer();
        return true;
      } else {
        if (kDebugMode) print("[AuthProvider] Refresh token failed: Invalid response or no token from server. Response: $responseData");
        await logout(); // Si le refresh échoue, déconnexion complète
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Refresh token API error: $e");
      await logout(); // Déconnexion complète en cas d'erreur
      return false;
    }
  }

  Future<void> _persistAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser != null) {
      await prefs.setString(_userDataKey, json.encode(_currentUser!.toJson()));
    } else {
      await prefs.remove(_userDataKey);
    }
    if (_token != null) await _secureStorage.write(key: _tokenKey, value: _token);
    else await _secureStorage.delete(key: _tokenKey);
    if (_refreshToken != null) await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken);
    else await _secureStorage.delete(key: _refreshTokenKey);
    if (kDebugMode) print("[AuthProvider] Auth data persisted/updated.");
  }

  Future<void> _clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    if (kDebugMode) print("[AuthProvider] Auth data cleared from storage.");
  }

  void _autoLogoutTimer() {
    _authTimer?.cancel(); // Annuler tout timer existant
    if (_tokenExpiryDate == null || _authState != AuthState.authenticated) {
      if (kDebugMode && _authState == AuthState.authenticated) print("[AuthProvider] AutoLogoutTimer: No expiry date for token, timer not set.");
      return;
    }

    final timeToExpiry = _tokenExpiryDate!.difference(DateTime.now());
    if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Time to current token expiry: $timeToExpiry");

    if (timeToExpiry.isNegative) {
      if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Token already expired by ${timeToExpiry.abs()}, attempting refresh immediately.");
      // Utiliser un microtask pour éviter d'appeler attemptRefreshToken (qui peut notifier) pendant un build/notify
      Future.microtask(() async {
        if (_authState == AuthState.authenticated) { // Double check state
          bool refreshed = await attemptRefreshToken();
          if (!refreshed) {
            if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Refresh failed after immediate check, logging out.");
            logout();
          }
        }
      });
    } else {
      Duration refreshLeadTime = const Duration(minutes: 5);
      Duration timerDuration = timeToExpiry - refreshLeadTime;

      // Si le token expire dans moins de (leadTime + une petite marge), on tente de rafraîchir plus tôt
      if (timerDuration.isNegative || timeToExpiry < (refreshLeadTime + const Duration(minutes: 1))) {
        timerDuration = timeToExpiry > const Duration(seconds: 10) ? timeToExpiry - const Duration(seconds: 10) : Duration.zero;
      }
      if(timerDuration.isNegative) timerDuration = Duration.zero; // Assurer non négatif

      if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Scheduling token refresh check in $timerDuration");
      _authTimer = Timer(timerDuration, () {
        if (_authState == AuthState.authenticated) { // Vérifier si toujours authentifié avant de tenter
          if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Timer expired, attempting token refresh.");
          attemptRefreshToken().then((refreshed) {
            if (!refreshed) {
              if (kDebugMode) print("[AuthProvider] AutoLogoutTimer: Refresh failed via timer, logging out.");
              logout();
            }
          });
        }
      });
    }
  }

  void _updateAuthState(AuthState newState, {String? error}) {
    bool shouldNotify = false;
    if (_authState != newState) {
      _authState = newState;
      shouldNotify = true;
    }

    // Gérer la mise à jour de _errorMessage
    if (error != null) { // Une nouvelle erreur est fournie
      if (_errorMessage != error) {
        _errorMessage = error;
        shouldNotify = true;
      }
    } else { // Aucune nouvelle erreur fournie
      // Effacer l'erreur existante seulement si on ne passe pas à un état de chargement
      // et que _errorMessage n'est pas déjà null.
      if (_errorMessage != null &&
          newState != AuthState.authenticating &&
          newState != AuthState.tokenRefreshing &&
          newState != AuthState.profileUpdating) {
        _errorMessage = null;
        shouldNotify = true;
      }
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // --- Logique de mise à jour du profil utilisateur ---

  Future<bool> updateUserProfileOnServer({
    required String userId,
    String? newUsername,
    File? avatarFile,
  }) async {
    final String? currentToken = await getValidToken(); // Essaye de rafraîchir si nécessaire
    if (currentToken == null) {
      // getValidToken ou attemptRefreshToken aurait déjà appelé logout si le refresh a échoué
      // et mis à jour l'état. On s'assure juste que _errorMessage est pertinent.
      _updateAuthState(_authState, error: _errorMessage ?? "Session expirée. Veuillez vous reconnecter.");
      return false;
    }

    _updateAuthState(AuthState.profileUpdating, error: null);

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$API_BASE_URL/api/users/profile/update'),
      );
      request.headers['Authorization'] = 'Bearer $currentToken';

      if (newUsername != null && newUsername.isNotEmpty) {
        request.fields['username'] = newUsername;
      }
      if (avatarFile != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarFile.path));
      }

      if (kDebugMode) {
        print("[AuthProvider] Sending profile update request to: ${request.url}");
        print("[AuthProvider] Headers: ${request.headers}");
        print("[AuthProvider] Fields: ${request.fields.map((key, value) => MapEntry(key, value.length > 100 ? '${value.substring(0,100)}...' : value))}"); // Tronquer les champs longs pour les logs
        if (avatarFile != null) print("[AuthProvider] Avatar file being sent: ${avatarFile.path}");
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print("[AuthProvider] Profile update response status: ${response.statusCode}");
        print("[AuthProvider] Profile update response body: ${response.body.length > 500 ? response.body.substring(0,500)+'...' : response.body}"); // Tronquer les réponses longues
      }

      if (response.statusCode == 200) {
        final dynamic responseDataRaw = json.decode(response.body);
        if (responseDataRaw != null && responseDataRaw is Map<String, dynamic>) {
          final Map<String, dynamic> responseDataValidated = responseDataRaw;
          // L'API doit retourner l'objet UserDto mis à jour
          _currentUser = User.fromJson(responseDataValidated);
          await _persistAuthData(); // Sauvegarder les nouvelles données utilisateur
          _updateAuthState(AuthState.authenticated); // Retour à l'état authentifié
          return true;
        } else {
          _updateAuthState(AuthState.authenticated, error: "Réponse invalide du serveur après mise à jour (format).");
          return false;
        }
      } else {
        String serverErrorMsg = "Erreur du serveur (${response.statusCode}).";
        try {
          final dynamic errorDataRaw = json.decode(response.body);
          if (errorDataRaw != null && errorDataRaw is Map<String, dynamic>) {
            final Map<String, dynamic> errorData = errorDataRaw;
            if (errorData['message'] != null && errorData['message'] is String) {
              serverErrorMsg = errorData['message'] as String;
            }
          }
        } catch (_) { /* Ignorer si le corps n'est pas du JSON ou ne contient pas 'message' */ }
        _updateAuthState(AuthState.authenticated, error: serverErrorMsg);
        return false;
      }
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] Exception during profile update: $e");
      _updateAuthState(AuthState.authenticated, error: "Erreur de communication: ${e.toString()}");
      return false;
    }
  }

  Future<void> fetchUserProfile() async {
    final String? currentToken = await getValidToken();
    if (currentToken == null) {
      if (kDebugMode) print("[AuthProvider] fetchUserProfile: No valid token. User might have been logged out.");
      return;
    }

    // Pourrait avoir son propre état de chargement si c'est une opération fréquente et potentiellement longue
    // ex: _isFetchingProfile = true; notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/api/users/profile'),
        headers: {'Authorization': 'Bearer $currentToken'},
      );

      if (response.statusCode == 200) {
        final dynamic responseDataRaw = json.decode(response.body);
        if (responseDataRaw != null && responseDataRaw is Map<String, dynamic>) {
          final Map<String, dynamic> responseDataValidated = responseDataRaw;
          _currentUser = User.fromJson(responseDataValidated);
          await _persistAuthData();
          notifyListeners(); // Important pour mettre à jour l'UI
          if (kDebugMode) print("[AuthProvider] User profile fetched/refreshed: ${_currentUser?.username}");
        } else {
          if (kDebugMode) print("[AuthProvider] fetchUserProfile: Invalid data format from server.");
          // Ne pas nécessairement mettre une erreur globale ici, pourrait être une réponse inattendue
        }
      } else {
        if (kDebugMode) print("[AuthProvider] fetchUserProfile: Failed to fetch profile - ${response.statusCode}, Body: ${response.body}");
        // Gérer l'erreur, par exemple, si c'est 401, appeler logout()
        if (response.statusCode == 401 || response.statusCode == 403) {
          await logout();
        } else {
          // Pour d'autres erreurs, on peut juste logguer ou définir une erreur temporaire
        }
      }
    } catch (e) {
      if (kDebugMode) print("[AuthProvider] fetchUserProfile: Exception - $e");
      // Une erreur réseau pourrait justifier une erreur affichée à l'utilisateur
      // _updateAuthState(_authState, error: "Impossible de récupérer le profil.");
    } finally {
      // if (_isFetchingProfile) { _isFetchingProfile = false; notifyListeners(); }
    }
  }
}