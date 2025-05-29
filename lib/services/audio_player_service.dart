// lib/services/audio_player_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

import '../config/api_config.dart';
import '../models/song.dart';


class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _baseUrl = API_BASE_URL;

  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false; // Votre booléen pour gérer l'état de chargement
  bool _isSeeking = false;

  List<Song> _playlistSongs = [];
  int _currentIndexInPlaylist = -1;
  bool _isPlaylistActive = false;

  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isLoading => _isLoading; // Vous exposez votre propre booléen
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get showPlayer => _currentSong != null;
  bool get isActive => _currentSong != null && (_playerState == PlayerState.playing || _playerState == PlayerState.paused);

  AudioPlayerService() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((newState) {
      final PlayerState oldPlayerState = _playerState;
      final bool wasLoading = _isLoading; // Sauvegarder l'état de chargement précédent

      _playerState = newState;

      // Mettre à jour _isLoading en fonction du nouvel état
      // Le chargement se termine quand on passe à playing, paused, stopped, ou completed.
      // Il commence quand vous appelez play() ou setSource().
      if (newState == PlayerState.playing ||
          newState == PlayerState.paused ||
          newState == PlayerState.stopped ||
          newState == PlayerState.completed) {
        _isLoading = false;
      }
      // Note: _isLoading sera mis à `true` dans la méthode `_playInternal`
      // avant d'appeler `setSource`.

      if (newState == PlayerState.completed) {
        _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero;
        if (_isPlaylistActive && _currentIndexInPlaylist < _playlistSongs.length - 1) {
          skipNext(fromAutoPlay: true);
        } else {
          _isPlaylistActive = false;
          _currentIndexInPlaylist = -1;
          // Optionnel: mettre _currentSong à null ou juste notifier l'état 'completed'
          // Si vous voulez que le player disparaisse après la fin de la playlist:
          // _currentSong = null;
        }
      }

      // Notifier si l'état du lecteur a changé OU si l'état de chargement a changé
      if (oldPlayerState != _playerState || wasLoading != _isLoading) {
        notifyListeners();
      }

      if (kDebugMode) print("[AudioPlayerService] State Changed: $_playerState, isLoading: $_isLoading, for song ${_currentSong?.id}");
    }, onError: (msg) { // Le type est Object ou String selon la version d'audioplayers
      if (kDebugMode) print("[AudioPlayerService ERREUR] State Stream: $msg");
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _totalDuration = Duration.zero;
      _currentPosition = Duration.zero;
      _isPlaylistActive = false;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (duration > Duration.zero && _totalDuration != duration) {
        _totalDuration = duration;
        notifyListeners();
        if (kDebugMode) print("[AudioPlayerService] Duration Changed: $duration for song ${_currentSong?.id}");
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!_isSeeking && _currentSong != null && _currentPosition != position) {
        _currentPosition = (position > _totalDuration && _totalDuration > Duration.zero) ? _totalDuration : position;
        notifyListeners();
      }
    });

    // onPlayerComplete est souvent redondant si onPlayerStateChanged gère PlayerState.completed
    // Mais on peut le garder pour des logs spécifiques si besoin.
    // _audioPlayer.onPlayerComplete.listen((event) {
    //   if (kDebugMode) print("[AudioPlayerService] Event Player Complete for song: ${_currentSong?.id}");
    // });
  }

  Future<void> _playInternal(Song song, {bool isFromPlaylist = false}) async {
    if (_isLoading && _currentSong?.id == song.id) {
      if (kDebugMode) print("[AudioPlayerService] Play called for ${song.id} but already loading/playing.");
      return;
    }

    if (_currentSong?.id == song.id && _playerState == PlayerState.paused) {
      await resume();
      return;
    }

    if (_playerState != PlayerState.stopped && _playerState != PlayerState.completed) {
      await _audioPlayer.stop(); // Assure un état propre avant de jouer une nouvelle chanson
    }

    _currentSong = song;
    _isLoading = true; // **** ICI, on met _isLoading à true ****
    _currentPosition = Duration.zero;
    _totalDuration = song.duration != null ? Duration(seconds: song.duration!) : Duration.zero;

    if (!isFromPlaylist) {
      _isPlaylistActive = false;
      _playlistSongs = [];
      _currentIndexInPlaylist = -1;
    }
    notifyListeners(); // Notifier l'UI que le chargement a commencé et que la chanson a changé

    final String directAudioUrl = '$_baseUrl/api/songs/${song.id}/audio';
    if (kDebugMode) print("[AudioPlayerService] Attempting to play from URL: $directAudioUrl");

    try {
      await _audioPlayer.setSource(UrlSource(directAudioUrl));
      // Note: audioplayers démarre la lecture après setSource si play() est appelé,
      // ou resume() est appelé. Ici, nous allons appeler resume() pour démarrer.
      await _audioPlayer.resume(); // Commence la lecture
      // _isLoading sera mis à false par le listener onPlayerStateChanged quand l'état passera à 'playing'
    } catch (e, s) {
      if (kDebugMode) {
        print("[AudioPlayerService ERREUR] Failed to play song ${song.id} from $directAudioUrl");
        print("Erreur: $e");
        print("Trace de la pile:\n$s");
      }
      // Réinitialiser l'état en cas d'erreur
      _playerState = PlayerState.stopped; // Le listener devrait aussi le faire, mais par sécurité
      _isLoading = false;
      _currentSong = null;
      _totalDuration = Duration.zero;
      _currentPosition = Duration.zero;
      _isPlaylistActive = false;
      notifyListeners();
    }
  }

  Future<void> play(Song song) async {
    await _playInternal(song, isFromPlaylist: false);
  }

  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    _playlistSongs = List.from(songs);
    _currentIndexInPlaylist = startIndex.clamp(0, _playlistSongs.length - 1);
    _isPlaylistActive = true;
    await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
  }

  Future<void> pause() async {
    if (isPlaying) { // Utilise le getter isPlaying
      try {
        if (kDebugMode) print("[AudioPlayerService] Pausing song: ${_currentSong?.id}");
        await _audioPlayer.pause();
        // _isLoading reste false, _playerState sera mis à jour par le listener
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to pause: $e");
      }
    }
  }

  Future<void> resume() async {
    if (_currentSong == null) {
      if (kDebugMode) print("[AudioPlayerService] Resume called but no current song.");
      return;
    }

    if (_playerState == PlayerState.paused) {
      try {
        if (kDebugMode) print("[AudioPlayerService] Resuming song: ${_currentSong!.id}");
        // _isLoading pourrait être mis à true ici si la reprise peut prendre du temps (buffering)
        // mais généralement la reprise est rapide. Laisser le listener gérer.
        await _audioPlayer.resume();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to resume: $e");
      }
    } else if (_playerState == PlayerState.stopped || _playerState == PlayerState.completed) {
      if (kDebugMode) print("[AudioPlayerService] Replaying song from start: ${_currentSong!.id}");
      // Si une playlist est active et qu'on est à la fin ou stoppé, rejouer l'élément courant de la playlist
      if (_isPlaylistActive && _currentIndexInPlaylist >= 0 && _currentIndexInPlaylist < _playlistSongs.length) {
        await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
      } else {
        await _playInternal(_currentSong!, isFromPlaylist: _isPlaylistActive); // Si pas de playlist active, rejouer la chanson
      }
    }
  }

  Future<void> stop() async {
    if (kDebugMode) print("[AudioPlayerService] Stopping audio. Current state: $_playerState");
    if (_playerState != PlayerState.stopped) {
      try {
        await _audioPlayer.stop();
        _currentPosition = Duration.zero; // Réinitialiser la position explicitement
        // _isLoading sera mis à false par le listener
        // _playerState sera mis à PlayerState.stopped par le listener
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to stop: $e");
        _playerState = PlayerState.stopped; // Forcer l'état en cas d'erreur
        _isLoading = false;
      }
    }
    // Même si déjà stoppé, s'assurer que les états UI sont corrects
    _isPlaylistActive = false;
    _playlistSongs = [];
    _currentIndexInPlaylist = -1;
    // Si on veut que la chanson disparaisse de l'UI après stop:
    // _currentSong = null;
    // _totalDuration = Duration.zero;
    notifyListeners(); // Notifier pour _currentPosition, _isPlaylistActive etc.
  }

  Future<void> seek(Duration position) async {
    if (_currentSong == null || _totalDuration <= Duration.zero) {
      if (kDebugMode) print("[AudioPlayerService] Seek failed: No current song or unknown duration.");
      return;
    }

    _isSeeking = true; // Empêche onPositionChanged de mettre à jour _currentPosition pendant le seek
    _currentPosition = position.isNegative ? Duration.zero : (position > _totalDuration ? _totalDuration : position);
    notifyListeners(); // Met à jour l'UI du slider pendant que l'utilisateur drag

    try {
      if (kDebugMode) print("[AudioPlayerService] Seeking to: $_currentPosition for song: ${_currentSong!.id}");
      await _audioPlayer.seek(_currentPosition);
    } catch (e) {
      if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to seek: $e");
    } finally {
      // Un petit délai pour s'assurer que le seek est terminé avant de réactiver les mises à jour de position automatiques
      Timer(const Duration(milliseconds: 250), () { // 250ms est une estimation, ajustez si besoin
        _isSeeking = false;
      });
    }
  }

  Future<void> skipNext({bool fromAutoPlay = false}) async {
    if (!_isPlaylistActive || _playlistSongs.isEmpty) {
      if (kDebugMode) print("[AudioPlayerService] SkipNext: No active playlist or playlist empty.");
      return;
    }
    if (_currentIndexInPlaylist < _playlistSongs.length - 1) {
      _currentIndexInPlaylist++;
      if (kDebugMode) print("[AudioPlayerService] Skipping to next song in playlist: index $_currentIndexInPlaylist");
      await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
    } else {
      if (kDebugMode) print("[AudioPlayerService] SkipNext: End of playlist reached.");
      if (!fromAutoPlay) {
        // Optionnel: Arrêter la lecture, ou boucler, ou ne rien faire
        await stop(); // Ou une autre logique comme revenir au début : playPlaylist(_playlistSongs, startIndex: 0);
      } else {
        // Si c'est un autoplay à la fin de la playlist, on peut juste stopper
        await stop();
      }
    }
  }

  Future<void> skipPrevious() async {
    if (!_isPlaylistActive || _playlistSongs.isEmpty) {
      if (kDebugMode) print("[AudioPlayerService] SkipPrevious: No active playlist or playlist empty.");
      return;
    }

    // Si la chanson actuelle a joué plus de X secondes, la redémarrer.
    // Sinon, passer à la chanson précédente dans la playlist.
    const Duration restartThreshold = Duration(seconds: 3);
    if (_currentPosition > restartThreshold && _currentIndexInPlaylist >= 0) {
      if (kDebugMode) print("[AudioPlayerService] Restarting current song in playlist: index $_currentIndexInPlaylist");
      await seek(Duration.zero); // Redémarrer la chanson actuelle
    } else if (_currentIndexInPlaylist > 0) {
      _currentIndexInPlaylist--;
      if (kDebugMode) print("[AudioPlayerService] Skipping to previous song in playlist: index $_currentIndexInPlaylist");
      await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
    } else if (_currentIndexInPlaylist == 0) {
      // Si on est sur la première chanson et qu'on veut la redémarrer (moins de X secondes jouées)
      if (kDebugMode) print("[AudioPlayerService] Restarting first song in playlist: index $_currentIndexInPlaylist");
      await seek(Duration.zero);
    } else {
      if (kDebugMode) print("[AudioPlayerService] SkipPrevious: Already at the beginning or invalid state.");
    }
  }

  void clearCurrentSongAndStop() {
    if (kDebugMode) print("[AudioPlayerService] Clearing current song and stopping player.");
    stop(); // Cela gère déjà la playlist et l'état du lecteur
    _currentSong = null;
    _totalDuration = Duration.zero;
    // _currentPosition est déjà à zéro par stop()
    // _playerState est déjà stopped (ou sera mis à jour par le listener de stop())
    // _isLoading est déjà false (ou sera mis à jour par le listener de stop())
    notifyListeners(); // Notifier pour le changement de _currentSong et _totalDuration
  }

  @override
  void dispose() {
    if (kDebugMode) print("[AudioPlayerService] Disposing AudioPlayerService.");
    _audioPlayer.release(); // Libère les ressources natives
    _audioPlayer.dispose(); // Nettoie l'instance Dart
    super.dispose();
  }
}