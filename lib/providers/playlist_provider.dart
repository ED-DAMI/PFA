// lib/providers/playlist_provider.dart
import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../models/song.dart'; // Importez Song si votre modèle Playlist contient List<Song>
import '../services/ApiService.dart';
import 'auth_provider.dart';

class PlaylistProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  PlaylistProvider(this._apiService, this._authProvider);

  List<Playlist> get playlists => List.unmodifiable(_playlists); // Retourne une copie non modifiable
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  bool get isLoadingList => _isLoading;

  bool get isModifyingItem => false;

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (_authProvider.currentUser?.id != newAuthProvider.currentUser?.id) {
      _authProvider = newAuthProvider;
      _playlists = [];
      _isInitialized = false;
      _error = null;
      if (_authProvider.isAuthenticated && _authProvider.token != null) {
        fetchPlaylists(); // fetchPlaylists utilisera _authProvider.token
      } else {
        notifyListeners();
      }
    } else {
      // Même si l'ID utilisateur est le même, le token pourrait avoir été rafraîchi.
      // Mettre à jour _authProvider est une bonne pratique.
      _authProvider = newAuthProvider;
    }
  }

  Future<void> fetchPlaylists({bool forceRefresh = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _playlists = [];
      _isInitialized = true;
      notifyListeners();
      return;
    }

    if (_isLoading || (_isInitialized && !forceRefresh)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _playlists = await _apiService.fetchUserPlaylists(authToken: _authProvider.token!);
      _isInitialized = true;
      _error = null; // Effacer l'erreur si succès
      if (kDebugMode) {
        print("PlaylistProvider: Fetched ${_playlists.length} playlists.");
      }
    } catch (e) {
      _error = "Erreur chargement playlists: ${e.toString()}";
      _isInitialized = false;
      if (kDebugMode) {
        print("PlaylistProvider: Error fetching playlists: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // MODIFIÉ: Utilise des paramètres nommés et le token interne
  Future<bool> createPlaylist({required String name, String? description}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Authentification requise pour créer une playlist.";
      notifyListeners();
      return false;
    }

    _isLoading = true; // Peut-être un indicateur de chargement spécifique pour la création
    _error = null;
    notifyListeners();

    try {
      final newPlaylist = await _apiService.createPlaylist(
          name: name,
          description: description, // description peut être null
          authToken: _authProvider.token!
      );
      if (newPlaylist != null) {
        _playlists.insert(0, newPlaylist); // Ajouter au début pour un feedback immédiat
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = "La création de la playlist a échoué (réponse nulle de l'API).";
      _isLoading = false;
      notifyListeners();
      return false;
    } catch(e) {
      _error = "Erreur lors de la création de la playlist: ${e.toString()}";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Authentification requise pour ajouter une chanson.";
      notifyListeners();
      return false;
    }
    try {
      bool success = await _apiService.addSongToPlaylist(playlistId, songId, authToken: _authProvider.token!);
      if (success) {
        final index = _playlists.indexWhere((p) => p.id == playlistId);
        if (index != -1) {
          // Pour une mise à jour optimiste, il faut s'assurer que songIds est mutable
          // ou recréer l'objet Playlist avec la nouvelle liste de songIds.
          // Supposons que Playlist a une méthode copyWith ou que songIds est une List<String> mutable.
          final playlistToUpdate = _playlists[index];
          if (!playlistToUpdate.songIds.contains(songId)) {
            // Créer une nouvelle liste pour s'assurer de la mutabilité et notifier le changement
            final newSongIds = List<String>.from(playlistToUpdate.songIds)..add(songId);
            _playlists[index] = playlistToUpdate.copyWith(songIds: newSongIds); // copyWith est crucial
            notifyListeners();
          }
        }
        return true;
      }
      _error = "Échec de l'ajout de la chanson à la playlist.";
      notifyListeners();
      return false;
    } catch (e) {
      _error = "Erreur lors de l'ajout de la chanson: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // IMPLÉMENTÉ: Récupère une playlist par son ID depuis la liste locale
  Playlist? getPlaylistById(String playlistId) {
    try {
      return _playlists.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      // Gère le cas où la playlist n'est pas trouvée (firstWhere lève une exception si pas d'élément)
      if (kDebugMode) {
        print("PlaylistProvider: Playlist avec ID $playlistId non trouvée dans la liste locale.");
      }
      return null;
    }
  }

  removeSongFromPlaylist(String playlistId, String id) {

  }
}