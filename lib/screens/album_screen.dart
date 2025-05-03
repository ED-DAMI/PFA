import 'package:flutter/material.dart';

class AlbumScreen extends StatelessWidget {
  final String albumId; // Pass the album ID to fetch data

  const AlbumScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch album details using albumId
    // TODO: Display tracklist, allow playing album, add to playlist

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Album'), // Replace with actual album name later
      ),
      body: Center(
        child: Text(
          'Album Screen Placeholder\n(ID: $albumId)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}