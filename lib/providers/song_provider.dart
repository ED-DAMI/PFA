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
    // Pour s'assurer qu'il est appelé au moins une fois après la création si l'auth est déjà valide :
    // Future.microtask(() => initializeIfNeeded()); // Déclenche l'initialisation si nécessaire après la construction
    // OU mieux : laisser updateAuthProvider faire son travail lors du premier update du ProxyProvider.
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

    // Si déjà initialisé ET que l'auth n'a pas changé de manière à nécessiter un rechargement, on sort.
    // Cette vérification est importante car initialize() peut être appelé par updateAuthProvider.
    // Si _isInitialized est true ici, cela signifie que les données ont été chargées avec l'état actuel de _authProvider.
    if (_isInitialized) {
      if (kDebugMode) {
        print("SongProvider: Already initialized with current auth context. Skipping re-initialization.");
      }
      return;
    }

    final token = _authProvider.token; // Accès direct au token actuel de l'AuthProvider interne
    // Si l'authProvider n'a pas encore chargé son token (ex: depuis SharedPreferences), token peut être null.
    // Attendre que AuthProvider soit prêt peut être une stratégie, mais ici on se base sur son état actuel.
    // Si le token est requis pour fetchSongs/fetchTags et qu'il est null, l'API échouera ou retournera des données publiques.

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
        _isInitialized = true; // Marquer comme initialisé APRÈS succès
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
      _error = _authProvider.isAuthenticated ? "Token d'application manquant." : "Veuillez vous connecter pour voir les chansons.";
      _isInitialized = false;
      _isLoadingSongs = false;
      _isLoadingTags = false;
      notifyListeners();
    }
  }

  // Met à jour l'instance AuthProvider interne et réinitialise si l'auth a changé.
  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (kDebugMode) {
      print("SongProvider: updateAuthProvider called. New auth state: ${newAuthProvider.isAuthenticated}, New token: ${newAuthProvider.token != null}");
    }

    bool authSignificantlyChanged = (_authProvider.token != newAuthProvider.token) ||
        (_authProvider.isAuthenticated != newAuthProvider.isAuthenticated) ||
        !_isInitialized; // Forcer l'initialisation si elle n'a jamais eu lieu

    _authProvider = newAuthProvider; // Toujours mettre à jour la référence

    if (authSignificantlyChanged) {
      if (kDebugMode) {
        print("SongProvider: Auth state changed significantly or not initialized. Re-initializing SongProvider data.");
      }
      _isInitialized = false; // Forcer la réinitialisation (ou la première initialisation)
      initialize(); // Relancer l'initialisation avec le nouvel état d'auth
    } else if (kDebugMode) {
      print("SongProvider: Auth state unchanged or already initialized. No re-initialization needed by updateAuthProvider.");
    }
  }

  // Le reste du code de SongProvider (selectTag, searchSongs, _applyFiltersAndSearch, getSongById, incrementViewCount, clearError, dispose)
  // est globalement bien structuré et peut rester tel quel.
  // Assurez-vous que la logique de filtrage dans _applyFiltersAndSearch corresponde bien à vos modèles de données.
  // Par exemple, pour les tags :
  //   tempSongs = tempSongs.where((song) =>
  //     song.genre?.toLowerCase() == _selectedTag!.name.toLowerCase() // si genre est un String
  //     // ou song.tagIds?.contains(_selectedTag!.id) ?? false // si song a une liste d'IDs de tags
  //   ).toList();


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
      song.genre?.toLowerCase() == _selectedTag!.name.toLowerCase()
      ).toList();
      // Si Song a un champ comme `List<String> tagIds` et Tag a `String id`:
      // tempSongs = tempSongs.where((song) =>
      //   song.tagIds?.contains(_selectedTag!.id) ?? false
      // ).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempSongs = tempSongs.where((song) {
        final titleMatch = song.title.toLowerCase().contains(_searchQuery);
        final artistMatch = song.artist.toLowerCase().contains(_searchQuery);
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
    try {
      final localSong = _allSongs.firstWhere((s) => s.id == songId);
      if (kDebugMode) print("SongProvider: Song $songId found in local cache (_allSongs).");
      return localSong;
    } catch (e) {
      if (kDebugMode) print("SongProvider: Song $songId not in _allSongs. Will try API.");
    }

    _isLoadingSongDetails = true;
    _error = null;
    notifyListeners();

    try {
      final token = _authProvider.token;
      final song = await _apiService.fetchSongById(songId, authToken: token);
      if (song != null) {
        if (kDebugMode) print("SongProvider: Song $songId fetched from API successfully.");
        // Optionnel: Mettre à jour _allSongs pour le cache, attention à la duplication et à l'ordre.
        // Il est souvent plus simple de ne pas le faire ici et de compter sur un re-fetch global si nécessaire.
      } else {
        if (kDebugMode) print("SongProvider: Song $songId not found via API.");
      }
      return song;
    } catch (e) {
      if (kDebugMode) {
        print("SongProvider: Error fetching song $songId by ID: $e");
      }
      _error = "Erreur lors du chargement des détails de la chanson.";
      return null;
    } finally {
      _isLoadingSongDetails = false;
      notifyListeners();
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