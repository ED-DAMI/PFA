import 'package:flutter/foundation.dart';

import '../models/song.dart';
import '../models/tag.dart';

import '../services/ApiService.dart';
import 'auth_provider.dart';

class SongProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  List<Tag> _tags = [];
  Tag? _selectedTag;
  String _searchQuery = '';

  bool _isInitialized = false;
  bool _isLoadingSongs = false;
  bool _isLoadingTags = false;
  bool _isLoadingSongDetails = false;
  String? _error;

  SongProvider(this._apiService, AuthProvider initialAuthProvider)
      : _authProvider = initialAuthProvider {
    if (kDebugMode) {
      print("SongProvider: Instance created. Initial Auth state: ${_authProvider.isAuthenticated}, Token available: ${_authProvider.token != null}");
    }
    // L'appel initial à initialize() est maintenant géré par la logique de updateAuthProvider
    // qui est appelée par ChangeNotifierProxyProvider juste après la création,
    // ou par un appel explicite si nécessaire dans le `create` du ProxyProvider (moins courant).
    // updateAuthProvider sera appelé par le ProxyProvider après la création, qui déclenchera initialize si nécessaire.
  }

  // --- Getters ---
  List<Song> get songsToDisplay => _filteredSongs; // Utilisé par l'UI
  List<Tag> get tags => _tags;
  Tag? get selectedTag => _selectedTag;
  String get searchQuery => _searchQuery;
  bool get isLoadingSongs => _isLoadingSongs;
  bool get isLoadingTags => _isLoadingTags;
  bool get isLoadingSongDetails => _isLoadingSongDetails;
  bool get isLoading => _isLoadingSongs || _isLoadingTags || _isLoadingSongDetails;
  String? get error => _error;
  bool get isInitialized => _isInitialized;


  // Méthode d'initialisation principale.
  Future<void> initialize() async {
    if (kDebugMode) {
      print("SongProvider: initialize() called. Current auth state: ${_authProvider.isAuthenticated}, Token available: ${_authProvider.token != null}");
    }

    if (_isInitialized) { // Si déjà initialisé avec le contexte actuel, ne rien faire.
      // updateAuthProvider se charge de setter _isInitialized à false si l'auth change.
      if (kDebugMode) {
        print("SongProvider: Already initialized for current auth context. Skipping re-initialization.");
      }
      return;
    }

    final token = _authProvider.token;

    // Condition pour autoriser le fetch: soit authentifié, soit token disponible (pour API publique avec token d'app)
    // Adapter cette logique si des endpoints sont purement publics sans token.
    if (_authProvider.isAuthenticated || token != null /*pour endpoints avec token d'app même si non loggué*/) {
      _isLoadingSongs = true;
      _isLoadingTags = true;
      _error = null;
      notifyListeners();

      try {
        if (kDebugMode) {
          print("SongProvider: Fetching initial songs and tags with token: ${token != null ? "present" : "absent"}...");
        }
        final results = await Future.wait([
          _apiService.fetchSongs(authToken: token),
          _apiService.fetchTags(authToken: token),
        ]);

        _allSongs = results[0] as List<Song>;
        _tags = results[1] as List<Tag>;

        _applyFiltersAndSearch();
        _isInitialized = true;
        if (kDebugMode) {
          print("SongProvider: Initial data fetched. ${_allSongs.length} songs, ${_tags.length} tags.");
        }
      } catch (e) {
        if (kDebugMode) {
          print("SongProvider: Error during initial data fetch: $e");
        }
        _error = "Erreur de chargement des données : ${e.toString()}";
        _allSongs = [];
        _tags = [];
        _filteredSongs = [];
        _isInitialized = false; // Échec de l'initialisation
      } finally {
        _isLoadingSongs = false;
        _isLoadingTags = false;
        notifyListeners();
      }
    } else {
      if (kDebugMode) {
        print("SongProvider: User not authenticated or token not available for data fetching. Clearing data.");
      }
      _allSongs = [];
      _filteredSongs = [];
      _tags = [];
      _selectedTag = null;
      _searchQuery = '';
      // Message d'erreur plus précis en fonction de l'état de l'authentification
      _error = !_authProvider.isAuthenticated && token == null ? "Veuillez vous connecter pour voir les chansons." : "Problème de configuration ou d'authentification.";
      _isInitialized = false; // On considère que non initialisé si pas d'auth/token pour fetch
      _isLoadingSongs = false;
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  // Met à jour l'instance AuthProvider interne et réinitialise si l'auth a changé.
  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (kDebugMode) {
      print("SongProvider: updateAuthProvider called. New auth state: ${newAuthProvider.isAuthenticated}, New token: ${newAuthProvider.token != null}");
      print("SongProvider: Old auth state: ${_authProvider.isAuthenticated}, Old token: ${_authProvider.token != null}, Was initialized: $_isInitialized");
    }

    bool authContextChanged = (_authProvider.token != newAuthProvider.token) ||
        (_authProvider.isAuthenticated != newAuthProvider.isAuthenticated);

    _authProvider = newAuthProvider; // Toujours mettre à jour la référence

    if (authContextChanged || !_isInitialized) { // Si l'auth a changé OU si jamais initialisé
      if (kDebugMode) {
        print("SongProvider: Auth state changed or not initialized. Resetting and re-initializing SongProvider data.");
      }
      _isInitialized = false; // Marquer pour réinitialisation (ou première initialisation)
      initialize(); // Relancer l'initialisation avec le nouvel état d'auth
    } else if (kDebugMode) {
      print("SongProvider: Auth state effectively unchanged and already initialized. No re-initialization needed by updateAuthProvider.");
    }
  }


  // --- Logique de filtrage et de recherche ---
  void selectTag(Tag? tag) {
    if (kDebugMode) {
      print("SongProvider: Tag selected: ${tag?.name ?? 'None'}");
    }
    _selectedTag = tag;
    _applyFiltersAndSearch();
  }

  void searchSongs(String query) {
    final newQuery = query.trim().toLowerCase();
    if (kDebugMode) {
      print("SongProvider: Search query changed to: '$newQuery'");
    }
    if (_searchQuery != newQuery) {
      _searchQuery = newQuery;
      _applyFiltersAndSearch();
    }
  }

  void _applyFiltersAndSearch() {
    if (kDebugMode) {
      print("SongProvider: Applying filters. Query: '$_searchQuery', Tag: '${_selectedTag?.name}'. Songs available: ${_allSongs.length}");
    }
    List<Song> tempSongs = List.from(_allSongs);

    if (_selectedTag != null) {
      // Adaptez ceci à la structure de vos modèles Song et Tag.
      // Si Song.genre est un String qui doit correspondre à Tag.name :
      tempSongs = tempSongs.where((song) =>
      song.genre.toLowerCase() == _selectedTag!.name.toLowerCase()
      ).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempSongs = tempSongs.where((song) {
        final titleMatch = song.title.toLowerCase().contains(_searchQuery);
        final artistMatch = song.artist.toLowerCase().contains(_searchQuery);
        // Ajoutez d'autres champs si nécessaire (ex: album)
        // final albumMatch = song.album?.toLowerCase().contains(_searchQuery) ?? false;
        return titleMatch || artistMatch;
      }).toList();
    }

    _filteredSongs = tempSongs;
    if (kDebugMode) {
      print("SongProvider: Filtering complete. ${_filteredSongs.length} songs match.");
    }
    notifyListeners();
  }

  // --- Méthodes pour une chanson spécifique ---
  Future<Song?> getSongById(String songId) async {
    if (kDebugMode) {
      print("SongProvider: Getting song by ID: $songId");
    }
    // Tente de trouver la chanson dans le cache local en premier
    try {
      final localSong = _allSongs.firstWhere((s) => s.id == songId);
      if (kDebugMode) print("SongProvider: Song $songId found in local cache (_allSongs).");
      return localSong;
    } catch (e) {
      if (kDebugMode) print("SongProvider: Song $songId not in _allSongs. Will try API.");
    }

    // Si non trouvée localement, et si on veut fetch individuellement (sinon, dépendre du fetch global)
    _isLoadingSongDetails = true;
    _error = null; // Efface l'erreur précédente pour cette opération spécifique
    notifyListeners();

    try {
      final token = _authProvider.token;
      final song = await _apiService.fetchSongById(songId, authToken: token);
      if (song != null) {
        if (kDebugMode) print("SongProvider: Song $songId fetched from API successfully.");
        // Optionnel: Mettre à jour _allSongs. Attention à la gestion des doublons ou à la cohérence de la liste.
        // Une stratégie simple est de ne pas l'ajouter à _allSongs ici et de compter sur un re-fetch global.
      } else {
        if (kDebugMode) print("SongProvider: Song $songId not found via API.");
      }
      return song;
    } catch (e) {
      if (kDebugMode) {
        print("SongProvider: Error fetching song $songId by ID: $e");
      }
      _error = "Erreur lors du chargement des détails de la chanson."; // Erreur spécifique pour cette action
      return null;
    } finally {
      _isLoadingSongDetails = false;
      notifyListeners();
    }
  }

  // Méthode pour mettre à jour les compteurs d'une chanson (ex: après un commentaire ou une réaction)
  // Cette méthode devrait être appelée depuis l'extérieur (ex: InteractionProvider via un callback, ou depuis l'UI)
  // si une mise à jour en temps réel des listes est souhaitée sans re-fetch complet.
  void updateSongInteractionCounts(String songId, {int? newCommentCount, int? newReactionCount}) {
    final songIndex = _allSongs.indexWhere((s) => s.id == songId);
    if (songIndex != -1) {
      final originalSong = _allSongs[songIndex];
      bool changed = false;

      int updatedCommentCount = originalSong.commentCount;
      if (newCommentCount != null && newCommentCount != originalSong.commentCount) {
        updatedCommentCount = newCommentCount;
        changed = true;
      }

      int updatedReactionCount = originalSong.totalReactionCount;
      if (newReactionCount != null && newReactionCount != originalSong.totalReactionCount) {
        updatedReactionCount = newReactionCount;
        changed = true;
      }

      if (changed) {
        _allSongs[songIndex] = Song(
          id: originalSong.id,
          title: originalSong.title,
          artist: originalSong.artist,
          album: originalSong.album,
          genre: originalSong.genre,
          duration: originalSong.duration,
          releaseDate: originalSong.releaseDate,
          language: originalSong.language,
          tags: originalSong.tags,
          createdAt: originalSong.createdAt,
          viewCount: originalSong.viewCount,
          commentCount: updatedCommentCount, // updated
          totalReactionCount: updatedReactionCount, // updated
        );
        _applyFiltersAndSearch(); // Pour que _filteredSongs soit aussi mise à jour et notifie les listeners
        if (kDebugMode) {
          print("SongProvider: Updated interaction counts for song $songId. New comments: $updatedCommentCount, New reactions: $updatedReactionCount");
        }
      }
    }
  }


  // --- Gestion des erreurs ---
  void clearError() {
    if (_error != null) {
      if (kDebugMode) {
        print("SongProvider: Clearing error: '$_error'");
      }
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print("SongProvider: Disposing...");
    }
    super.dispose();
  }
}