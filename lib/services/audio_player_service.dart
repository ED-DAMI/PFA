// lib/services/audio_player_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pfa/services/ApiService.dart';
import 'package:pfa/providers/auth_provider.dart'; // <--- Important

// Pas besoin de Provider.of ici si AuthProvider est injecté
// import 'package:provider/provider.dart';
// import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../models/song.dart';

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _baseUrl = API_BASE_URL;

  Song? _songBeingTrackedForListenDuration;
  DateTime? _listenSegmentStartTime;
  final Duration _minListenDurationThreshold = const Duration(seconds: 5);

  final ApiService apiService;
  final AuthProvider authProvider; // <--- AuthProvider injecté

  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = false;
  bool _isSeeking = false;

  List<Song> _playlistSongs = [];
  int _currentIndexInPlaylist = -1;
  bool _isPlaylistActive = false;

  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isLoading => _isLoading;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get showPlayer => _currentSong != null;
  bool get isActive => _currentSong != null && (_playerState == PlayerState.playing || _playerState == PlayerState.paused);

  AudioPlayerService({
    required this.apiService,
    required this.authProvider, // <--- AuthProvider requis dans le constructeur
  }) {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    _audioPlayer.onPlayerStateChanged.listen((newState) {
      final PlayerState oldPlayerState = _playerState;
      final bool wasLoading = _isLoading;
      final Song? songWhenStateChanged = _currentSong;

      _playerState = newState;

      if (newState == PlayerState.playing ||
          newState == PlayerState.paused ||
          newState == PlayerState.stopped ||
          newState == PlayerState.completed) {
        _isLoading = false;
      }

      if (oldPlayerState == PlayerState.playing && songWhenStateChanged != null) {
        if (newState == PlayerState.paused || newState == PlayerState.stopped || newState == PlayerState.completed) {
          _handleListenSegmentEnd(songWhenStateChanged);
        }
      }

      if (newState == PlayerState.playing && songWhenStateChanged != null) {
        _handleListenSegmentStart(songWhenStateChanged);
      }

      if (newState == PlayerState.completed) {
        _currentPosition = _totalDuration > Duration.zero ? _totalDuration : Duration.zero;
        if (_isPlaylistActive && _currentIndexInPlaylist < _playlistSongs.length - 1) {
          skipNext(fromAutoPlay: true);
        } else {
          _isPlaylistActive = false;
          _currentIndexInPlaylist = -1;
        }
      }

      if (oldPlayerState != _playerState || wasLoading != _isLoading) {
        notifyListeners();
      }
      if (kDebugMode) print("[AudioPlayerService] State Changed: $_playerState, isLoading: $_isLoading, for song ${songWhenStateChanged?.id}");
    }, onError: (msg) {
      if (kDebugMode) print("[AudioPlayerService ERREUR] State Stream: $msg");
      if (_songBeingTrackedForListenDuration != null) {
        _handleListenSegmentEnd(_songBeingTrackedForListenDuration!, isError: true);
      }
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
  }

  void _handleListenSegmentStart(Song song) {
    if (_songBeingTrackedForListenDuration?.id != song.id) {
      if (_songBeingTrackedForListenDuration != null) {
        _handleListenSegmentEnd(_songBeingTrackedForListenDuration!);
      }
      _songBeingTrackedForListenDuration = song;
      _listenSegmentStartTime = DateTime.now();
      if (kDebugMode) print("[AudioPlayerService] Started tracking listen duration for ${song.title}");
    } else if (_listenSegmentStartTime == null) {
      _listenSegmentStartTime = DateTime.now();
      if (kDebugMode) print("[AudioPlayerService] Resumed tracking listen duration for ${song.title}");
    }
  }

  Future<void> _handleListenSegmentEnd(Song song, {bool isError = false}) async {
    if (_listenSegmentStartTime != null && _songBeingTrackedForListenDuration?.id == song.id) {
      final segmentDuration = DateTime.now().difference(_listenSegmentStartTime!);
      _listenSegmentStartTime = null;

      if (kDebugMode) print("[AudioPlayerService] Ended listen segment for ${song.title}. Duration: ${segmentDuration.inSeconds}s. Error: $isError");

      if (!authProvider.isAuthenticated) {
        if (kDebugMode) print("[AudioPlayerService] User not authenticated. Skipping listen duration track.");
        return;
      }

      final String? authToken = authProvider.token;
      if (authToken == null) {
        if (kDebugMode) print("[AudioPlayerService] Auth token not available. Skipping listen duration track.");
        return;
      }

      if (!isError && segmentDuration > _minListenDurationThreshold) {
        try {
          await apiService.trackSongListenDuration(
            songId: song.id,
            durationListenedSeconds: segmentDuration.inSeconds,
            authToken: authToken, // <--- Utilisation du vrai token
          );
        } catch (e) {
          if (kDebugMode) print("[AudioPlayerService] Failed to send listen duration: $e");
        }
      } else if (segmentDuration <= _minListenDurationThreshold) {
        if (kDebugMode) print("[AudioPlayerService] Listen duration for ${song.title} below threshold (${_minListenDurationThreshold.inSeconds}s). Not tracking.");
      }
    }
  }

  Future<void> _playInternal(Song song, {bool isFromPlaylist = false}) async {
    if (_currentSong != null && _currentSong!.id != song.id) {
      _handleListenSegmentEnd(_currentSong!);
    }

    if (_isLoading && _currentSong?.id == song.id) {
      return;
    }
    if (_currentSong?.id == song.id && _playerState == PlayerState.paused) {
      await resume();
      return;
    }
    if (_playerState != PlayerState.stopped && _playerState != PlayerState.completed) {
      await _audioPlayer.stop();
    }

    _currentSong = song;
    _isLoading = true;
    _currentPosition = Duration.zero;
    _totalDuration = song.duration != null ? Duration(seconds: song.duration!) : Duration.zero;

    if (!isFromPlaylist) {
      _isPlaylistActive = false;
      _playlistSongs = [];
      _currentIndexInPlaylist = -1;
    }
    notifyListeners();

    final String directAudioUrl = '$_baseUrl/api/songs/${song.id}/audio';
    try {
      await _audioPlayer.setSource(UrlSource(directAudioUrl));
      await _audioPlayer.resume();
    } catch (e, s) {
      if (kDebugMode) {
        print("[AudioPlayerService ERREUR] Failed to play song ${song.id} from $directAudioUrl");
        print("Erreur: $e");
        print("Trace de la pile:\n$s");
      }
      if (_songBeingTrackedForListenDuration?.id == song.id) {
        _handleListenSegmentEnd(song, isError: true);
      }
      _playerState = PlayerState.stopped;
      _isLoading = false;
      _currentSong = null;
      _totalDuration = Duration.zero;
      _currentPosition = Duration.zero;
      _isPlaylistActive = false;
      _songBeingTrackedForListenDuration = null;
      _listenSegmentStartTime = null;
      notifyListeners();
    }
  }

  Future<void> play(Song song) async {
    await _playInternal(song, isFromPlaylist: false);
  }

  Future<void> playPlaylist(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    if (_currentSong != null && (!_isPlaylistActive || _playlistSongs.isEmpty || _playlistSongs.firstWhere((s) => s.id == _currentSong!.id, orElse: () => Song.empty()).id != songs.firstWhere((s) => s.id == _currentSong!.id, orElse: () => Song.empty()).id )) {
      // Compare based on some property if the lists themselves are different, or if currentSong is not in the new list.
      // A simpler check might be if _currentSong is not null and is different from songs[startIndex]
      _handleListenSegmentEnd(_currentSong!);
    }

    _playlistSongs = List.from(songs);
    _currentIndexInPlaylist = startIndex.clamp(0, _playlistSongs.length - 1);
    _isPlaylistActive = true;
    await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
  }

  Future<void> pause() async {
    if (isPlaying && _currentSong != null) {
      try {
        await _audioPlayer.pause();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to pause: $e");
      }
    }
  }

  Future<void> resume() async {
    if (_currentSong == null) return;
    if (_playerState == PlayerState.paused) {
      try {
        await _audioPlayer.resume();
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to resume: $e");
      }
    } else if (_playerState == PlayerState.stopped || _playerState == PlayerState.completed) {
      if (_isPlaylistActive && _currentIndexInPlaylist >= 0 && _currentIndexInPlaylist < _playlistSongs.length) {
        await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
      } else {
        await _playInternal(_currentSong!, isFromPlaylist: _isPlaylistActive);
      }
    }
  }

  Future<void> stop() async {
    if (_currentSong != null && _playerState != PlayerState.stopped) {
      // _handleListenSegmentEnd est appelé via onPlayerStateChanged
    }
    if (_playerState != PlayerState.stopped) {
      try {
        await _audioPlayer.stop();
        _currentPosition = Duration.zero;
      } catch (e) {
        if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to stop: $e");
        _playerState = PlayerState.stopped;
        _isLoading = false;
      }
    }
    _isPlaylistActive = false;
    _songBeingTrackedForListenDuration = null;
    _listenSegmentStartTime = null;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (_currentSong == null || _totalDuration <= Duration.zero) return;
    _isSeeking = true;
    _currentPosition = position.isNegative ? Duration.zero : (position > _totalDuration ? _totalDuration : position);
    notifyListeners();
    try {
      await _audioPlayer.seek(_currentPosition);
    } catch (e) {
      if (kDebugMode) print("[AudioPlayerService ERREUR] Failed to seek: $e");
    } finally {
      Timer(const Duration(milliseconds: 250), () { _isSeeking = false; });
    }
  }

  Future<void> skipNext({bool fromAutoPlay = false}) async {
    if (!_isPlaylistActive || _playlistSongs.isEmpty) return;
    if (_currentIndexInPlaylist < _playlistSongs.length - 1) {
      _currentIndexInPlaylist++;
      await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
    } else {
      if (_currentSong != null) {
        _handleListenSegmentEnd(_currentSong!);
      }
      if (!fromAutoPlay) await stop();
      else await stop();
      _songBeingTrackedForListenDuration = null;
      _listenSegmentStartTime = null;
    }
  }

  Future<void> skipPrevious() async {
    if (!_isPlaylistActive || _playlistSongs.isEmpty) return;
    const Duration restartThreshold = Duration(seconds: 3);
    if (_currentPosition > restartThreshold && _currentIndexInPlaylist >= 0) {
      await seek(Duration.zero);
    } else if (_currentIndexInPlaylist > 0) {
      _currentIndexInPlaylist--;
      await _playInternal(_playlistSongs[_currentIndexInPlaylist], isFromPlaylist: true);
    } else if (_currentIndexInPlaylist == 0) {
      await seek(Duration.zero);
    }
  }

  void clearCurrentSongAndStop() {
    if (_currentSong != null) {
      _handleListenSegmentEnd(_currentSong!);
    }
    stop();
    _currentSong = null;
    _totalDuration = Duration.zero;
    _songBeingTrackedForListenDuration = null;
    _listenSegmentStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_songBeingTrackedForListenDuration != null) {
      _handleListenSegmentEnd(_songBeingTrackedForListenDuration!, isError: true);
    }
    _audioPlayer.release();
    _audioPlayer.dispose();
    super.dispose();
  }
}