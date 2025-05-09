// lib/services/audio_player_service.dart
import 'dart:async'; // Pour debounce potentiel (non implémenté ici)
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/api_config.dart';
import '../models/song.dart'; // Vérifiez le chemin

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _baseUrl; // URL de base du backend (ex: "http://192.168.1.125:8080")

  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;
  bool _isSeeking = false; // Pour éviter conflits entre seek et position updates

  // Getters
  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isLoading => _isLoading;
  bool get isPlaying => _playerState == PlayerState.playing;

  // Constructeur injectant l'URL de base
  AudioPlayerService() : _baseUrl =API_BASE_URL {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      final wasLoading = _isLoading;
      _playerState = state;
      if (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.stopped || state == PlayerState.completed) {
        _isLoading = false; // Arrêter le chargement
      }
      if (state == PlayerState.completed) {
        _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero; // Aller à la fin
      }
      if (wasLoading != _isLoading || state == PlayerState.completed || state == PlayerState.stopped) {
        notifyListeners(); // Notifier si chargement terminé ou état final atteint
      }
    }, onError: (Object error, StackTrace stackTrace) {
      print("[AudioPlayerService ERROR] State Stream Error: $error\n$stackTrace");
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      // Mettre à jour seulement si la durée change et est valide
      if (duration > Duration.zero && _totalDuration != duration) {
        print("[AudioPlayerService] Duration changed: $duration");
        _totalDuration = duration;
        notifyListeners();
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      // Mettre à jour la position seulement si pas en cours de seek manuel
      if (!_isSeeking && _currentPosition != position) {
        _currentPosition = position;
        notifyListeners();
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      print("[AudioPlayerService] Player Complete for song: ${_currentSong?.id}");
      // L'état et la position sont gérés par les autres listeners
      // On peut notifier une dernière fois pour s'assurer
      notifyListeners();
    });

    // Écouteur spécifique pour les erreurs de lecture/source
    _audioPlayer.eventStream.listen((event) {
      // Cet écouteur peut donner des détails spécifiques sur les erreurs
      // mais onPlayerStateChanged avec onError est souvent suffisant.
    }, onError: (Object error) {
      print("[AudioPlayerService ERROR] Player Event Stream Error: $error");
      // Gérer comme l'erreur de onPlayerStateChanged
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
      notifyListeners();
    });
  }

  Future<void> play(Song song) async {
    if (_isLoading && _currentSong?.id == song.id) return; // Déjà en cours de chargement

    // Si la même chanson est juste en pause, reprendre
    if (_currentSong?.id == song.id && _playerState == PlayerState.paused) {
      await resume();
      return;
    }

    // Arrêter la lecture précédente si elle existe
    await stop();

    _currentSong = song;
    _isLoading = true;
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero; // La vraie durée viendra de onDurationChanged
    notifyListeners(); // Afficher le chargement et la nouvelle chanson

    final String directAudioUrl = '$_baseUrl/api/songs/${song.id}/audio';
    print("[AudioPlayerService] Attempting to play from: $directAudioUrl");

    try {

      // ****************** AVERTISSEMENT DE SÉCURITÉ MAJEUR ******************
      // audioplayers via UrlSource NE PEUT PAS envoyer de headers 'Authorization'.
      // Votre endpoint backend `GET /api/songs/{id}/audio` DOIT être accessible
      // SANS token pour que ceci fonctionne.
      // Alternatives si sécurité par token requise:
      // 1. URLs Signées (backend génère URL temporaire sécurisée sans header).
      // 2. Téléchargement complet via http (avec header) puis jouer le fichier/bytes.
      // ***********************************************************************
      await _audioPlayer.setSource(UrlSource(directAudioUrl)); // Préparer la source
      await _audioPlayer.resume(); // Démarrer la lecture (resume démarre si pas déjà joué)
      // isLoading deviendra false via onPlayerStateChanged

    } catch (e, s) {
      print("[AudioPlayerService ERROR] Failed to play song ${song.id} from $directAudioUrl");
      print("Error: $e");
      print("Stack Trace:\n$s");
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _totalDuration = Duration.zero;
      notifyListeners();

    }
  }

  Future<void> pause() async {
    if (isPlaying) {
      try {
        await _audioPlayer.pause();
        // État mis à jour par listener
      } catch (e) {
        print("[AudioPlayerService ERROR] Pausing failed: $e");
      }
    }
  }

  Future<void> resume() async {
    if (_currentSong != null && _playerState == PlayerState.paused) {
      try {
        await _audioPlayer.resume();
        // État mis à jour par listener
      } catch (e) {
        print("[AudioPlayerService ERROR] Resuming failed: $e");
      }
    } else if (_currentSong != null && (_playerState == PlayerState.stopped || _playerState == PlayerState.completed)) {
      // Si arrêtée ou complétée, relancer la lecture depuis le début
      await play(_currentSong!);
    }
  }

  Future<void> stop() async {
    // Vérifier si le player est dans un état où stop() a un sens
    if (_playerState == PlayerState.playing || _playerState == PlayerState.paused || _isLoading ) {
      try {
        print("[AudioPlayerService] Stopping player for song: ${_currentSong?.id}");
        await _audioPlayer.stop();
        // L'état sera mis à jour par le listener, mais on force un état propre ici
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero; // Réinitialiser la durée
        _isLoading = false;
        _playerState = PlayerState.stopped; // Forcer état
        // Optionnel : remettre _currentSong à null si on veut vider NowPlayingScreen
        // _currentSong = null;
        notifyListeners();
      } catch (e) {
        print("[AudioPlayerService ERROR] Stopping failed: $e");
        // Assurer un état propre même en cas d'erreur
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _isLoading = false;
        _playerState = PlayerState.stopped;
        notifyListeners();
      }
    } else {
      // Si déjà arrêté/complété/initial, s'assurer que tout est à zéro
      bool needsNotify = false;
      if (_currentPosition != Duration.zero) { _currentPosition = Duration.zero; needsNotify = true; }
      if (_totalDuration != Duration.zero) { _totalDuration = Duration.zero; needsNotify = true; }
      if (_isLoading) { _isLoading = false; needsNotify = true; }
      if (_playerState != PlayerState.stopped) { _playerState = PlayerState.stopped; needsNotify = true; }
      if (needsNotify) {
        notifyListeners();
      }
    }
  }

  Future<void> seek(Duration position) async {
    if (_currentSong == null || _totalDuration <= Duration.zero) {
      print("[AudioPlayerService] Cannot seek: No song or duration unknown.");
      return; // Ne peut pas seek si pas de chanson ou durée inconnue
    }

    final seekPosition = position.isNegative ? Duration.zero :
    (position > _totalDuration ? _totalDuration : position);

    if (_playerState == PlayerState.playing || _playerState == PlayerState.paused) {
      _isSeeking = true; // Marquer le début du seek manuel
      try {
        print("[AudioPlayerService] Seeking to: $seekPosition");
        await _audioPlayer.seek(seekPosition);
        // Mettre à jour la position immédiatement pour la réactivité de l'UI
        // avant que le listener onPositionChanged ne le fasse.
        _currentPosition = seekPosition;
        notifyListeners();
      } catch (e) {
        print("[AudioPlayerService ERROR] Seeking failed: $e");
      } finally {
        // S'assurer que _isSeeking redevient false après un court délai
        // pour permettre au listener de reprendre la main sans conflit.
        await Future.delayed(const Duration(milliseconds: 200));
        _isSeeking = false;
      }
    } else {
      print("[AudioPlayerService] Cannot seek in state: $_playerState");
    }
  }

  @override
  void dispose() {
    print("[AudioPlayerService] Disposing AudioPlayerService.");
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}