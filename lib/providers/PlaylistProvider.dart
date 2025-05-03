// lib/providers/playlist_provider.dart
import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../services/APIservice.dart';
import 'auth_provider.dart'; // Pour obtenir le token

class PlaylistProvider with ChangeNotifier {
  final ApiService _apiService;
  final AuthProvider _authProvider; // Pour accéder au token

  List<Playlist> _userPlaylists = [];
  bool _isLoading = false;
  String? _errorMessage;

  PlaylistProvider(this._apiService, this._authProvider) {
    // Charger les playlists initialement si l'utilisateur est déjà connecté
    if (_authProvider.isAuthenticated) {
      fetchMyPlaylists();
    }
    // Écouter les changements d'authentification pour recharger
    _authProvider.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthChange); // Important !
    super.dispose();
  }

  void _handleAuthChange() {
    if (_authProvider.isAuthenticated) {
      fetchMyPlaylists(); // Recharger quand l'utilisateur se connecte
    } else {
      _userPlaylists = []; // Vider quand l'utilisateur se déconnecte
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }


  List<Playlist> get userPlaylists => _userPlaylists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyPlaylists() async {
    if (_authProvider.token == null) {
      _errorMessage = "Utilisateur non connecté";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _userPlaylists = await _apiService.fetchMyPlaylists(_authProvider.token!);
    } catch (e) {
      _errorMessage = "Impossible de charger les playlists: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Ajouter ici les méthodes pour créer, supprimer, renommer des playlists...
// Future<bool> createPlaylist(String name) async { ... }
}