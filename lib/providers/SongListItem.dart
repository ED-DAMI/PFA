import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/song.dart'; // Your Song model

class SongListItem extends StatefulWidget {
  final Song song;

  const SongListItem({Key? key, required this.song}) : super(key: key);

  @override
  _SongListItemState createState() => _SongListItemState();
}

class _SongListItemState extends State<SongListItem> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PlayerState? _playerState;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _playerState = state;
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    // Optional: Listen for when audio completes
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playerState = PlayerState.completed;
        });
      }
    });

    // Optional: Listen for errors
    _audioPlayer.onPlayerError.listen((msg) {
      print('Audio Player Error: $msg');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          // Handle the error, maybe show a message
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Release resources
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      // Ensure urlAudio is a valid URL
      if (widget.song.urlAudio.isNotEmpty) {
        try {
          await _audioPlayer.play(UrlSource(widget.song.urlAudio));
        } catch (e) {
          print("Error playing audio: $e");
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur de lecture: ${e.toString()}'))
          );
        }
      } else {
        print("Error: Audio URL is empty for song ${widget.song.title}");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL audio manquante'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: widget.song.coverImage != null
          ? Image.network(widget.song.coverImage!, width: 50, height: 50, fit: BoxFit.cover)
          : const Icon(Icons.music_note, size: 50),
      title: Text(widget.song.title),
      // subtitle: Text(widget.song.artistId), // You'll likely want to fetch Artist details
      trailing: IconButton(
        icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        iconSize: 40.0,
        onPressed: _playPause,
      ),
      onTap: _playPause, // Allow tapping the whole item to play/pause
    );
  }
}

extension on AudioPlayer {
  get onPlayerError => null;
}