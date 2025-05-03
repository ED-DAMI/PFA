import 'package:flutter/material.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture en cours'),
        backgroundColor: Colors.transparent, // Make AppBar blend with background potentially
        elevation: 0,
      ),
      // Extend body behind app bar for full-screen feel
      extendBodyBehindAppBar: true,
      body: Container(
        // Placeholder dynamic background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade300, Colors.blue.shade800],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Now Playing Screen Placeholder',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Icon(Icons.play_circle_fill, size: 100, color: Colors.white70,)
            ],
          ),
        ),
      ),
    );
  }
}