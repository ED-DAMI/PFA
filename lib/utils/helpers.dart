import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Assurez-vous d'avoir intl dans pubspec.yaml
// Si vous utilisez 'fr_FR' pour DateFormat, vous pourriez avoir besoin de l'initialisation:
// import 'package:intl/date_symbol_data_local.dart'; // Pour initializeDateFormatting

// Formatter la durée en mm:ss
String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  int totalSeconds = d.inSeconds;
  int minutes = totalSeconds ~/ 60;
  int seconds = totalSeconds % 60;
  // padLeft assure que si minutes ou secondes est < 10, il est préfixé par '0'
  return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
}

// Formatter une date (exemple simple)
// Pour que 'fr_FR' fonctionne correctement, vous devez initialiser les données de formatage de date.
// Appelez `await initializeDateFormatting('fr_FR', null);` dans votre `main()` async.
String formatDate(DateTime? date, {String locale = 'fr_FR'}) {
  if (date == null) return 'N/A';
  try {
    return DateFormat('dd MMM yyyy', locale).format(date);
  } catch (e) {
    // Fallback si la locale n'est pas initialisée ou supportée
    print("Erreur de formatage de date pour la locale '$locale': $e. Utilisation du format par défaut.");
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

// Afficher un SnackBar
// Dans utils/helpers.dart
void showAppSnackBar(
    BuildContext context,
    String message, {
      bool isError = false,
      Duration duration = const Duration(seconds: 3),
      Color? backgroundColor, // Ajoutez ce paramètre
    }) {
  if (!ScaffoldMessenger.of(context).mounted) return;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();

  Color? finalSnackBarBackgroundColor;
  if (backgroundColor != null) { // Priorité au paramètre explicite
    finalSnackBarBackgroundColor = backgroundColor;
  } else if (isError) {
    finalSnackBarBackgroundColor = Theme.of(context).colorScheme.error;
  } else {
    finalSnackBarBackgroundColor = Theme.of(context).snackBarTheme.backgroundColor;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: finalSnackBarBackgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
  );
}

// Obtenir une couleur de contraste pour un fond.
// Cette fonction est correctement définie avec un paramètre positionnel `backgroundColor`.
// Si l'erreur "The named parameter 'backgroundColor' isn't defined"
// se produit lorsque vous appelez CETTE fonction, cela signifie que vous l'appelez
// avec un paramètre nommé, par exemple : getContrastingTextColor(backgroundColor: Colors.blue);
// Au lieu de : getContrastingTextColor(Colors.blue);
Color getContrastingTextColor(Color backgroundColor) {
  // Calcul simple de la luminance. Une valeur > 0.5 est considérée comme claire.
  // La formule exacte de la luminance relative est plus complexe, mais c'est une approximation courante.
  double luminance = backgroundColor.computeLuminance();
  return luminance > 0.5 ? Colors.black : Colors.white;
}

// Exemple d'utilisation de initializeDateFormatting dans main.dart:
/*
// Dans main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import pour l'initialisation

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Nécessaire si main est async avant runApp

  // Initialiser les données de formatage pour le français
  await initializeDateFormatting('fr_FR', null);
  // Vous pouvez en initialiser d'autres si besoin:
  // await initializeDateFormatting('en_US', null);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // ...
}
*/