// lib/providers/interaction_provider.dart
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../models/comment.dart';
import '../models/reaction.dart';
import '../models/user.dart';
import '../services/ApiService.dart';
import 'auth_provider.dart';
import 'song_provider.dart'; // Pour potentiellement notifier des changements de compteurs

class InteractionProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;
  final SongProvider? _songProvider; // Optionnel, pour mettre à jour les compteurs de chansons

  String? _currentSongId;
  List<Comment> _comments = [];
  Map<String, int> _reactionCounts = {}; // emoji -> count
  List<Reaction> _currentUserReactionsForCurrentSong = []; // Réactions de l'utilisateur actuel pour la chanson courante

  bool _isInitialized = false; // Pour savoir si les données pour _currentSongId ont été chargées
  bool _isLoadingComments = false;
  bool _isLoadingReactions = false;
  bool _isPostingComment = false;
  bool _isPostingReaction = false;
  String? _error;

  InteractionProvider(this._apiService, AuthProvider initialAuthProvider, [this._songProvider])
      : _authProvider = initialAuthProvider;

  // --- Getters ---
  List<Comment> get comments => _comments;
  Map<String, int> get reactionCounts => _reactionCounts; // Total counts for each emoji
  int get totalReactionCountForCurrentSong => _reactionCounts.values.fold(0, (sum, count) => sum + count);
  String? get currentSongId => _currentSongId;
  bool get isLoadingComments => _isLoadingComments;
  bool get isLoadingReactions => _isLoadingReactions;
  bool get isPostingComment => _isPostingComment;
  bool get isPostingReaction => _isPostingReaction;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoadingComments || _isLoadingReactions;
  String? get error => _error;
  User? get currentUser => _authProvider.currentUser;
  bool get isAuthenticated => _authProvider.isAuthenticated;

  void updateAuthProvider(AuthProvider newAuthProvider) {
    bool authSignificantlyChanged = (_authProvider.isAuthenticated != newAuthProvider.isAuthenticated) ||
        (_authProvider.currentUser?.id != newAuthProvider.currentUser?.id);

    _authProvider = newAuthProvider;

    if (authSignificantlyChanged) {
      if (kDebugMode) print("InteractionProvider: Auth state changed. Clearing user-specific interaction data if a song is set.");
      if (_currentSongId != null) {
        // Rafraîchir les données d'interaction pour refléter le nouvel utilisateur
        setSongId(_currentSongId!, forceRefresh: true);
      } else {
        _currentUserReactionsForCurrentSong = [];
        notifyListeners(); // Notifier au cas où l'UI dépend de _currentUserReactionsForCurrentSong
      }
    }
  }

  void setSongId(String songId, {bool forceRefresh = false}) {
    if (_currentSongId != songId || forceRefresh || !_isInitialized) {
      if (kDebugMode) print("InteractionProvider: Setting song ID to '$songId'. Force refresh: $forceRefresh, Was Initialized: $_isInitialized");
      _currentSongId = songId;
      _comments = [];
      _reactionCounts = {};
      _currentUserReactionsForCurrentSong = [];
      _error = null;
      _isInitialized = false; // Marquer comme non initialisé pour ce songId
      notifyListeners(); // Notifier le changement de songId et le reset des données
      _fetchInteractionsForSong(songId);
    }
  }

  Future<void> _fetchInteractionsForSong(String songId) async {
    if (songId.isEmpty) {
      _isInitialized = true; // Pas d'interactions à charger pour un songId vide
      notifyListeners();
      return;
    }
    _error = null;
    _isLoadingComments = true;
    _isLoadingReactions = true;
    notifyListeners(); // Notifier le début du chargement

    try {
      // Fetch reactions first (pour _currentUserReactionsForCurrentSong), then comments
      // L'ordre peut importer si l'un dépend de l'autre, ici ils sont indépendants
      await fetchReactionsForSong(songId, triggeredBySetSongId: true);
      await fetchCommentsForSong(songId, triggeredBySetSongId: true);
      _isInitialized = true; // Marquer comme initialisé après succès
      if (kDebugMode) print("InteractionProvider: Interactions fetched for $songId");
    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error during combined fetch for $songId: $e");
      _error = "Erreur de chargement des interactions.";
      _isInitialized = false; // Échec de l'initialisation
    } finally {
      // Les états _isLoadingComments et _isLoadingReactions sont déjà mis à false dans leurs méthodes respectives
      // S'assurer qu'ils sont bien false si l'appel combiné échoue avant qu'ils ne soient appelés
      _isLoadingComments = false;
      _isLoadingReactions = false;
      notifyListeners(); // Notifier la fin du chargement et l'état d'initialisation
    }
  }

  Future<void> fetchCommentsForSong(String songId, {bool triggeredBySetSongId = false}) async {
    if (!triggeredBySetSongId) { // Si appelé directement et non par _fetchInteractionsForSong
      if (songId.isEmpty || _currentSongId != songId) return; // Sécurité
      _isLoadingComments = true;
      notifyListeners();
    }
    try {
      _comments = await _apiService.fetchComments(songId, authToken: _authProvider.token);
      if (kDebugMode) print("InteractionProvider: Fetched ${_comments.length} comments for song $songId");
      _songProvider?.updateSongInteractionCounts(songId, newCommentCount: _comments.length);
    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error fetching comments for $songId: $e");
      _error = _error ?? "Erreur chargement commentaires: ${e.toString()}"; // Ne pas écraser une erreur de réactions
      _comments = []; // Réinitialiser en cas d'erreur
    } finally {
      if (!triggeredBySetSongId) {
        _isLoadingComments = false;
        notifyListeners();
      } else {
        _isLoadingComments = false; // Toujours mettre à false
      }
    }
  }

  Future<void> fetchReactionsForSong(String songId, {bool triggeredBySetSongId = false}) async {
    if (!triggeredBySetSongId) {
      if (songId.isEmpty || _currentSongId != songId) return;
      _isLoadingReactions = true;
      notifyListeners();
    }
    try {
      final List<Reaction> allReactions = await _apiService.fetchReactions(songId, authToken: _authProvider.token);
      _calculateReactionCounts(allReactions);

      _currentUserReactionsForCurrentSong = []; // Réinitialiser
      if (_authProvider.isAuthenticated && _authProvider.currentUser != null) {
        // Le nom d'utilisateur de l'API pour les réactions peut être `_authProvider.currentUser!.name` ou `id`
        // Assurez-vous que `reactorName` (ou quel que soit le champ) correspond
        final String currentUserName = _authProvider.currentUser!.name; // ou .name, selon ce que l'API attend/retourne
        _currentUserReactionsForCurrentSong = allReactions.where((r) => r.reactorName == currentUserName).toList();

        if (kDebugMode) {
          if (_currentUserReactionsForCurrentSong.isNotEmpty) {
            print("InteractionProvider: User's current reaction for $songId: ${_currentUserReactionsForCurrentSong.first.emoji}");
          } else {
            print("InteractionProvider: User has no reaction for $songId");
          }
        }
      }
      if (kDebugMode) print("InteractionProvider: Fetched ${allReactions.length} total reactions for song $songId. Counts: $_reactionCounts");
      _songProvider?.updateSongInteractionCounts(songId, newReactionCount: totalReactionCountForCurrentSong);

    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error fetching reactions for $songId: $e");
      _error = _error ?? "Erreur chargement réactions: ${e.toString()}";
      _reactionCounts = {};
      _currentUserReactionsForCurrentSong = [];
    } finally {
      if (!triggeredBySetSongId) {
        _isLoadingReactions = false;
        notifyListeners();
      } else {
        _isLoadingReactions = false;
      }
    }
  }

  void _calculateReactionCounts(List<Reaction> allReactions) {
    final counts = <String, int>{};
    for (var reaction in allReactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    _reactionCounts = counts;
  }

  bool hasUserReactedWith(String emojiSymbol) {
    if (!_authProvider.isAuthenticated || _currentUserReactionsForCurrentSong.isEmpty) {
      return false;
    }
    // Si un utilisateur ne peut avoir qu'une réaction, .first est ok.
    // S'il peut en avoir plusieurs de types différents (rare), ajuster.
    return _currentUserReactionsForCurrentSong.any((r) => r.emoji == emojiSymbol);
  }

  Future<bool> addComment(String text) async { // songId est maintenant _currentSongId
    if (_currentSongId == null) {
      _error = "Aucune chanson sélectionnée pour commenter.";
      notifyListeners();
      return false;
    }
    if (!_authProvider.isAuthenticated || _authProvider.token == null || _authProvider.currentUser == null) {
      _error = "Connectez-vous pour commenter.";
      notifyListeners();
      return false;
    }

    _isPostingComment = true;
    _error = null;
    notifyListeners();

    try {
      final newComment = await _apiService.postComment(
        _currentSongId!,
        text,
        authToken: _authProvider.token!,
        // L'API devrait utiliser le token pour identifier l'utilisateur.
        // Si l'API a besoin explicitement de `userId` ou `userName` dans le corps, ajoutez-le.
        // userId: _authProvider.currentUser!.id,
        // userName: _authProvider.currentUser!.name,
      );
      if (newComment != null) {
        _comments.insert(0, newComment); // Ajoute en haut de la liste
        if (kDebugMode) print("InteractionProvider: Comment added for song $_currentSongId");
        _songProvider?.updateSongInteractionCounts(_currentSongId!, newCommentCount: _comments.length);
        notifyListeners(); // Notifier pour reconstruire l'UI des commentaires
        return true;
      } else {
        _error = "Impossible d'ajouter le commentaire (API a retourné null).";
      }
    } catch (e) {
      _error = "Erreur ajout commentaire: ${e.toString()}";
      if (kDebugMode) print("InteractionProvider: Error adding comment for $_currentSongId: $e");
    } finally {
      _isPostingComment = false;
      notifyListeners(); // Notifier la fin du post
    }
    return false;
  }

  Future<bool> toggleReaction(String emojiToggled) async {
    if (_currentSongId == null) {
      _error = "Aucune chanson sélectionnée pour réagir.";
      notifyListeners(); return false;
    }
    if (!_authProvider.isAuthenticated || _authProvider.token == null || _authProvider.currentUser == null) {
      _error = "Connectez-vous pour réagir.";
      notifyListeners(); return false;
    }

    _isPostingReaction = true;
    _error = null;
    notifyListeners();

    // Trouve la réaction existante de l'utilisateur pour cet emoji ou n'importe quel emoji
    // S'il ne peut y avoir qu'une seule réaction par utilisateur par chanson:
    final Reaction? existingUserReactionOverall = _currentUserReactionsForCurrentSong.firstOrNull;
    bool success = false;

    try {
      if (existingUserReactionOverall != null) { // L'utilisateur a déjà une réaction (quelle qu'elle soit)
        if (existingUserReactionOverall.emoji == emojiToggled) { // Clique sur le même emoji: supprimer
          if (kDebugMode) print("InteractionProvider: Toggling OFF reaction '${existingUserReactionOverall.emoji}' (id: ${existingUserReactionOverall.id})");
          _optimisticUpdateReactionCount(existingUserReactionOverall.emoji, -1);
          _currentUserReactionsForCurrentSong = []; // Optimistic: remove
          notifyListeners();

          success = await _apiService.deleteReaction(existingUserReactionOverall.id, authToken: _authProvider.token!);
          if (!success) { // Rollback si API échoue
            _error = _error ?? "Échec suppression réaction.";
            _optimisticUpdateReactionCount(existingUserReactionOverall.emoji, 1); // Remettre
            _currentUserReactionsForCurrentSong = [existingUserReactionOverall]; // Rollback: re-add
            if (kDebugMode) print("InteractionProvider: Rollback delete for '${existingUserReactionOverall.emoji}'");
          } else {
            if (kDebugMode) print("InteractionProvider: Reaction '${existingUserReactionOverall.emoji}' removed successfully.");
          }
        } else { // Clique sur un emoji différent -> Modifier (Delete ancienne, Post nouvelle)
          if (kDebugMode) print("InteractionProvider: Changing reaction from '${existingUserReactionOverall.emoji}' to '$emojiToggled'");
          _optimisticUpdateReactionCount(existingUserReactionOverall.emoji, -1); // Remove old
          _optimisticUpdateReactionCount(emojiToggled, 1); // Add new
          // Optimistic: _currentUserReactionsForCurrentSong sera mis à jour avec la nouvelle réaction si post OK
          notifyListeners();

          bool deleteSuccess = await _apiService.deleteReaction(existingUserReactionOverall.id, authToken: _authProvider.token!);
          if (deleteSuccess) {
            final Reaction? newApiReaction = await _apiService.postReaction(_currentSongId!, emojiToggled, authToken: _authProvider.token!);
            if (newApiReaction != null) {
              _currentUserReactionsForCurrentSong = [newApiReaction]; // Confirmer la nouvelle réaction
              success = true;
              if (kDebugMode) print("InteractionProvider: Reaction changed to '$emojiToggled' successfully.");
            } else { // Post a échoué
              _error = "Impossible de poster la nouvelle réaction.";
              _optimisticUpdateReactionCount(existingUserReactionOverall.emoji, 1); // Rollback delete
              _optimisticUpdateReactionCount(emojiToggled, -1); // Rollback post
              _currentUserReactionsForCurrentSong = [existingUserReactionOverall]; // Revert to old one
            }
          } else { // Delete a échoué
            _error = "Impossible de supprimer l'ancienne réaction pour modifier.";
            _optimisticUpdateReactionCount(existingUserReactionOverall.emoji, 1); // Rollback delete
            _optimisticUpdateReactionCount(emojiToggled, -1); // Rollback (new emoji was never posted)
            // _currentUserReactionsForCurrentSong n'a pas changé d'état si delete échoue
          }
        }
      } else { // L'utilisateur n'a pas de réaction: ajouter nouvelle
        if (kDebugMode) print("InteractionProvider: Adding new reaction '$emojiToggled'");
        _optimisticUpdateReactionCount(emojiToggled, 1);
        // Optimistic: _currentUserReactionsForCurrentSong sera mis à jour si post OK
        notifyListeners();

        final Reaction? newApiReaction = await _apiService.postReaction(_currentSongId!, emojiToggled, authToken: _authProvider.token!);
        if (newApiReaction != null) {
          _currentUserReactionsForCurrentSong = [newApiReaction];
          success = true;
          if (kDebugMode) print("InteractionProvider: Reaction '$emojiToggled' added successfully.");
        } else { // Post a échoué
          _error = "Impossible d'ajouter la réaction.";
          _optimisticUpdateReactionCount(emojiToggled, -1); // Rollback
        }
      }
    } catch (e) {
      _error = "Erreur: ${e.toString()}";
      if (kDebugMode) print("InteractionProvider: Error in toggleReaction: $e");
      success = false;
      // Tentative de rollback général, plus sûr de refetcher.
      await fetchReactionsForSong(_currentSongId!, triggeredBySetSongId: true); // Re-fetch pour s'assurer de la cohérence
    } finally {
      _isPostingReaction = false;
      if (success) { // Si succès, mettre à jour le compteur global dans SongProvider
        _songProvider?.updateSongInteractionCounts(_currentSongId!, newReactionCount: totalReactionCountForCurrentSong);
      }
      notifyListeners(); // Notifier l'état final
    }
    return success;
  }


  void _optimisticUpdateReactionCount(String emoji, int delta) {
    _reactionCounts[emoji] = (_reactionCounts[emoji] ?? 0) + delta;
    if ((_reactionCounts[emoji] ?? 0) <= 0) {
      _reactionCounts.remove(emoji);
    }
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print("InteractionProvider: Disposing...");
    super.dispose();
  }
}