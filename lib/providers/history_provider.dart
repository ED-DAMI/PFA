// lib/providers/history_provider.dart
import 'package:flutter/foundation.dart';
import '../models/song.dart'; // Historique contient des chansons

import '../services/ApiService.dart';
import 'auth_provider.dart';

class HistoryProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  List<Song> _history = []; // Les chansons les plus récentes en premier
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  HistoryProvider(this._apiService, this._authProvider);

  List<Song> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;


  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (_authProvider.currentUser?.id != newAuthProvider.currentUser?.id) {
      _authProvider = newAuthProvider;
      _history = [];
      _isInitialized = false;
      _error = null;
      if (_authProvider.isAuthenticated) {
        fetchHistory();
      } else {
        notifyListeners();
      }
    } else {
      _authProvider = newAuthProvider;
    }
  }

  Future<void> fetchHistory({bool forceRefresh = false}) async {
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _history = [];
      _isInitialized = true;
      notifyListeners();
      return;
    }
    if (_isLoading || (_isInitialized && !forceRefresh)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Note: fetchHistory peut retourner directement List<Song> si l'API
      // renvoie les objets Song complets, ou List<HistoryEntry> si elle
      // renvoie juste des IDs et timestamps (nécessiterait un fetch des chansons ensuite).
      // Supposons ici qu'elle retourne List<Song>
      _history = await _apiService.fetchUserHistory(authToken: _authProvider.token!);
      _isInitialized = true;
      if (kDebugMode) {
        print("HistoryProvider: Fetched ${_history.length} history entries.");
      }
    } catch (e) {
      _error = "Erreur chargement historique: $e";
      _isInitialized = false;
      if (kDebugMode) {
        print("HistoryProvider: Error fetching history: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Méthode appelée (potentiellement par AudioPlayerService) lorsqu'une chanson est jouée assez longtemps
  // pour être ajoutée à l'historique. Ceci est OPTIMISTE. L'API devrait gérer la logique serveur.
  void addSongToLocalHistoryOptimistic(Song song) {
    if (!_authProvider.isAuthenticated) return;

    // Éviter les doublons consécutifs immédiats (optionnel)
    if (_history.isNotEmpty && _history.first.id == song.id) {
      return;
    }

    // Supprimer les anciennes occurrences de cette chanson pour la remonter en haut
    _history.removeWhere((s) => s.id == song.id);
    // Ajouter la chanson au début
    _history.insert(0, song);

    // Limiter la taille de l'historique local (optionnel)
    // const int maxHistorySize = 100;
    // if (_history.length > maxHistorySize) {
    //   _history = _history.sublist(0, maxHistorySize);
    // }

    notifyListeners();

    // Note: Normalement, un appel API pour enregistrer cet événement d'écoute
    // serait fait séparément (peut-être depuis AudioPlayerService).
    // `fetchHistory` re-synchronisera avec le serveur lors du prochain chargement/refresh.
  }
}