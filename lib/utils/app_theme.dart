import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.deepPurple, // Ou une autre couleur principale
    // primaryColor: Colors.deepPurple, // Plus spécifique
    scaffoldBackgroundColor: Colors.grey[100],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white, // Couleur du texte et des icônes dans l'AppBar
      elevation: 4.0,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
      labelSmall: TextStyle(fontSize: 12, color: Colors.grey[600]),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.deepPurple, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.deepPurple.withOpacity(0.1),
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(color: Colors.deepPurple[700]),
      secondaryLabelStyle: const TextStyle(color: Colors.white), // Pour le texte quand selected
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    ),
    // Autres customisations...
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.teal,
    // primaryColor: Colors.teal,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
      elevation: 4.0,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
      labelSmall: TextStyle(fontSize: 12, color: Colors.grey[400]),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.teal, width: 2.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      hintStyle: TextStyle(color: Colors.grey[500]),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.teal.withOpacity(0.2),
      selectedColor: Colors.teal,
      labelStyle: TextStyle(color: Colors.teal[200]),
      secondaryLabelStyle: const TextStyle(color: Colors.black),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    ),
    // Autres customisations...
  );
}