// lib/providers/playlist_provider.dart
import 'package:flutter/foundation.dart';
import '../models/playlist.dart'; // Assurez-vous que Playlist a une méthode copyWith
import '../models/song.dart';
import '../widgets/services/ApiService.dart';
import 'auth_provider.dart';

class PlaylistProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  List<Playlist> _playlists = [];
  bool _isLoadingList = false; // Pour le chargement de la liste principale
  String? _error;
  bool _isInitialized = false;

  // Pour gérer l'état de modification d'un item spécifique (ajout/suppression de chanson)
  bool _isModifyingItem = false;
  String? _modifyingPlaylistId; // L'ID de la playlist en cours de modification

  PlaylistProvider(this._apiService, AuthProvider initialAuthProvider)
      : _authProvider = initialAuthProvider {
    // L'initialisation est déclenchée par updateAuthProvider ou manuellement
  }

  // --- Getters ---
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  bool get isLoadingList => _isLoadingList; // Pour le chargement initial/refresh de la liste
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  bool get isModifyingItem => _isModifyingItem;
  String? get modifyingPlaylistId => _modifyingPlaylistId; // Pour savoir QUELLE playlist est modifiée

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (kDebugMode) {
      print("PlaylistProvider: updateAuthProvider. Old user: ${_authProvider.currentUser?.id}, New user: ${newAuthProvider.currentUser?.id}");
    }
    // Réinitialiser si l'utilisateur a changé ou si le token a changé
    // (un changement de token sans changement d'utilisateur est rare mais possible, ex: refresh forcé ailleurs)
    bool userChanged = _authProvider.currentUser?.id != newAuthProvider.currentUser?.id;
    bool tokenChanged = _authProvider.token != newAuthProvider.token;

    _authProvider = newAuthProvider; // Toujours mettre à jour la référence

    if (userChanged || (tokenChanged && newAuthProvider.isAuthenticated)) {
      if (kDebugMode) {
        print("PlaylistProvider: Auth context changed. Resetting playlists.");
      }
      _playlists = [];
      _isInitialized = false;
      _error = null;
      _isLoadingList = false; // Réinitialiser l'état de chargement
      // Si le nouvel AuthProvider est authentifié, on lance le fetch.
      // Sinon, l'état reste vide et non initialisé.
      if (_authProvider.isAuthenticated && _authProvider.token != null) {
        fetchPlaylists();
      } else {
        notifyListeners(); // Notifier que les playlists sont vides
      }
    }
  }

  Future<void> fetchPlaylists({bool forceRefresh = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      if (kDebugMode) print("PlaylistProvider: Not authenticated, cannot fetch playlists.");
      _playlists = [];
      _isInitialized = true; // Initialisé, mais avec une liste vide car non authentifié
      _isLoadingList = false;
      _error = "Veuillez vous connecter pour voir vos playlists.";
      notifyListeners();
      return;
    }

    if (_isLoadingList || (_isInitialized && !forceRefresh)) {
      if (kDebugMode) print("PlaylistProvider: Fetch playlists skipped (already loading or initialized and no forceRefresh).");
      return;
    }

    _isLoadingList = true;
    _error = null;
    if (!forceRefresh) { // Si ce n'est pas un refresh, on peut indiquer un état de "première initialisation"
      _isInitialized = false;
    }
    notifyListeners();

    try {
      if (kDebugMode) print("PlaylistProvider: Fetching user playlists...");
      _playlists = await _apiService.fetchUserPlaylists(authToken: _authProvider.token!);
      _isInitialized = true;
      _error = null;
      if (kDebugMode) print("PlaylistProvider: Fetched ${_playlists.length} playlists.");
    } catch (e) {
      _error = "Erreur lors du chargement de vos playlists: ${e.toString()}";
      if (!forceRefresh && !_isInitialized) { // Si c'était la première tentative et qu'elle a échoué
        _isInitialized = false; // Marquer l'échec de l'initialisation
      }
      // Si c'est un refresh qui échoue, _isInitialized reste true (on a les anciennes données).
      if (kDebugMode) print("PlaylistProvider: Error fetching playlists: $_error");
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  Future<bool> createPlaylist({required String name, String? description}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Authentification requise pour créer une playlist.";
      notifyListeners();
      return false;
    }

    // Utiliser _isModifyingItem pour une création de playlist, même si ce n'est pas un "item" existant
    // Ou un booléen dédié comme _isCreatingPlaylist si on veut plus de granularité
    _isModifyingItem = true;
    _modifyingPlaylistId = null; // Pas d'ID spécifique pour une création
    _error = null;
    notifyListeners();

    try {
      final newPlaylist = await _apiService.createPlaylist(
          name: name,
          description: description,
          authToken: _authProvider.token!);
      if (newPlaylist != null) {
        _playlists.insert(0, newPlaylist);
        _error = null;
        return true;
      }
      _error = "La création de la playlist a échoué."; // Message plus simple
      return false;
    } catch (e) {
      _error = "Erreur: ${e.toString()}";
      return false;
    } finally {
      _isModifyingItem = false;
      _modifyingPlaylistId = null;
      notifyListeners();
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Authentification requise.";
      notifyListeners();
      return false;
    }

    _isModifyingItem = true;
    _modifyingPlaylistId = playlistId;
    _error = null; // Effacer l'erreur précédente pour cette opération
    notifyListeners();

    // Sauvegarder l'état original de la playlist pour un rollback en cas d'erreur
    Playlist? originalPlaylist;
    int playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      originalPlaylist = _playlists[playlistIndex];
    }

    try {
      // Mise à jour optimiste (si la playlist est trouvée localement)
      if (playlistIndex != -1) {
        final playlistToUpdate = _playlists[playlistIndex];
        if (!playlistToUpdate.songIds.contains(songId)) {
          final newSongIds = List<String>.from(playlistToUpdate.songIds)..add(songId);
          // Remplacer l'élément dans la liste pour déclencher la mise à jour de l'UI
          _playlists = List.from(_playlists); // Créer une nouvelle instance de la liste
          _playlists[playlistIndex] = playlistToUpdate.copyWith(songIds: newSongIds);
          notifyListeners(); // Notifier l'UI de la mise à jour optimiste
        }
      }

      await _apiService.addSongToPlaylist(playlistId, songId, authToken: _authProvider.token!);
      // Si l'API réussit, la mise à jour optimiste est correcte.
      // Si la playlist n'était pas dans la liste locale (improbable mais possible),
      // il faudrait la rafraîchir pour voir la modification.
      // Pour simplifier, on suppose que la mise à jour optimiste suffit si la playlist est locale.
      return true;
    } catch (e) {
      _error = "Erreur ajout chanson: ${e.toString()}";
      // Rollback de la mise à jour optimiste
      if (originalPlaylist != null && playlistIndex != -1) {
        _playlists = List.from(_playlists);
        _playlists[playlistIndex] = originalPlaylist;
      }
      return false;
    } finally {
      _isModifyingItem = false;
      _modifyingPlaylistId = null;
      notifyListeners();
    }
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Authentification requise.";
      notifyListeners();
      return false;
    }

    _isModifyingItem = true;
    _modifyingPlaylistId = playlistId;
    _error = null;
    notifyListeners();

    Playlist? originalPlaylist;
    int playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      originalPlaylist = _playlists[playlistIndex];
    }

    try {
      // Mise à jour optimiste
      if (playlistIndex != -1) {
        final playlistToUpdate = _playlists[playlistIndex];
        if (playlistToUpdate.songIds.contains(songId)) {
          final newSongIds = List<String>.from(playlistToUpdate.songIds)..remove(songId);
          _playlists = List.from(_playlists);
          _playlists[playlistIndex] = playlistToUpdate.copyWith(songIds: newSongIds);
          notifyListeners();
        }
      }

      await _apiService.removeSongFromPlaylist(playlistId, songId, authToken: _authProvider.token!);
      return true;
    } catch (e) {
      _error = "Erreur retrait chanson: ${e.toString()}";
      if (originalPlaylist != null && playlistIndex != -1) {
        _playlists = List.from(_playlists);
        _playlists[playlistIndex] = originalPlaylist;
      }
      return false;
    } finally {
      _isModifyingItem = false;
      _modifyingPlaylistId = null;
      notifyListeners();
    }
  }

  Playlist? getPlaylistById(String playlistId) {
    try {
      return _playlists.firstWhere((playlist) => playlist.id == playlistId);
    } catch (e) {
      if (kDebugMode) print("PlaylistProvider: Playlist ID $playlistId not found locally.");
      // Optionnel: Déclencher un fetch de cette playlist spécifique si elle n'est pas trouvée
      // et que ce comportement est désiré. Pour l'instant, retourne null.
      // _fetchPlaylistDetailsById(playlistId); // Méthode à créer
      return null;
    }
  }

  // Optionnel: Si vous voulez pouvoir rafraîchir une seule playlist
  // Future<void> _fetchPlaylistDetailsById(String playlistId) async {
  //   // Logique pour appeler _apiService.fetchPlaylistById(playlistId, authToken: _authProvider.token!)
  //   // Et mettre à jour l'élément dans _playlists
  // }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print("PlaylistProvider: Disposing...");
    super.dispose();
  }
}