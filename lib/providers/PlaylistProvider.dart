// lib/providers/playlist_provider.dart
import 'package:flutter/material.dart';
import '../models/playlist.dart'; // Assurez-vous que le modèle existe
import '../services/ApiService.dart'; // Correction: APIservice -> ApiService
import 'auth_provider.dart';

class PlaylistProvider with ChangeNotifier {
  final ApiService _apiService;
  final AuthProvider _authProvider;

  List<Playlist> _userPlaylists = [];
  bool _isLoading = false;
  String? _errorMessage;

  PlaylistProvider(this._apiService, this._authProvider) {
    // Écouter les changements pour charger/vider les playlists
    _authProvider.addListener(_handleAuthChange);
    // Charger immédiatement si déjà connecté au démarrage
    if (_authProvider.isAuthenticated) {
      fetchMyPlaylists();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_handleAuthChange); // Ne pas oublier !
    super.dispose();
  }

  // Gérer connexion/déconnexion
  void _handleAuthChange() {
    if (_authProvider.isAuthenticated) {
      fetchMyPlaylists();
    } else {
      _userPlaylists = [];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  // Getters
  List<Playlist> get userPlaylists => _userPlaylists;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fetch des playlists de l'utilisateur
  Future<void> fetchMyPlaylists() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String? token;
    try {
      // Utiliser getToken() pour obtenir le token de manière asynchrone
      token = await _authProvider.getToken();
      if (token == null) {
        throw Exception("Utilisateur non authentifié"); // Ou gérer silencieusement
      }
      // Appeler l'API avec le token obtenu
      _userPlaylists = await _apiService.fetchMyPlaylists(token);
      _errorMessage = null; // Succès
    } catch (e) {
      print("[PlaylistProvider] Error fetching playlists: $e");
      _errorMessage = "Impossible de charger vos playlists : ${e.toString()}";
      _userPlaylists = []; // Vider en cas d'erreur
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// --- Autres méthodes à implémenter ---
// Future<bool> createPlaylist(String name, {String? description}) async {
//   String? token = await _authProvider.getToken();
//   if (token == null) return false;
//   try {
//      await _apiService.createPlaylist(name, description, authToken: token);
//      fetchMyPlaylists(); // Recharger la liste après création
//      return true;
//   } catch (e) {
//      _errorMessage = "Erreur création playlist: $e";
//      notifyListeners();
//      return false;
//   }
// }
// etc. pour addSongToPlaylist, deletePlaylist...
}