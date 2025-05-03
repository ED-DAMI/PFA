// lib/services/api_service.dart
import 'dart:convert'; // Pour jsonEncode/Decode
import 'dart:io'; // Pour File (upload)
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Pour MediaType (upload)

// Assurez-vous que ces chemins sont corrects
import '../config/api_config.dart'; // Votre URL de base
import '../models/playlist.dart'; // Doit contenir Playlist.fromJson
import '../models/song.dart';     // Doit contenir Song.fromJson
// Importez d'autres modèles si nécessaire (User, Artist, Album...)

class ApiService {

  // Helper pour gérer les réponses communes et les erreurs
  dynamic _handleResponse(http.Response response) {
    final String responseBody = utf8.decode(response.bodyBytes); // Gère les caractères spéciaux (accents, etc.)

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty || response.statusCode == 204) {
        // 204 No Content ou corps vide pour succès
        return null;
      }
      try {
        // Tenter de décoder le JSON
        return jsonDecode(responseBody);
      } catch (e) {
        print("Erreur de décodage JSON: $e");
        print("Corps de la réponse: $responseBody");
        // Si le décodage échoue mais que c'est un succès (2xx),
        // retourner le corps brut peut être une option selon l'API,
        // mais lever une exception est plus sûr par défaut.
        throw Exception('Réponse invalide depuis le serveur (JSON mal formé)');
      }
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      print('Erreur ${response.statusCode}: Non autorisé ou Interdit.');
      print('Réponse: $responseBody');
      // Tenter de décoder un message d'erreur du backend
      String message = 'Authentification requise ou accès refusé (${response.statusCode})';
      try {
        final errorJson = jsonDecode(responseBody);
        if (errorJson is Map && errorJson.containsKey('message')) {
          message = errorJson['message'];
        }
      } catch (_) {} // Ignorer l'erreur de décodage du message d'erreur
      throw Exception(message);
    } else if (response.statusCode == 404) {
      print('Erreur 404: Ressource non trouvée.');
      print('Réponse: $responseBody');
      throw Exception('Ressource non trouvée (404)');
    } else {
      // Autres erreurs (4xx, 5xx)
      print('Erreur API: Status Code: ${response.statusCode}');
      print('Réponse: $responseBody');
      // Tenter de décoder un message d'erreur du backend
      String message = 'Erreur serveur (${response.statusCode}): ${response.reasonPhrase}';
      try {
        final errorJson = jsonDecode(responseBody);
        if (errorJson is Map && errorJson.containsKey('message')) {
          message = errorJson['message'];
        }
      } catch (_) {} // Ignorer l'erreur de décodage du message d'erreur
      throw Exception(message);
    }
  }

  // Helper pour ajouter les headers HTTP
  Map<String, String> _getHeaders({String? authToken, bool isJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json', // Préciser qu'on accepte du JSON en retour
    };
    if (isJson) {
      // Indiquer qu'on envoie du JSON (si applicable)
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (authToken != null && authToken.isNotEmpty) {
      // Ajouter le token d'authentification
      headers['Authorization'] = 'Bearer $authToken'; // Adaptez si votre schéma est différent
    }
    return headers;
  }

  // --- Authentification ---

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/auth/login'), // Adaptez l'endpoint réel
        headers: _getHeaders(), // Content-Type: application/json
        body: jsonEncode(<String, String>{
          'email': email, // ou 'username' selon votre backend
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15)); // Ajout d'un timeout

      // Retourne le corps de la réponse (peut contenir token, user info)
      // _handleResponse lèvera une exception en cas d'erreur HTTP
      return _handleResponse(response) as Map<String, dynamic>?;

    } catch (e) {
      print("Erreur lors de la connexion: $e");
      // Relancer l'exception pour que le Provider puisse l'attraper et afficher un message
      throw Exception("Erreur de connexion: ${e.toString()}");
      // Ou retourner null si le Provider gère spécifiquement le null
      // return null;
    }
  }

  Future<Map<String, dynamic>?> signupUser(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/auth/register'), // Adaptez l'endpoint réel
        headers: _getHeaders(),
        body: jsonEncode(<String, String>{
          'name': name, // Adaptez les champs requis par votre backend
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      // _handleResponse lèvera une exception en cas d'erreur HTTP
      return _handleResponse(response) as Map<String, dynamic>?;

    } catch (e) {
      print("Erreur lors de l'inscription: $e");
      throw Exception("Erreur d'inscription: ${e.toString()}");
      // return null;
    }
  }

  // --- Chansons (Songs) ---

  Future<List<Song>> fetchSongs({String? authToken}) async { // Ajout authToken optionnel
    try {
      final response = await http.get(
          Uri.parse('$API_BASE_URL/api/songs'),
          headers: _getHeaders(authToken: authToken, isJson: false) // Pas de body JSON
      ).timeout(const Duration(seconds: 20));

      final jsonResponse = _handleResponse(response); // Peut être null ou une liste
      if (jsonResponse == null || jsonResponse is! List) {
        // Gérer le cas où la réponse est vide ou non une liste comme attendu
        print("Réponse inattendue pour fetchSongs: $jsonResponse");
        return [];
      }
      // Assurez-vous que jsonResponse est bien List<dynamic> avant de mapper
      return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data)).toList();
    } catch (e) {
      print("Erreur lors de la récupération des chansons: $e");
      // Il est préférable de relancer pour que l'UI puisse afficher une erreur
      throw Exception("Impossible de charger les chansons: ${e.toString()}");
      // Ou retourner une liste vide si c'est le comportement souhaité en cas d'erreur
      // return [];
    }
  }

  Future<Song?> fetchSongById(String songId, {String? authToken}) async { // Ajout authToken
    try {
      final response = await http.get(
          Uri.parse('$API_BASE_URL/api/songs/$songId'),
          headers: _getHeaders(authToken: authToken, isJson: false)
      ).timeout(const Duration(seconds: 15));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null; // Si la réponse est vide
      return Song.fromJson(jsonResponse);
    } catch (e) {
      print("Erreur lors de la récupération de la chanson $songId: $e");
      throw Exception("Impossible de charger la chanson $songId: ${e.toString()}");
      // return null;
    }
  }

  Future<Song?> uploadSong({
    required String title,
    required String artist,
    required String genre,
    required File audioFile,
    required File coverImageFile,
    String? authToken, // Requis si l'upload est protégé
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$API_BASE_URL/api/songs/upload'), // Adaptez l'endpoint réel
      );

      // Ajouter les headers (y compris l'auth si nécessaire)
      // Note: MultipartRequest n'a pas de 'headers' direct, on les ajoute après
      final headers = _getHeaders(authToken: authToken, isJson: false);
      request.headers.addAll(headers); // Ajoute les headers préparés

      // Ajout des champs texte
      request.fields['title'] = title;
      request.fields['artist'] = artist;
      request.fields['genre'] = genre;

      // Ajout du fichier audio
      request.files.add(await http.MultipartFile.fromPath(
        'audio', // Nom du champ attendu par le backend
        audioFile.path,
        contentType: MediaType('audio', '*'), // Ex: audio/mpeg, audio/ogg...
      ));

      // Ajout de l'image de couverture
      request.files.add(await http.MultipartFile.fromPath(
        'cover', // Nom du champ attendu par le backend
        coverImageFile.path,
        contentType: MediaType('image', '*'), // Ex: image/jpeg, image/png...
      ));

      // Envoi de la requête (avec un timeout plus long pour l'upload)
      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);

      // Gestion de la réponse
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Song.fromJson(jsonResponse); // Attend la chanson créée en retour

    } catch (e) {
      print("Erreur lors de l'upload de la chanson: $e");
      throw Exception("Erreur d'upload: ${e.toString()}");
      // return null;
    }
  }

  Future<bool> deleteSong(String songId, {required String authToken}) async { // authToken rendu requis
    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/api/songs/$songId'),
        headers: _getHeaders(authToken: authToken, isJson: false), // Pas de body JSON ici
      ).timeout(const Duration(seconds: 15));

      _handleResponse(response); // Vérifie le succès (lèvera une exception sinon)
      return true; // Succès si aucune exception n'est levée

    } catch (e) {
      print("Erreur lors de la suppression de la chanson $songId: $e");
      throw Exception("Erreur de suppression: ${e.toString()}");
      // return false; // Retourner false si on ne relance pas l'exception
    }
  }

  // --- Playlists ---

  Future<List<Playlist>> fetchPlaylists({String? authToken}) async {
    try {
      final response = await http.get(
          Uri.parse('$API_BASE_URL/api/playlists'), // Endpoint pour TOUTES les playlists (publiques?)
          headers: _getHeaders(authToken: authToken, isJson: false)
      ).timeout(const Duration(seconds: 20));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) {
        print("Réponse inattendue pour fetchPlaylists: $jsonResponse");
        return [];
      }
      return (jsonResponse as List<dynamic>).map((data) => Playlist.fromJson(data)).toList();
    } catch (e) {
      print("Erreur lors du chargement des playlists: $e");
      throw Exception("Impossible de charger les playlists: ${e.toString()}");
      // return [];
    }
  }

  Future<List<Playlist>> fetchMyPlaylists(String authToken) async {
    // Cette méthode est spécifique aux playlists de l'utilisateur connecté
    try {
      // Adaptez l'endpoint: '/api/users/me/playlists' ou '/api/playlists?userId=...' etc.
      final response = await http.get(
          Uri.parse('$API_BASE_URL/api/users/me/playlists'), // Endpoint spécifique
          headers: _getHeaders(authToken: authToken, isJson: false) // Auth est requis ici
      ).timeout(const Duration(seconds: 20));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) {
        print("Réponse inattendue pour fetchMyPlaylists: $jsonResponse");
        return [];
      }
      print(jsonResponse);
      return (jsonResponse as List<dynamic>).map((data) => Playlist.fromJson(data)).toList();
    } catch (e) {
      print("Erreur lors du chargement de mes playlists: $e");
      throw Exception("Impossible de charger vos playlists: ${e.toString()}");
      // return [];
    }
  }

  Future<Playlist?> fetchPlaylistDetails(String playlistId, {String? authToken}) async {
    try {
      final response = await http.get(
          Uri.parse('$API_BASE_URL/api/playlists/$playlistId'), // Endpoint pour UNE playlist
          headers: _getHeaders(authToken: authToken, isJson: false)
      ).timeout(const Duration(seconds: 15));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      // Assurez-vous que Playlist.fromJson gère bien la liste de chansons incluse
      return Playlist.fromJson(jsonResponse);
    } catch (e) {
      print("Erreur lors du chargement des détails de la playlist $playlistId: $e");
      throw Exception("Impossible de charger les détails de la playlist: ${e.toString()}");
      // return null;
    }
  }

  // --- Actions sur les Playlists (Nécessitent souvent une authentification) ---

  Future<Playlist?> createPlaylist(String name, String? description, {required String authToken}) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/api/playlists'), // Endpoint de création
        headers: _getHeaders(authToken: authToken), // Auth requis, body JSON
        body: jsonEncode(<String, String?>{
          'name': name,
          'description': description, // Inclure si non null ou vide
        }),
      ).timeout(const Duration(seconds: 15));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Playlist.fromJson(jsonResponse); // Retourne la playlist créée
    } catch (e) {
      print("Erreur lors de la création de la playlist: $e");
      throw Exception("Erreur de création de playlist: ${e.toString()}");
      // return null;
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId, {required String authToken}) async {
    try {
      final response = await http.post(
        // Endpoint probable: ajouter une chanson à une playlist spécifique
        Uri.parse('$API_BASE_URL/api/playlists/$playlistId/songs'),
        headers: _getHeaders(authToken: authToken), // Auth requis, body JSON
        body: jsonEncode({'songId': songId}), // Envoyer l'ID de la chanson
      ).timeout(const Duration(seconds: 15));

      _handleResponse(response); // Vérifie succès (200, 201, 204...)
      return true;

    } catch (e) {
      print("Erreur lors de l'ajout de la chanson $songId à la playlist $playlistId: $e");
      throw Exception("Erreur d'ajout à la playlist: ${e.toString()}");
      // return false;
    }
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId, {required String authToken}) async {
    try {
      // L'endpoint dépend de votre design API (ex: DELETE sur /playlists/{id}/songs/{songId})
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/api/playlists/$playlistId/songs/$songId'), // Endpoint hypothétique
        headers: _getHeaders(authToken: authToken, isJson: false), // Auth requis, pas de body
      ).timeout(const Duration(seconds: 15));

      _handleResponse(response); // Vérifie succès (200, 204...)
      return true;

    } catch (e) {
      print("Erreur lors de la suppression de la chanson $songId de la playlist $playlistId: $e");
      throw Exception("Erreur de suppression de la playlist: ${e.toString()}");
      // return false;
    }
  }

  Future<bool> deletePlaylist(String playlistId, {required String authToken}) async {
    try {
      final response = await http.delete(
        Uri.parse('$API_BASE_URL/api/playlists/$playlistId'),
        headers: _getHeaders(authToken: authToken, isJson: false),
      ).timeout(const Duration(seconds: 15));
      _handleResponse(response);
      return true;
    } catch (e) {
      print("Erreur lors de la suppression de la playlist $playlistId: $e");
      throw Exception("Erreur de suppression de playlist: ${e.toString()}");
      // return false;
    }
  }

  // --- Recherche (Exemple) ---
  Future<List<dynamic>> search(String query, {String? type, String? authToken}) async {
    // Le type pourrait être 'song', 'artist', 'playlist', 'album' ou null pour tout
    try {
      // Construire l'URL avec les paramètres de requête
      final queryParams = {
        'q': query,
        if (type != null) 'type': type,
      };
      final uri = Uri.parse('$API_BASE_URL/api/search').replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _getHeaders(authToken: authToken, isJson: false),
      ).timeout(const Duration(seconds: 20));

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) {
        print("Réponse inattendue pour la recherche: $jsonResponse");
        return [];
      }
      // La réponse est une liste mixte, le Provider/Screen devra déterminer le type de chaque item
      return jsonResponse as List<dynamic>;
    } catch (e) {
      print("Erreur lors de la recherche '$query': $e");
      throw Exception("Erreur de recherche: ${e.toString()}");
      // return [];
    }
  }

  Future<List<Song>> fetchRecommendations(String? token) async {
    final url = Uri.parse('$API_BASE_URL/api/songs/recommendations'); // Adjust endpoint
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          // Include Authorization header if your endpoint requires it
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        // Ensure the response is a list before mapping
        if (jsonResponse is List) {
          List<Song> songs = jsonResponse
              .map((data) => Song.fromJson(data as Map<String, dynamic>))
              .toList();
          return songs;
        } else {
          throw Exception('Invalid response format: Expected a List');
        }
      } else {
        // Handle different HTTP status codes (e.g., 401 Unauthorized, 404 Not Found)
        print('Failed to load recommendations: ${response.statusCode} ${response.body}');
        throw Exception('Failed to load recommendations (${response.statusCode})');
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      // Re-throw the exception to be caught by the Provider
      throw Exception('Error fetching recommendations: $e');
    }
  }


}