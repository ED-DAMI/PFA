// lib/providers/home_provider.dart
import 'package:flutter/material.dart';
// Assurez-vous que l'import utilise la bonne casse !
import '../models/song.dart'; // <-- Utilise 'song.dart'
import '../services/ApiService.dart';
import '../providers/auth_provider.dart';
import '../models/playlist.dart';


class HomeProvider with ChangeNotifier {
  final ApiService _apiService;
  final AuthProvider? _authProvider;

  // Types de données utilisant le modèle Song corrigé
  List<Song> _recommendations = [];
  List<Playlist> _popularPlaylists = [];
  List<Song> _newReleases = []; // <-- Doit être chargé correctement
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialLoadComplete = false; // Pour gérer l'indicateur de chargement

  HomeProvider(this._apiService, [this._authProvider]) {
    fetchHomeData(); // Charger au démarrage
  }

  // Getters
  List<Song> get recommendations => _recommendations;
  List<Playlist> get popularPlaylists => _popularPlaylists;
  List<Song> get newReleases => _newReleases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInitialLoadComplete => _isInitialLoadComplete; // Peut être utile pour l'UI

  Future<void> fetchHomeData() async {
    if (_isLoading) return; // Empêche les appels multiples

    _isLoading = true;
    // Ne pas notifier ici si c'est un refresh, RefreshIndicator s'en charge
    if (!_isInitialLoadComplete) {
      _errorMessage = null; // Efface l'erreur seulement au début d'un chargement initial
      notifyListeners();
    }


    try {
      // Utiliser Future.wait pour récupérer les données en parallèle (plus rapide)
      final results = await Future.wait([
        _apiService.fetchPlaylists(), // Récupère les playlists
        _apiService.fetchRecommendations(await _authProvider?.getToken()), // Récupère les recommandations
        _apiService.fetchRecommendations(await _authProvider?.getToken()), // *** AJOUT/CORRECTION: Récupère les nouveautés ***
      ]);

      // Effacer l'erreur seulement après un fetch réussi
      _errorMessage = null;

      // Assigner les résultats après que tout soit terminé
      // Important: S'assurer que ApiService retourne les bons types !
      _popularPlaylists = results[0] as List<Playlist>;
      _recommendations = results[1] as List<Song>;
      _newReleases = results[2] as List<Song>; // *** CORRECTION: Assigner les nouveautés récupérées ***

      _isInitialLoadComplete = true; // Marquer que le chargement initial est fait

      print("Home data fetched/refreshed successfully:");
      print("Recommendations: ${_recommendations.length} items");
      print("Playlists: ${_popularPlaylists.length} items");
      print("New Releases: ${_newReleases.length} items");

      // ----- SUPPRIMER L'ANCIENNE LOGIQUE FAUTIVE -----
      // if (_recommendations.isEmpty)
      //      print("les recomandation sont vide");
      // // *** SUPPRIMER CETTE LIGNE INCORRECTE ***
      // // if (_newReleases.isEmpty) _newReleases =_apiService.fetchRecommendations(_authProvider?.token);


    } catch (e, stackTrace) { // Capturer aussi la stacktrace pour le debug
      print("Erreur chargement Accueil: $e");
      print("Stack Trace: $stackTrace"); // Très utile pour débugger !
      _errorMessage = "Erreur chargement Accueil: $e";
      // Garder les anciennes données affichées lors d'une erreur de refresh ? Ou tout effacer ?
      // Optionnel: Effacer en cas d'erreur
      // _popularPlaylists = [];
      // _recommendations = [];
      // _newReleases = [];
    } finally {
      _isLoading = false;
      // Toujours notifier à la fin pour mettre à jour l'UI (données ou erreur)
      notifyListeners();
    }
  }

  // Méthode pour rafraîchir (utilisée par RefreshIndicator)
  Future<void> refreshHomeData() async {
    print("Refreshing home data...");
    // Ré-exécute simplement la logique de chargement
    await fetchHomeData();
  }
}