import 'package:flutter/foundation.dart';

import '../models/song.dart'; // Assurez-vous que ce chemin est correct
import '../models/tag.dart';  // Assurez-vous que ce chemin est correct

import '../widgets/services/ApiService.dart'; // Assurez-vous que ce chemin est correct
import 'auth_provider.dart';      // Assurez-vous que ce chemin est correct

class SongProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  List<Song> _allSongs = [];
  List<Song> _filteredSongs = [];
  List<Tag> _tags = [];
  Tag? _selectedTag;
  String _searchQuery = '';

  bool _isInitialized = false;
  bool _isLoadingSongs = false; // Pour le chargement/rafraîchissement des chansons
  bool _isLoadingTags = false;  // Pour le chargement/rafraîchissement des tags
  bool _isLoadingSongDetails = false; // Pour le chargement d'une chanson spécifique par ID
  String? _error;

  SongProvider(this._apiService, AuthProvider initialAuthProvider)
      : _authProvider = initialAuthProvider {
    if (kDebugMode) {
      print("SongProvider: Instance created. Initial Auth state: ${_authProvider.isAuthenticated}, Token available: ${_authProvider.token != null}");
    }
    // L'initialisation est maintenant principalement déclenchée par updateAuthProvider
    // ou manuellement (par exemple, par pull-to-refresh appelant initialize(forceRefresh: true)).
  }

  // --- Getters ---
  List<Song> get songsToDisplay => _filteredSongs;
  List<Tag> get tags => _tags;
  Tag? get selectedTag => _selectedTag;
  String get searchQuery => _searchQuery;

  // isLoading combiné pour l'UI (principalement pour le chargement initial)
  bool get isLoading => (_isLoadingSongs || _isLoadingTags) && !_isInitialized;
  // Getters individuels si l'UI a besoin de plus de granularité
  bool get isLoadingInitialSongs => _isLoadingSongs && !_isInitialized;
  bool get isLoadingInitialTags => _isLoadingTags && !_isInitialized;
  bool get isRefreshingData => (_isLoadingSongs || _isLoadingTags) && _isInitialized; // Pour le pull-to-refresh
  bool get isLoadingSongDetails => _isLoadingSongDetails;

  String? get error => _error;
  bool get isInitialized => _isInitialized;

  Future<void> initialize({bool forceRefresh = false}) async {
    if (kDebugMode) {
      print("SongProvider: initialize(forceRefresh: $forceRefresh) called. Current auth state: ${_authProvider.isAuthenticated}, Token available: ${_authProvider.token != null}, IsInitialized: $_isInitialized");
    }

    if (_isInitialized && !forceRefresh) {
      if (kDebugMode) {
        print("SongProvider: Already initialized and not forcing refresh. Skipping.");
      }
      return;
    }

    final token = _authProvider.token;

    if (_authProvider.isAuthenticated || token != null) {
      bool wasAlreadyInitialized = _isInitialized; // Sauvegarder l'état précédent d'initialisation
      _isInitialized = false; // Marquer comme non initialisé pendant le fetch/refresh

      _isLoadingSongs = true;
      _isLoadingTags = true;
      _error = null; // Toujours effacer l'erreur avant une nouvelle tentative
      notifyListeners();

      try {
        if (kDebugMode) {
          print("SongProvider: Fetching songs and tags. ForceRefresh: $forceRefresh. Token: ${token != null ? "present" : "absent"}...");
        }

        // Simultanément fetcher les chansons et les tags
        final results = await Future.wait([
          _apiService.fetchSongs(authToken: token), // Supposons que fetchSongs retourne List<Song>
          _apiService.fetchTags(authToken: token),   // Supposons que fetchTags retourne List<Tag>
        ]);

        _allSongs = results[0] as List<Song>;
        _tags = results[1] as List<Tag>;

        _applyFiltersAndSearch(); // Ceci appelle notifyListeners()
        _isInitialized = true; // Marquer comme initialisé avec succès
        if (kDebugMode) {
          print("SongProvider: Data fetched/refreshed. ${_allSongs.length} songs, ${_tags.length} tags.");
        }
      } catch (e) {
        if (kDebugMode) {
          print("SongProvider: Error during data fetch/refresh: $e");
        }
        _error = "Erreur de chargement des données : ${e.toString()}";

        if (!wasAlreadyInitialized) { // Si c'était la première tentative d'initialisation (pas un refresh)
          _allSongs = [];
          _tags = [];
          _filteredSongs = [];
          _isInitialized = false; // Échec de l'initialisation
        } else {
          // Si c'était un refresh et qu'il a échoué, on garde les anciennes données.
          // _isInitialized reste true pour indiquer que des données (anciennes) sont disponibles.
          // L'erreur sera affichée par un SnackBar ou un message dans l'UI.
          _isInitialized = true;
        }
      } finally {
        _isLoadingSongs = false;
        _isLoadingTags = false;
        // Si _applyFiltersAndSearch n'a pas été appelé (en cas d'erreur avant), notifier ici.
        // Si _isInitialized est false (échec total du premier chargement), l'UI le reflétera.
        // Si _isInitialized est true (refresh échoué mais données anciennes présentes), l'UI est ok.
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
      _error = !_authProvider.isAuthenticated && token == null ? "Veuillez vous connecter pour voir les chansons." : "Problème de configuration ou d'authentification.";
      _isInitialized = false;
      _isLoadingSongs = false;
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (kDebugMode) {
      print("SongProvider: updateAuthProvider called. New auth state: ${newAuthProvider.isAuthenticated}, New token: ${newAuthProvider.token != null}");
      print("SongProvider: Old auth state: ${_authProvider.isAuthenticated}, Old token: ${_authProvider.token != null}, Was initialized: $_isInitialized");
    }

    bool authContextSignificantlyChanged = (_authProvider.token != newAuthProvider.token) ||
        (_authProvider.isAuthenticated != newAuthProvider.isAuthenticated);

    _authProvider = newAuthProvider;

    // Réinitialiser si le contexte d'authentification a changé de manière significative
    // OU si le provider n'a jamais été initialisé.
    if (authContextSignificantlyChanged || !_isInitialized) {
      if (kDebugMode) {
        print("SongProvider: Auth context changed significantly or not initialized. Resetting and re-initializing SongProvider data.");
      }
      // Forcer la réinitialisation complète des données et de l'état
      _isInitialized = false; // Marquer pour une réinitialisation complète
      // Effacer les données existantes pour éviter d'afficher des données d'un utilisateur précédent
      _allSongs = [];
      _filteredSongs = [];
      _tags = [];
      _selectedTag = null;
      _searchQuery = '';
      _error = null;
      // _isLoading sera géré par initialize()

      initialize(); // Relancer l'initialisation avec le nouvel état d'auth
    } else if (kDebugMode) {
      print("SongProvider: Auth context effectively unchanged and already initialized. No re-initialization needed by updateAuthProvider.");
    }
  }

  void selectTag(Tag? tag) {
    if (kDebugMode) {
      print("SongProvider: Tag selected: ${tag?.name ?? 'None'}");
    }
    // Vérifier si la sélection a réellement changé pour éviter des rebuilds inutiles
    if (_selectedTag?.id != tag?.id) {
      _selectedTag = tag;
      _applyFiltersAndSearch();
    }
  }

  void searchSongs(String query) {
    final newQuery = query.trim().toLowerCase();
    if (kDebugMode) {
      print("SongProvider: Search query changing from '$_searchQuery' to: '$newQuery'");
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
      // Assurez-vous que la logique de filtrage par tag correspond à vos modèles.
      // Exemple: si Song.genre est un String et Tag.name est le nom du genre.
      tempSongs = tempSongs.where((song) =>
      song.genre.toLowerCase() == _selectedTag!.name.toLowerCase()
      ).toList();
      // Ou si Song.tags est une List<String> de noms de tags:
      // tempSongs = tempSongs.where((song) =>
      //   song.tags.any((tagName) => tagName.toLowerCase() == _selectedTag!.name.toLowerCase())
      // ).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempSongs = tempSongs.where((song) {
        final titleMatch = song.title.toLowerCase().contains(_searchQuery);
        final artistMatch = song.artist.toLowerCase().contains(_searchQuery);
        final albumMatch = song.album?.toLowerCase().contains(_searchQuery) ?? false;
        return titleMatch || artistMatch || albumMatch;
      }).toList();
    }

    _filteredSongs = tempSongs;
    if (kDebugMode) {
      print("SongProvider: Filtering complete. ${_filteredSongs.length} songs match.");
    }
    notifyListeners();
  }

  Future<Song?> getSongById(String songId) async {
    if (kDebugMode) {
      print("SongProvider: Getting song by ID: $songId");
    }
    try {
      final localSong = _allSongs.firstWhere((s) => s.id == songId, orElse: () => throw StateError("Not found"));
      if (kDebugMode) print("SongProvider: Song $songId found in local cache (_allSongs).");
      return localSong;
    } catch (_) { // L'erreur spécifique StateError est ignorée ici, on essaie l'API
      if (kDebugMode) print("SongProvider: Song $songId not in _allSongs. Will try API.");
    }

    _isLoadingSongDetails = true;
    // Ne pas effacer _error global ici, car cela pourrait masquer une erreur de chargement principale.
    // Gérer l'erreur de cette opération plus localement si nécessaire.
    String? fetchError;
    notifyListeners();

    try {
      final token = _authProvider.token;
      final song = await _apiService.fetchSongById(songId, authToken: token);
      if (song != null) {
        if (kDebugMode) print("SongProvider: Song $songId fetched from API successfully.");
        // Optionnel: Mettre à jour _allSongs. Cela peut être complexe.
        // Si la chanson est récupérée, on pourrait l'ajouter/mettre à jour dans _allSongs.
        // int existingIndex = _allSongs.indexWhere((s) => s.id == songId);
        // if (existingIndex != -1) {
        //   _allSongs[existingIndex] = song;
        // } else {
        //   _allSongs.add(song);
        // }
        // _applyFiltersAndSearch(); // Pour refléter le changement si _allSongs est modifié
      } else {
        if (kDebugMode) print("SongProvider: Song $songId not found via API.");
        fetchError = "Chanson non trouvée.";
      }
      return song;
    } catch (e) {
      if (kDebugMode) {
        print("SongProvider: Error fetching song $songId by ID: $e");
      }
      fetchError = "Erreur lors du chargement des détails de la chanson.";
      // Mettre à jour l'erreur globale si on veut que l'UI la reflète,
      // sinon, l'appelant de getSongById devrait gérer l'erreur.
      // _error = fetchError;
      return null;
    } finally {
      _isLoadingSongDetails = false;
      notifyListeners();
      if (fetchError != null && _error == null) { // Afficher l'erreur si pas déjà une erreur globale plus importante
        // _error = fetchError; // Optionnel: définir l'erreur globale
        // notifyListeners();
      }
    }
  }

  void updateSongInteractionCounts(String songId, {int? newCommentCount, int? newReactionCount}) {
    int songIndexAll = _allSongs.indexWhere((s) => s.id == songId);
    bool changedInAll = false;

    if (songIndexAll != -1) {
      final originalSong = _allSongs[songIndexAll];
      int updatedCommentCount = originalSong.commentCount;
      int updatedReactionCount = originalSong.totalReactionCount;

      if (newCommentCount != null && newCommentCount != originalSong.commentCount) {
        updatedCommentCount = newCommentCount;
        changedInAll = true;
      }
      if (newReactionCount != null && newReactionCount != originalSong.totalReactionCount) {
        updatedReactionCount = newReactionCount;
        changedInAll = true;
      }

      if (changedInAll) {
        _allSongs[songIndexAll] = originalSong
            .copyWith(
          commentCount: updatedCommentCount,
          totalReactionCount: updatedReactionCount,
        );
      }
    }

    // Mettre aussi à jour dans _filteredSongs pour une UI réactive immédiate si la chanson y est.
    int songIndexFiltered = _filteredSongs.indexWhere((s) => s.id == songId);
    bool changedInFiltered = false;
    if (songIndexFiltered != -1) {
      final originalSong = _filteredSongs[songIndexFiltered];
      int updatedCommentCount = originalSong.commentCount;
      int updatedReactionCount = originalSong.totalReactionCount;

      if (newCommentCount != null && newCommentCount != originalSong.commentCount) {
        updatedCommentCount = newCommentCount;
        changedInFiltered = true;
      }
      if (newReactionCount != null && newReactionCount != originalSong.totalReactionCount) {
        updatedReactionCount = newReactionCount;
        changedInFiltered = true;
      }
      if (changedInFiltered) {
        _filteredSongs[songIndexFiltered] = originalSong.copyWith(
          commentCount: updatedCommentCount,
          totalReactionCount: updatedReactionCount,
        );
      }
    }


    if (changedInAll || changedInFiltered) {
      if (kDebugMode) {
        print("SongProvider: Updated interaction counts for song $songId.");
      }
      notifyListeners(); // Notifier si un changement a eu lieu dans l'une ou l'autre liste
    }
  }

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