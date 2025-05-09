import 'package:flutter/material.dart';
import 'package:intl/intl.dart';// Ajoutez intl: ^0.18.0 ou plus récent à pubspec.yaml

// Formatter la durée en mm:ss
String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  int totalSeconds = d.inSeconds;
  int minutes = totalSeconds ~/ 60;
  int seconds = totalSeconds % 60;
  return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
}

// Formatter une date (exemple simple)
String formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  return DateFormat('dd MMM yyyy', 'fr_FR').format(date); // 'fr_FR' pour le format français
  // Assurez-vous d'initialiser la localisation pour intl si nécessaire dans main.dart
  // await initializeDateFormatting('fr_FR', null);
}

// Afficher un SnackBar
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Cacher le précédent
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).snackBarTheme.backgroundColor,
      duration: const Duration(seconds: 3),
    ),
  );
}

// Obtenir une couleur de contraste pour un fond
Color getContrastingTextColor(Color backgroundColor) {
  // Simple calcul de luminance
  return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}