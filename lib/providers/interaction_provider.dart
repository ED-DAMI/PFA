// lib/providers/interaction_provider.dart
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

import '../models/comment.dart';
import '../models/reaction.dart';
import '../models/user.dart';
import '../services/ApiService.dart';
import 'auth_provider.dart';

class InteractionProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;

  String? _currentSongId;
  List<Comment> _comments = [];
  Map<String, int> _reactionCounts = {};
  List<Reaction> _currentUserReactionsForCurrentSong = [];

  bool _isInitialized = false; // Pour savoir si les données pour _currentSongId ont été chargées
  bool _isLoadingComments = false;
  bool _isLoadingReactions = false;
  bool _isPostingComment = false;
  bool _isPostingReaction = false;
  String? _error;

  InteractionProvider(this._apiService, AuthProvider initialAuthProvider)
      : _authProvider = initialAuthProvider;

  // --- Getters ---
  List<Comment> get comments => _comments;
  Map<String, int> get reactionCounts => _reactionCounts;
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
        setSongId(_currentSongId!, forceRefresh: true);
      } else {
        _currentUserReactionsForCurrentSong = [];
        notifyListeners();
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
      _isInitialized = false;
      notifyListeners();
      _fetchInteractionsForSong(songId);
    }
  }

  Future<void> _fetchInteractionsForSong(String songId) async {
    if (songId.isEmpty) {
      _isInitialized = true;
      notifyListeners();
      return;
    }
    _error = null;
    _isLoadingComments = true;
    _isLoadingReactions = true;
    notifyListeners();

    try {
      // Fetch reactions first to update user's reaction state, then comments
      await fetchReactionsForSong(songId, triggeredBySetSongId: true);
      await fetchCommentsForSong(songId, triggeredBySetSongId: true);
      _isInitialized = true;
      if (kDebugMode) print("InteractionProvider: Interactions fetched for $songId");
    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error during combined fetch for $songId: $e");
      _error = "Erreur de chargement des interactions.";
      _isInitialized = false;
    } finally {
      // Les états de chargement sont gérés dans les méthodes individuelles.
      // On s'assure que la notification finale se fait après que tous les états soient à jour.
      if (_isLoadingComments || _isLoadingReactions) { // Évite de notifier inutilement si déjà false
        _isLoadingComments = false;
        _isLoadingReactions = false;
        notifyListeners();
      } else {
        notifyListeners(); // Au cas où l'état _isInitialized a changé
      }
    }
  }

  Future<void> fetchCommentsForSong(String songId, {bool triggeredBySetSongId = false}) async {
    if (!triggeredBySetSongId) {
      if (songId.isEmpty || _currentSongId != songId) return;
      _isLoadingComments = true;
      notifyListeners();
    }
    try {
      _comments = await _apiService.fetchComments(songId, authToken: _authProvider.token);
      if (kDebugMode) print("InteractionProvider: Fetched ${_comments.length} comments for song $songId");
    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error fetching comments for $songId: $e");
      _error = "Erreur chargement commentaires: ${e.toString()}";
      _comments = [];
    } finally {
      if (!triggeredBySetSongId) {
        _isLoadingComments = false;
        notifyListeners();
      } else {
        _isLoadingComments = false; // Doit être mis à false même si appelé par _fetchInteractionsForSong
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

      _currentUserReactionsForCurrentSong = [];
      if (_authProvider.isAuthenticated && _authProvider.currentUser != null) {
        final String currentUserName = _authProvider.currentUser!.name;
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
    } catch (e) {
      if (kDebugMode) print("InteractionProvider: Error fetching reactions for $songId: $e");
      _error = "Erreur chargement réactions: ${e.toString()}";
      _reactionCounts = {};
      _currentUserReactionsForCurrentSong = [];
    } finally {
      if (!triggeredBySetSongId) {
        _isLoadingReactions = false;
        notifyListeners();
      } else {
        _isLoadingReactions = false; // Doit être mis à false même si appelé par _fetchInteractionsForSong
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
    return _currentUserReactionsForCurrentSong.first.emoji == emojiSymbol;
  }

  Future<bool> addComment(String songIdParam, String text) async {
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
      );
      if (newComment != null) {
        _comments.insert(0, newComment);
        if (kDebugMode) print("InteractionProvider: Comment added for song $_currentSongId");
        // Notifier SongProvider (si référence existe et si nécessaire pour le count)
        return true;
      } else {
        _error = "Impossible d'ajouter le commentaire (API a retourné null).";
      }
    } catch (e) {
      _error = "Erreur ajout commentaire: ${e.toString()}";
      if (kDebugMode) print("InteractionProvider: Error adding comment for $_currentSongId: $e");
    } finally {
      _isPostingComment = false;
      notifyListeners();
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

    final Reaction? originalUserReaction = _currentUserReactionsForCurrentSong.firstOrNull;
    bool success = false;

    try {
      if (originalUserReaction != null) { // L'utilisateur a déjà une réaction
        if (originalUserReaction.emoji == emojiToggled) { // Clique sur le même emoji: supprimer
          if (kDebugMode) print("InteractionProvider: Toggling OFF reaction '${originalUserReaction.emoji}' (id: ${originalUserReaction.id})");
          _optimisticUpdateReactionCount(originalUserReaction.emoji, -1);
          _currentUserReactionsForCurrentSong = [];
          notifyListeners();

          success = await _apiService.deleteReaction(originalUserReaction.id, authToken: _authProvider.token!);
          if (!success) { // Rollback si API échoue
            _error = _error ?? "Échec suppression réaction.";
            _optimisticUpdateReactionCount(originalUserReaction.emoji, 1); // Remettre
            _currentUserReactionsForCurrentSong = [originalUserReaction];
            if (kDebugMode) print("InteractionProvider: Rollback delete for '${originalUserReaction.emoji}'");
          } else {
            if (kDebugMode) print("InteractionProvider: Reaction '${originalUserReaction.emoji}' removed successfully.");
          }
        } else { // Clique sur un emoji différent -> Modifier (Delete ancienne, Post nouvelle)
          if (kDebugMode) print("InteractionProvider: Changing reaction from '${originalUserReaction.emoji}' to '$emojiToggled'");
          _optimisticUpdateReactionCount(originalUserReaction.emoji, -1);
          _optimisticUpdateReactionCount(emojiToggled, 1);
          // Ne pas changer _currentUserReactionsForCurrentSong tout de suite pour le post.
          notifyListeners();

          bool deleteSuccess = await _apiService.deleteReaction(originalUserReaction.id, authToken: _authProvider.token!);
          if (deleteSuccess) {
            final Reaction? newApiReaction = await _apiService.postReaction(_currentSongId!, emojiToggled, authToken: _authProvider.token!);
            if (newApiReaction != null) {
              _currentUserReactionsForCurrentSong = [newApiReaction]; // Confirmer la nouvelle réaction
              success = true;
              if (kDebugMode) print("InteractionProvider: Reaction changed to '$emojiToggled' successfully.");
            } else { // Post a échoué
              _error = "Impossible de poster la nouvelle réaction.";
              _optimisticUpdateReactionCount(originalUserReaction.emoji, 1); // Rollback delete
              _optimisticUpdateReactionCount(emojiToggled, -1); // Rollback post
            }
          } else { // Delete a échoué
            _error = "Impossible de supprimer l'ancienne réaction pour modifier.";
            _optimisticUpdateReactionCount(originalUserReaction.emoji, 1); // Rollback delete
            _optimisticUpdateReactionCount(emojiToggled, -1); // Rollback post (qui n'a pas eu lieu)
          }
        }
      } else { // L'utilisateur n'a pas de réaction: ajouter nouvelle
        if (kDebugMode) print("InteractionProvider: Adding new reaction '$emojiToggled'");
        _optimisticUpdateReactionCount(emojiToggled, 1);
        // Pas de _currentUserReactionsForCurrentSong ici, attendre la réponse
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
      // Tentative de rollback plus général si une exception survient, pourrait nécessiter un refetch
      if(originalUserReaction != null) _currentUserReactionsForCurrentSong = [originalUserReaction];
      else _currentUserReactionsForCurrentSong = [];
      await fetchReactionsForSong(_currentSongId!, triggeredBySetSongId: true); // Re-fetch pour s'assurer de la cohérence
    } finally {
      _isPostingReaction = false;
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