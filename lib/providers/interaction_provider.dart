// lib/providers/interaction_provider.dart
import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../models/reaction.dart';
import '../services/ApiService.dart';
import './auth_provider.dart';
import './song_provider.dart';

class InteractionProvider with ChangeNotifier {
  final ApiService _apiService;
  AuthProvider _authProvider;
  SongProvider? _songProvider;

  String? _currentSongId;
  Map<String, int> _reactionCounts = {};
  String? _currentUserReactionEmoji; // Stocke L'UNIQUE emoji de l'utilisateur actuel

  List<Comment> _comments = [];

  bool _isLoadingReactions = false;
  bool _isLoadingComments = false;
  String? _error;

  bool _isReactionsInitializedForCurrentSong = false;
  bool _isCommentsInitializedForCurrentSong = false;

  InteractionProvider(this._apiService, this._authProvider, [this._songProvider]);

  String? get currentSongId => _currentSongId;
  Map<String, int> get reactionCounts => Map.unmodifiable(_reactionCounts);
  List<Comment> get comments => List.unmodifiable(_comments);
  bool get isLoadingReactions => _isLoadingReactions;
  bool get isLoadingComments => _isLoadingComments;
  String? get error => _error;

  bool hasUserReactedWith(String emoji) => _currentUserReactionEmoji == emoji;

  bool get isReactionsInitializedForCurrentSong => _isReactionsInitializedForCurrentSong;
  bool get isCommentsInitializedForCurrentSong => _isCommentsInitializedForCurrentSong;

  String? get currentUserReactionEmoji => _currentUserReactionEmoji;

  bool isInitializedForSong(String songId) {
    return _currentSongId == songId &&
        _isReactionsInitializedForCurrentSong &&
        _isCommentsInitializedForCurrentSong;
  }

  void updateAuthProvider(AuthProvider newAuthProvider) {
    if (_authProvider.token != newAuthProvider.token || _authProvider.currentUser?.id != newAuthProvider.currentUser?.id) {
      _authProvider = newAuthProvider;
      if (_currentSongId != null) {
        _isReactionsInitializedForCurrentSong = false;
        _currentUserReactionEmoji = null;
      }
    }
  }

  Future<void> setSongId(String? newSongId, {bool forceRefresh = false}) async {
    if (_currentSongId == newSongId && !forceRefresh && (newSongId != null && isInitializedForSong(newSongId))) {
      return;
    }
    final songChanged = _currentSongId != newSongId;
    _currentSongId = newSongId;

    if (songChanged || forceRefresh) {
      _reactionCounts = {};
      _currentUserReactionEmoji = null;
      _comments = [];
      _isReactionsInitializedForCurrentSong = false;
      _isCommentsInitializedForCurrentSong = false;
      _error = null;
    }
    notifyListeners();

    if (_currentSongId != null) {
      await Future.wait([fetchReactions(), fetchComments()]);
    } else {
      _isLoadingReactions = false;
      _isLoadingComments = false;
    }
  }

  Future<void> fetchReactions() async {
    if (_currentSongId == null) return;
    if (_isLoadingReactions && _currentSongId == _currentSongId) return;

    _isLoadingReactions = true;
    notifyListeners();

    try {
      final fetchedReactionsFromApi = await _apiService.fetchReactions(_currentSongId!, authToken: _authProvider.token);

      _reactionCounts = {};
      _currentUserReactionEmoji = null;
      final String? currentUserId = _authProvider.currentUser?.id;

      for (var reaction in fetchedReactionsFromApi) {
        _reactionCounts[reaction.emoji] = (_reactionCounts[reaction.emoji] ?? 0) + 1;
        if (reaction.reactorId == currentUserId) {
          // Si l'API garantit une seule réaction par utilisateur, ceci est correct.
          _currentUserReactionEmoji = reaction.emoji;
        }
      }

      _isReactionsInitializedForCurrentSong = true;
      if(!_isLoadingComments) _error = null;
    } catch (e) {
      _error = "Erreur chargement réactions: ${e.toString()}";
      _isReactionsInitializedForCurrentSong = false;
    } finally {
      _isLoadingReactions = false;
      notifyListeners();
    }
  }

  Future<void> fetchComments() async {
    // ... (INCHANGÉ) ...
    if (_currentSongId == null) return;
    if (_isLoadingComments && _currentSongId == _currentSongId) return;

    _isLoadingComments = true;
    notifyListeners();

    try {
      _comments = await _apiService.fetchComments(_currentSongId!, authToken: _authProvider.token);
      _isCommentsInitializedForCurrentSong = true;
      if(!_isLoadingReactions) _error = null;
    } catch (e) {
      _error = _error ?? "Erreur chargement commentaires: ${e.toString()}";
      _isCommentsInitializedForCurrentSong = false;
    } finally {
      _isLoadingComments = false;
      notifyListeners();
    }
  }

