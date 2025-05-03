import 'package:flutter/material.dart';
import 'package:pfa/services/APIservice.dart';
import 'package:provider/provider.dart'; // Importer Provider

// Importer les Providers
import 'providers/auth_provider.dart';
import 'providers/PlaylistProvider.dart';
import 'providers/home_provider.dart'; // Assurez-vous que ce fichier existe



// Importer les Écrans
import 'screens/auth_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';

void main() {

  final apiService = ApiService();

  runApp(
    // Utiliser MultiProvider pour fournir tous les providers nécessaires
    MultiProvider(
      providers: [
        // Fournir AuthProvider (qui dépend de ApiService)
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiService),
        ),
        // Fournir PlaylistProvider (qui dépend de ApiService et AuthProvider)
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (context) => PlaylistProvider(
              apiService, Provider.of<AuthProvider>(context, listen: false)),
          update: (_, auth, previousPlaylistProvider) =>
              PlaylistProvider(apiService, auth), // Passe l'instance auth mise à jour
        ),
        // Fournir HomeProvider (qui dépend de ApiService et optionnellement AuthProvider)
        ChangeNotifierProxyProvider<AuthProvider, HomeProvider>(
          create: (context) => HomeProvider(
              apiService, Provider.of<AuthProvider>(context, listen: false)),
          update: (_, auth, previousHomeProvider) =>
              HomeProvider(apiService, auth), // Passe l'instance auth mise à jour
        ),
        // Ajoutez d'autres providers ici si nécessaire (ex: PlayerProvider)
      ],
      child: const MyApp(), // L'application principale
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Écouter AuthProvider pour déterminer l'écran initial
    final authProvider = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'Flutter Music App',
      debugShowCheckedModeBanner: false, // Optionnel: cache le bandeau debug
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[50],
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed, // Assure la visibilité des labels
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,

      ),
      themeMode: ThemeMode.system,

      // Logique pour l'écran de démarrage :
      // Si l'utilisateur est authentifié, afficher MainScreen, sinon AuthScreen.
      home: authProvider.isAuthenticated ? const MainScreen() : const AuthScreen(),

      // Définir les routes nommées pour la navigation secondaire
      routes: {
        // Note: '/home' pointe vers MainScreen, cohérent avec la logique 'home:' ci-dessus
        '/home': (context) => const MainScreen(),
        '/auth': (context) => const AuthScreen(),
        '/settings': (context) => const SettingsScreen(),
        },
      // Gérer les routes inconnues pour éviter les crashs
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Erreur')),
              body: Center(child: Text('Route non trouvée: ${settings.name}')),
            )
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {

    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Définir la liste des widgets ICI
    // Enlevez 'const' devant les écrans qui utilisent Provider.of dans leur build()
    final List<Widget> widgetOptions = <Widget>[
      HomeScreen(),      // Probablement besoin de Provider.of<HomeProvider> -> pas const
      SearchScreen(),    // Probablement besoin de rechercher -> pas const si StatefulWidget
      LibraryScreen(),   // Probablement besoin de Provider.of<PlaylistProvider> -> pas const
      ProfileScreen(),   // Certainement besoin de Provider.of<AuthProvider> -> pas const
    ];

    return Scaffold(
      // Utiliser IndexedStack pour préserver l'état des écrans lors du changement d'onglet
      body: IndexedStack(
        index: _selectedIndex,
        children: widgetOptions,
      ),
      // Alternative (plus simple, mais reconstruit l'écran à chaque fois) :
      // body: Center(
      //   child: widgetOptions.elementAt(_selectedIndex),
      // ),

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Recherche',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_outlined),
            activeIcon: Icon(Icons.library_music),
            label: 'Bibliothèque',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        // Le type et les couleurs sont hérités du thème défini dans MaterialApp
        // type: BottomNavigationBarType.fixed,
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // unselectedItemColor: Colors.grey,
      ),
    );
  }
}