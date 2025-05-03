import 'package:flutter/material.dart';

class ArtistScreen extends StatelessWidget {
  final String artistId; // Pass the artist ID to fetch data

  const ArtistScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context) {
    // TODO: Fetch artist details using artistId
    // TODO: Display bio, popular tracks, albums

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Artiste'), // Replace with actual artist name later
      ),
      body: Center(
        child: Text(
          'Artist Screen Placeholder\n(ID: $artistId)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}