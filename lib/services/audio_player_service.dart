// lib/services/audio_player_service.dart
import 'dart:async'; // Pour Timer dans seek
import 'package:flutter/foundation.dart'; // Pour kDebugMode et ChangeNotifier
import 'package:audioplayers/audioplayers.dart';
import 'package:pfa/providers/auth_provider.dart';
import 'package:pfa/services/ApiService.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart'; // Assurez-vous qu'API_BASE_URL est défini ici
import '../models/song.dart';     // Vérifiez le chemin vers votre modèle Song

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _baseUrl; // URL de base de votre backend (ex: "http://192.168.1.125:8080")
  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;
  bool _isSeeking = false; // Pour éviter les conflits entre la recherche manuelle (seek) et les mises à jour de position automatiques


  // Getters (Accesseurs) - Noms conservés pour compatibilité
  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isLoading => _isLoading;
  bool get isPlaying => _playerState == PlayerState.playing; // Reste 'isPlaying'
  bool get showPlayer =>true;
  /// Retourne vrai si une chanson est chargée et est actuellement en lecture ou en pause.
  /// Utile pour déterminer si le MiniPlayer ou l'écran "En Lecture" doit être actif.
  /// Conservé sous le nom 'isActive' pour la discussion, mais vous pouvez le renommer si un autre nom était utilisé.
  bool get isActive =>
      _currentSong != null &&
          (_playerState == PlayerState.playing || _playerState == PlayerState.paused);

  // Constructeur injectant l'URL de base
  AudioPlayerService() : _baseUrl = API_BASE_URL {

    _initAudioPlayer();
  }



  void _initAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);


    _audioPlayer.onPlayerStateChanged.listen((newState) {
      final PlayerState oldPlayerState = _playerState;
      final bool wasLoading = _isLoading;

      _playerState = newState;

      if (kDebugMode) {
        print("[AudioPlayerService] Changement d'état: $oldPlayerState -> $newState. Chanson: ${_currentSong?.id}");
      }

      if (newState == PlayerState.playing ||
          newState == PlayerState.paused ||
          newState == PlayerState.stopped ||
          newState == PlayerState.completed) {
        _isLoading = false;
      }

      if (newState == PlayerState.completed) {
        _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero;
      }

      if (oldPlayerState != _playerState || wasLoading != _isLoading) {
        notifyListeners();
      }
    }, onError: (Object error, StackTrace trace) {
      if (kDebugMode) {
        print("[AudioPlayerService ERREUR] Stream d'état: $error\n$trace");
      }
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (duration > Duration.zero && _totalDuration != duration) {
        if (kDebugMode) {
          print("[AudioPlayerService] Durée changée: $duration pour la chanson: ${_currentSong?.id}");
        }
        _totalDuration = duration;
        notifyListeners();
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!_isSeeking && _currentSong != null && _currentPosition != position) {
        _currentPosition = (position > _totalDuration && _totalDuration > Duration.zero) ? _totalDuration : position;
        notifyListeners();
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (kDebugMode) {
        print("[AudioPlayerService] Événement Player Complete pour la chanson: ${_currentSong?.id}");
      }
    });

    _audioPlayer.eventStream.listen((event) {
    }, onError: (Object error) {
      if (kDebugMode) {
        print("[AudioPlayerService ERREUR] Stream d'événements Lecteur: $error");
      }
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    });
  }

  // Nom de méthode conservé: play
  Future<void> play(Song song) async {

    if (_isLoading && _currentSong?.id == song.id) {
      if (kDebugMode) print("[AudioPlayerService] play() appelée pour ${song.id}, mais déjà en chargement.");
      return;
    }

    if (_currentSong?.id == song.id && _playerState == PlayerState.paused) {
      if (kDebugMode) print("[AudioPlayerService] Reprise de la chanson en pause: ${song.id}");
      await resume(); // Appel à resume()
      return;
    }

    if (kDebugMode) print("[AudioPlayerService] Tentative de lecture d'une nouvelle chanson: ${song.title} (ID: ${song.id})");

    if (_playerState != PlayerState.stopped && _playerState != PlayerState.completed) {
      await _audioPlayer.stop();
    }

    _currentSong = song;
    _isLoading = true;
    _currentPosition = Duration.zero;
    _totalDuration = song.duration != null ? Duration(seconds: song.duration!) : Duration.zero;
    notifyListeners();

    final String directAudioUrl = '$_baseUrl/api/songs/${song.id}/audio';
    if (kDebugMode) print("[AudioPlayerService] URL de la source: $directAudioUrl");

    try {
      // ****************** AVERTISSEMENT DE SÉCURITÉ MAJEUR ******************
      // (Commentaire original conservé)
      // ***********************************************************************
      await _audioPlayer.setSource(UrlSource(directAudioUrl));
      await _audioPlayer.resume();

    } catch (e, s) {
      if (kDebugMode) {
        print("[AudioPlayerService ERREUR] Échec de lecture de la chanson ${song.id} depuis $directAudioUrl");
        print("Erreur: $e");
        print("Trace de la pile:\n$s");
      }
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _totalDuration = Duration.zero;
      _currentPosition = Duration.zero;
      notifyListeners();
    }
  }

  // Nom de méthode conservé: pause
  Future<void> pause() async {
    if (isPlaying) { // Utilise le getter isPlaying
      try {
        if (kDebugMode) print("[AudioPlayerService] Mise en pause de la chanson: ${_currentSong?.id}");
        await _audioPlayer.pause();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Échec de la mise en pause: $e");
      }
    }
  }

  // Nom de méthode conservé: resume
  Future<void> resume() async {
    if (_currentSong == null) {
      if (kDebugMode) print("[AudioPlayerService] resume() appelée mais pas de chanson actuelle.");
      return;
    }

    if (_playerState == PlayerState.paused) {
      try {
        if (kDebugMode) print("[AudioPlayerService] Reprise de la lecture de: ${_currentSong!.id}");
        await _audioPlayer.resume();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Échec de la reprise: $e");
      }
    } else if (_playerState == PlayerState.stopped || _playerState == PlayerState.completed) {
      if (kDebugMode) print("[AudioPlayerService] Relecture de la chanson depuis le début: ${_currentSong!.id}");
      await play(_currentSong!); // Appel à play()
    } else {
      if (kDebugMode) print("[AudioPlayerService] resume() appelée dans un état inapproprié: $_playerState");
    }
  }

  // Nom de méthode conservé: stop
  Future<void> stop() async {
    if (kDebugMode) print("[AudioPlayerService] stop() appelée. État actuel: $_playerState, Chanson: ${_currentSong?.id}");
    if (_playerState != PlayerState.stopped && _playerState != PlayerState.completed ) {
      try {
        await _audioPlayer.stop();
        _currentPosition = Duration.zero;
        _isLoading = false;
        _playerState = PlayerState.stopped;
        // La décision de mettre _currentSong à null ici dépend de votre logique UI.
        // Si vous voulez que MiniPlayer disparaisse immédiatement, mettez _currentSong = null;
        // _currentSong = null;
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Échec de l'arrêt: $e");
        _playerState = PlayerState.stopped;
        _isLoading = false;
        _currentPosition = Duration.zero;
        notifyListeners();
      }
    } else {
      bool needsNotify = false;
      if (_isLoading) { _isLoading = false; needsNotify = true; }
      if (_currentPosition != Duration.zero) { _currentPosition = Duration.zero; needsNotify = true; }
      if (needsNotify) {
        notifyListeners();
      }
    }
  }

  // Nom de méthode conservé: seek
  Future<void> seek(Duration position) async { // 'position' est le nom original du paramètre
    if (_currentSong == null || _totalDuration <= Duration.zero) {
      if (kDebugMode) print("[AudioPlayerService] Impossible de rechercher: Pas de chanson ou durée inconnue.");
      return;
    }

    final Duration seekPosition = position.isNegative ? Duration.zero :
    (position > _totalDuration ? _totalDuration : position);

    if (_playerState == PlayerState.playing || _playerState == PlayerState.paused) {
      _isSeeking = true; // Utilisation de _isSeeking
      _currentPosition = seekPosition;
      notifyListeners();

      try {
        if (kDebugMode) print("[AudioPlayerService] Recherche vers: $seekPosition pour la chanson: ${_currentSong!.id}");
        await _audioPlayer.seek(seekPosition);
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Échec de la recherche: $e");
        _isSeeking = false;
      } finally {
        Timer(const Duration(milliseconds: 250), () {
          _isSeeking = false;
        });
      }
    } else {
      if (kDebugMode) print("[AudioPlayerService] Impossible de rechercher dans l'état: $_playerState");
    }
  }

  /// Optionnel: Si vous aviez une méthode pour explicitement vider la chanson.
  /// Sinon, `stop()` peut suffire et vous gérez la nullité de `currentSong` dans l'UI.
  void clearCurrentSongAndStop() { // Nom de méthode suggéré si besoin
    if (_currentSong != null) {
      stop(); // Appel à stop()
      _currentSong = null;
      _totalDuration = Duration.zero;
      // _currentPosition est déjà à zéro par stop()
      // _playerState est déjà stopped par stop()
      // _isLoading est déjà false par stop()
      notifyListeners(); // Notifier pour le changement de _currentSong
      if (kDebugMode) print("[AudioPlayerService] Chanson actuelle vidée et lecture arrêtée.");
    }
  }

  @override
  void dispose() {
    if (kDebugMode) print("[AudioPlayerService] Libération des ressources de AudioPlayerService.");
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}