  Future<bool> toggleReaction(String newEmojiToggled) async {
    if (_currentSongId == null) {
      _error = "Aucune chanson sélectionnée.";
      notifyListeners();
      return false;
    }
    if (!_authProvider.isAuthenticated || _authProvider.token == null) {
      _error = "Vous devez être connecté pour réagir.";
      notifyListeners();
      return false;
    }

    // Sauvegarder l'état actuel pour un éventuel rollback en cas d'échec de l'API
    final String? emojiPreviouslySet = _currentUserReactionEmoji;
    final Map<String, int> countsBeforeOptimisticUpdate = Map.from(_reactionCounts);

    // --- Logique de mise à jour optimiste (pour une interface utilisateur réactive immédiate) ---
    // Détermine quel sera l'état local après l'action de l'utilisateur, AVANT l'appel API.
    if (_currentUserReactionEmoji == newEmojiToggled) {
      // Cas 1: L'utilisateur clique sur l'emoji qui est déjà sa réaction actuelle -> intention de la supprimer
      _currentUserReactionEmoji = null; // Supprimer localement la réaction de l'utilisateur
      // Décrémenter le compteur local pour cet emoji
      _reactionCounts[newEmojiToggled] = (_reactionCounts[newEmojiToggled] ?? 1) - 1;
      if ((_reactionCounts[newEmojiToggled] ?? 0) <= 0) {
        _reactionCounts.remove(newEmojiToggled); // Retirer l'emoji si le compte tombe à zéro ou moins
      }
    } else {
      // Cas 2: L'utilisateur clique sur un nouvel emoji (ou n'avait pas de réaction)
      // -> intention de définir cette nouvelleEmojiToggled comme sa réaction.

      // Si l'utilisateur avait une réaction précédente (un emoji différent), la décrémenter localement.
      if (_currentUserReactionEmoji != null) {
        _reactionCounts[_currentUserReactionEmoji!] = (_reactionCounts[_currentUserReactionEmoji!] ?? 1) - 1;
        if ((_reactionCounts[_currentUserReactionEmoji!] ?? 0) <= 0) {
          _reactionCounts.remove(_currentUserReactionEmoji!); // Retirer l'ancien emoji si le compte tombe à zéro
        }
      }
      // Définir la nouvelle réaction de l'utilisateur localement
      _currentUserReactionEmoji = newEmojiToggled;
      // Incrémenter le compteur local pour la nouvelleEmojiToggled
      _reactionCounts[newEmojiToggled] = (_reactionCounts[newEmojiToggled] ?? 0) + 1;
    }

    // Notifier immédiatement les widgets qui écoutent ce provider pour mettre à jour l'interface utilisateur
    notifyListeners();

    // --- Appel API ---
    // Tenter d'appliquer le changement sur le serveur.
    // IMPORTANT: Votre API `postReaction` (ou l'endpoint que vous utilisez ici) doit gérer correctement
    // le comportement de "set ou unset" pour la réaction unique de l'utilisateur.
    // C'est-à-dire, si vous envoyez un emoji :
    // - Si l'utilisateur l'avait déjà, l'API le supprime.
    // - Si l'utilisateur avait une autre réaction, l'API supprime l'ancienne et ajoute la nouvelle.
    // - Si l'utilisateur n'avait pas de réaction, l'API l'ajoute.
    try {
      // L'appel à l'API demande au serveur de mettre à jour la réaction de l'utilisateur pour cette chanson
      // en fonction de newEmojiToggled.
      await _apiService.postReaction(_currentSongId!, newEmojiToggled, authToken: _authProvider.token);

      // --- Synchronisation après l'appel API ---
      // Après un appel API réussi (que ce soit ajout, suppression ou changement), le moyen le plus fiable
      // de garantir que l'état local est parfaitement synchronisé avec le serveur est de re-fetcher
      // toutes les réactions pour cette chanson. `fetchReactions` mettra à jour `_reactionCounts`
      // et `_currentUserReactionEmoji` avec les données exactes du serveur.
      await fetchReactions();

      // Optionnel: Notifier SongProvider des changements de compteurs globaux
      _songProvider?.updateSongInteractionCounts(
          _currentSongId!,
          // Recalculer le total à partir des données fraîchement fetchées par fetchReactions
          newReactionCount: _reactionCounts.values.fold(0, (sum, item) => sum! + item)
      );

      _error = null; // Effacer toute erreur précédente si l'opération réussit
      // Remarque: fetchReactions() aura déjà appelé notifyListeners(), donc un autre appel ici n'est
      // généralement pas nécessaire si l'opération réussit sans erreur intermédiaire.
      return true;

    } catch (e) {
      // --- Gestion de l'erreur et Rollback ---
      // Si l'appel API échoue, afficher une erreur et annuler les changements optimistes dans l'UI.
      _error = "Erreur lors de la mise à jour de la réaction: ${e.toString()}";

      // Restaurer l'état précédent des compteurs et de la réaction de l'utilisateur.
      _reactionCounts = countsBeforeOptimisticUpdate;
      _currentUserReactionEmoji = emojiPreviouslySet;

      // Notifier à nouveau pour que l'UI reflète le rollback.
      notifyListeners();
      return false; // Indiquer que l'opération a échoué.
    }
  }

  Future<bool> addComment(String text) async {
    // ... (INCHANGÉ) ...
    if (_currentSongId == null) {
      _error = "Aucune chanson sélectionnée.";
      notifyListeners();
      return false;
    }
    if (!_authProvider.isAuthenticated || _authProvider.token == null || _authProvider.currentUser == null) {
      _error = "Vous devez être connecté pour commenter.";
      notifyListeners();
      return false;
    }

    try {
      final newCommentFromApi = await _apiService.postComment(
        _currentSongId!,
        text,
        authToken: _authProvider.token!,
      );

      if (newCommentFromApi != null) {
        _comments.insert(0, newCommentFromApi);
        _isCommentsInitializedForCurrentSong = true;

        _songProvider?.updateSongInteractionCounts(
            _currentSongId!,
            newCommentCount: _comments.length
        );
        _error = null;
        notifyListeners();
        return true;
      } else {
        _error = "Impossible d'ajouter le commentaire.";
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = "Erreur lors de l'ajout du commentaire: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }
}