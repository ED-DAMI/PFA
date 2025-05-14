// lib/services/api_service.dart
import 'dart:convert'; // Pour jsonEncode/Decode
import 'dart:io'; // Pour File (upload)
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Pour MediaType (upload)

// Assurez-vous que ces chemins sont corrects
import '../config/api_config.dart'; // Votre URL de base

import '../models/comment.dart';
import '../models/playlist.dart'; // Doit contenir Playlist.fromJson // Commenté car non utilisé actuellement
import '../models/reaction.dart';
import '../models/song.dart';
import '../models/tag.dart';     // Doit contenir Song.fromJson


class ApiService {
  final String _baseUrl = API_BASE_URL; // Utiliser une variable locale pour la clarté

  // Helper pour gérer les réponses communes et les erreurs
  dynamic _handleResponse(http.Response response) {
    final String responseBody = utf8.decode(response.bodyBytes); // Gère les caractères spéciaux (accents, etc.)

    if (kDebugMode) {
      print("API Response Status: ${response.statusCode}");
      print("API Response Body: $responseBody");
      print("API Request URL: ${response.request?.url}");
      print("API Request Method: ${response.request?.method}");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty || response.statusCode == 204) {
        // 204 No Content ou corps vide pour succès
        return null; // ou true pour indiquer le succès si aucun corps n'est attendu
      }
      try {
        // Tenter de décoder le JSON
        return jsonDecode(responseBody);
      } catch (e) {
        if (kDebugMode) {
          print("Erreur de décodage JSON: $e");
          print("Corps de la réponse (brut): $responseBody");
        }
        throw Exception('Réponse invalide du serveur (JSON mal formé). Contenu: $responseBody');
      }
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      if (kDebugMode) {
        print('Erreur ${response.statusCode}: Non autorisé ou Interdit.');
        print('Réponse: $responseBody');
      }
      String message = 'Authentification requise ou accès refusé (${response.statusCode})';
      try {
        final errorJson = jsonDecode(responseBody);
        if (errorJson is Map && errorJson.containsKey('message')) {
          message = errorJson['message'];
        } else if (errorJson is Map && errorJson.containsKey('error')) {
          message = errorJson['error'];
        }
      } catch (_) {}
      throw Exception(message);
    } else if (response.statusCode == 404) {
      if (kDebugMode) {
        print('Erreur 404: Ressource non trouvée.');
        print('Réponse: $responseBody');
      }
      throw Exception('Ressource non trouvée (${response.statusCode})');
    } else {
      if (kDebugMode) {
        print('Erreur API: Status Code: ${response.statusCode}');
        print('Réponse: $responseBody');
      }
      String message = 'Erreur serveur (${response.statusCode}): ${response.reasonPhrase}';
      try {
        final errorJson = jsonDecode(responseBody);
        if (errorJson is Map && errorJson.containsKey('message')) {
          message = errorJson['message'];
        } else if (errorJson is Map && errorJson.containsKey('error')) {
          message = errorJson['error'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  // Helper pour ajouter les headers HTTP
  Map<String, String> _getHeaders({String? authToken, bool isJsonContent = true, bool acceptJson = true}) {
    final headers = <String, String>{};
    if (acceptJson) {
      headers['Accept'] = 'application/json';
    }
    if (isJsonContent) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  // --- Authentification ---

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    if (kDebugMode) print("ApiService: loginUser - Email: $email");
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode(<String, String>{'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response) as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print("Erreur lors de la connexion: $e");
      throw Exception("Erreur de connexion: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>?> signupUser(String name, String email, String password) async {
    if (kDebugMode) print("ApiService: signupUser - Email: $email, Name: $name");
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode(<String, String>{'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      return _handleResponse(response) as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print("Erreur lors de l'inscription: $e");
      throw Exception("Erreur d'inscription: ${e.toString()}");
    }
  }

  // --- Chansons (Songs) ---

  Future<List<Song>> fetchSongs({String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongs");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/songs'),
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur récupération chansons: $e");
      throw Exception("Impossible de charger les chansons: ${e.toString()}");
    }
  }

  Future<Song?> fetchSongById(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongById - ID: $songId");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/songs/$songId'),
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Song.fromJson(jsonResponse);
    } catch (e) {
      if (kDebugMode) print("Erreur récupération chanson $songId: $e");
      throw Exception("Impossible de charger la chanson $songId: ${e.toString()}");
    }
  }

  Future<Song?> uploadSong({
    required String title,
    required String artist,
    required String genre,
    required File audioFile,
    required File coverImageFile,
    String? authToken,
  }) async {
    if (kDebugMode) print("ApiService: uploadSong - Title: $title");
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/songs/upload'),
      );
      // Pour les requêtes multipart, Content-Type est géré par http.MultipartRequest
      // On ajoute seulement Accept et Authorization si besoin.
      final headers = _getHeaders(authToken: authToken, isJsonContent: false, acceptJson: true);
      request.headers.addAll(headers);

      request.fields['title'] = title;
      request.fields['artist'] = artist;
      request.fields['genre'] = genre;

      request.files.add(await http.MultipartFile.fromPath(
        'audio', audioFile.path, contentType: MediaType('audio', '*'),
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'cover', coverImageFile.path, contentType: MediaType('image', '*'),
      ));

      final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
      final response = await http.Response.fromStream(streamedResponse);
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Song.fromJson(jsonResponse);
    } catch (e) {
      if (kDebugMode) print("Erreur upload chanson: $e");
      throw Exception("Erreur d'upload: ${e.toString()}");
    }
  }

  Future<bool> deleteSong(String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: deleteSong - ID: $songId");
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/songs/$songId'),
        headers: _getHeaders(authToken: authToken, isJsonContent: false),
      ).timeout(const Duration(seconds: 15));
      _handleResponse(response); // Vérifie succès (200-204), sinon lève exception
      return true;
    } catch (e) {
      if (kDebugMode) print("Erreur suppression chanson $songId: $e");
      throw Exception("Erreur de suppression: ${e.toString()}");
    }
  }

  // --- Playlists ---
  // (À implémenter si nécessaire)

  // --- Recherche ---
  Future<List<dynamic>> search(String query, {String? type, String? authToken}) async {
    if (kDebugMode) print("ApiService: search - Query: '$query', Type: $type");
    try {
      final queryParams = {'q': query, if (type != null) 'type': type};
      final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: _getHeaders(authToken: authToken, isJsonContent: false),
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return jsonResponse as List<dynamic>;
    } catch (e) {
      if (kDebugMode) print("Erreur recherche '$query': $e");
      throw Exception("Erreur de recherche: ${e.toString()}");
    }
  }

  Future<Map<String, List<dynamic>>> searchAll(String query, {String? authToken}) async {
    if (kDebugMode) print("ApiService: searchAll - Query: '$query'");
    try {
      final uri = Uri.parse('$_baseUrl/api/search/all').replace(queryParameters: {'q': query}); // Endpoint exemple
      final response = await http.get(
        uri,
        headers: _getHeaders(authToken: authToken, isJsonContent: false),
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! Map) return {};

      Map<String, List<dynamic>> results = {};
      if (jsonResponse['songs'] is List) {
        results['songs'] = (jsonResponse['songs'] as List).map((data) => Song.fromJson(data)).toList();
      }
      if (jsonResponse['tags'] is List) {
        results['tags'] = (jsonResponse['tags'] as List).map((data) => Tag.fromJson(data)).toList();
      }
      // Ajouter artistes, playlists etc.
      return results;
    } catch (e) {
      if (kDebugMode) print("Erreur recherche 'all' '$query': $e");
      throw Exception("Erreur de recherche 'all': ${e.toString()}");
    }
  }


  Future<List<Song>> fetchRecommendations({String? authToken}) async { // authToken est passé, pas 'token'
    if (kDebugMode) print("ApiService: fetchRecommendations");
    final url = Uri.parse('$_baseUrl/api/songs/recommendations');
    try {
      final response = await http.get(
        url,
        headers: _getHeaders(authToken: authToken, isJsonContent: false), // Utilisation de _getHeaders
      ).timeout(const Duration(seconds: 20)); // Ajout timeout

      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data)).toList();

    } catch (e) {
      if (kDebugMode) print('Error fetching recommendations: $e');
      throw Exception('Erreur lors du chargement des recommandations: ${e.toString()}');
    }
  }

  // --- Tags ---
  Future<List<Tag>> fetchTags({String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchTags");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/tags'),
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Tag.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur récupération tags: $e");
      throw Exception("Impossible de charger les tags: ${e.toString()}");
    }
  }

  Future<List<Song>> fetchSongsByTag(String tagId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongsByTag - ID: $tagId");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/songs?tagId=$tagId'), // ou /api/tags/$tagId/songs
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur récupération chansons par tag $tagId: $e");
      throw Exception("Impossible de charger les chansons pour le tag: ${e.toString()}");
    }
  }

  // --- Comments ---
  Future<List<Comment>> fetchComments(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchComments - SongID: $songId");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/comments/$songId'),
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Comment.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur fetchComments: $e");
      throw Exception("Impossible de charger les commentaires: ${e.toString()}");
    }
  }

  Future<Comment?> postComment(String songId, String text, {required String authToken}) async {
    if (kDebugMode) print("ApiService: postComment - SongID: $songId, Text: $text");
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/comments/$songId'),
        headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut
        body: jsonEncode({'text': text}), // Assurez-vous que le backend attend 'text'
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Comment.fromJson(jsonResponse);
    } catch (e) {
      if (kDebugMode) print("Erreur postComment: $e");
      throw Exception("Impossible de poster le commentaire: ${e.toString()}");
    }
  }


  Future<void> IncrmentView(String songId, {required String authToken}) async {

    if (kDebugMode) print("ApiService: Increment view - SongID: $songId");
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/songs/$songId/view'),
        headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut

      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
    } catch (e) {
      if (kDebugMode) print("Erreur postComment: $e");
      throw Exception("Impossible de poster le commentaire: ${e.toString()}");
    }
  }

  // --- Reactions ---
  Future<List<Reaction>> fetchReactions(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchReactions - SongID: $songId");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/reactions/$songId'),
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      return (jsonResponse as List<dynamic>).map((data) => Reaction.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur fetchReactions: $e");
      throw Exception("Impossible de charger les réactions: ${e.toString()}");
    }
  }

  Future<Reaction?> postReaction(String songId, String emoji, {required String? authToken}) async {
    if (kDebugMode) print("ApiService: postReaction - SongID: $songId, Emoji: $emoji");
    if (authToken == null) { // S'assurer que le token est non-null pour les opérations nécessitant auth
      throw Exception("Authentification requise pour poster une réaction.");
    }
    try {
      print(emoji);
      final response = await http.post(
        Uri.parse('$_baseUrl/api/reactions/$songId'),
        headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut
        body: jsonEncode({'emoji': emoji}), // Assurez-vous que le backend attend 'emoji'
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Reaction.fromJson(jsonResponse);
    } catch (e) {
      if (kDebugMode) print("Erreur postReaction: $e");
      throw Exception("Impossible de poster la réaction: ${e.toString()}");
    }
  }

  Future<bool> deleteReaction(String songId, String token) async {
    if (kDebugMode) print("ApiService: deleteReaction - songId: $songId");
    // L'endpoint pour supprimer une réaction spécifique est généralement /api/reactions/{reactionId}
    // et non lié à songId directement, car reactionId devrait être unique.
    // Adaptez si votre API est structurée différemment (ex: /api/songs/{songId}/reactions/{reactionId}).
    // Ici, je suppose un endpoint direct pour la suppression de réaction.
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/reactions/$songId'), // Endpoint supposé
        headers: _getHeaders(authToken: token! , isJsonContent: false),
      ).timeout(const Duration(seconds: 15));

      _handleResponse(response); // Vérifie si la réponse est 200-204 (succès)
      // Si le backend retourne 204 (No Content), _handleResponse retournera null.
      // Si le backend retourne 200 avec un corps (ex: { "message": "Supprimé" }),
      // _handleResponse retournera le JSON décodé.
      // Dans les deux cas, si aucune exception n'est levée, c'est un succès.
      return true;
    } catch (e) {
      if (kDebugMode) print("Erreur lors de la suppression de la réaction $songId: $e");
      throw Exception("Impossible de supprimer la réaction: ${e.toString()}");
    }
  }




  Future<List<Song>> fetchRecommendedSongs(String basedOnSongId, {String? authToken}) async {
    final url = Uri.parse('$API_BASE_URL/api/songs/$basedOnSongId/recommendations'); // Adaptez l'URL
    final headers = {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };

    if (kDebugMode) {
      print('ApiService: Fetching recommendations based on song $basedOnSongId');
      print('API Request URL: $url');
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('ApiService: fetchRecommendedSongs - Raw response body: ${response.body}');
        }
        List<dynamic> body = json.decode(utf8.decode(response.bodyBytes)); // Gérer l'UTF-8
        List<Song> songs = body.map((dynamic item) => Song.fromJson(item as Map<String, dynamic>)).toList();
        return songs;
      } else {
        if (kDebugMode) {
          print('ApiService: Failed to load recommended songs. Status: ${response.statusCode}, Body: ${response.body}');
        }
        throw Exception('Impossible de charger les recommandations (code: ${response.statusCode})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error fetching recommended songs: $e');
      }
      throw Exception('Erreur lors de la récupération des recommandations: $e');
    }
  }
  Future<bool> deleteReactionByEmoji(String songId, String emoji, {required String authToken}) async {
    if (kDebugMode) print("ApiService: deleteReactionByEmoji - SongID: $songId, Emoji: $emoji");

    // L'URL de l'endpoint dépend de votre API. Exemples :
    // 1. DELETE /api/songs/{songId}/reactions/{emoji} (si l'emoji est un identifiant dans l'URL)
    //    final url = Uri.parse('$_baseUrl/api/songs/$songId/reactions/$emoji');
    // 2. DELETE /api/reactions?songId={songId}&emoji={emoji} (emoji en query param)
    //    final url = Uri.parse('$_baseUrl/api/reactions').replace(queryParameters: {'songId': songId, 'emoji': emoji});
    // 3. DELETE /api/reactions/{songId} avec l'emoji dans le body (moins courant pour DELETE)
    //    final url = Uri.parse('$_baseUrl/api/reactions/$songId');
    //    final body = jsonEncode({'emoji': emoji});

    // Je vais supposer un endpoint comme le n°1 pour l'exemple :
    final url = Uri.parse('$_baseUrl/api/songs/$songId/reactions/$emoji');
    // Si l'emoji contient des caractères spéciaux, il faudrait l'encoder pour l'URL :
    // final encodedEmoji = Uri.encodeComponent(emoji);
    // final url = Uri.parse('$_baseUrl/api/songs/$songId/reactions/$encodedEmoji');


    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(authToken: authToken, isJsonContent: false), // Pas de corps JSON pour DELETE simple
        // body: body, // Si l'option 3 est utilisée
      ).timeout(const Duration(seconds: 15));

      _handleResponse(response); // Gère les codes de statut (200, 204 pour succès)
      return true; // Succès si _handleResponse ne lève pas d'exception
    } catch (e) {
      if (kDebugMode) print("Erreur deleteReactionByEmoji: $e");
      throw Exception("Impossible de supprimer la réaction: ${e.toString()}");
    }
  }

  Future<List<Playlist>> fetchUserPlaylists({required String authToken}) async { // Modèle Playlist nécessaire
    if (kDebugMode) print("ApiService: fetchUserPlaylists");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/playlists/me'), // Endpoint pour les playlists de l'utilisateur connecté
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      // Assurez-vous d'avoir Playlist.fromJson(data) dans votre modèle Playlist
      return (jsonResponse as List<dynamic>).map((data) => Playlist.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur récupération playlists utilisateur: $e");
      throw Exception("Impossible de charger vos playlists: ${e.toString()}");
    }
  }

  Future<Playlist?> createPlaylist({
    required String name,
    String? description,
    bool isPublic = true, // Exemple de paramètre additionnel
    required String authToken
  }) async {
    if (kDebugMode) print("ApiService: createPlaylist - Name: $name");
    try {
      final body = <String, dynamic>{
        'name': name,
        'isPublic': isPublic,
      };
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }else
        body['description']="vide";

      final response = await http.post(
        Uri.parse('$_baseUrl/api/playlists'),
        headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null) return null;
      return Playlist.fromJson(jsonResponse); // Modèle Playlist nécessaire
    } catch (e) {
      if (kDebugMode) print("Erreur création playlist: $e");
      throw Exception("Impossible de créer la playlist: ${e.toString()}");
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: addSongToPlaylist - PlaylistID: $playlistId, SongID: $songId");
    try {
      // L'API peut attendre un corps vide, ou un corps avec songId, ou l'ID dans l'URL
      // Exemple : POST /api/playlists/{playlistId}/songs/{songId}
      // Ou : POST /api/playlists/{playlistId}/songs avec body: {'songId': songId}
      final response = await http.post(
        Uri.parse('$_baseUrl/api/playlists/$playlistId/songs'), // Endpoint exemple
        headers: _getHeaders(authToken: authToken),
        body: jsonEncode({'songId': songId}),
      ).timeout(const Duration(seconds: 15));
      _handleResponse(response); // Vérifie succès (200-201), sinon lève exception
      return true;
    } catch (e) {
      if (kDebugMode) print("Erreur ajout chanson à playlist: $e");
      throw Exception("Impossible d'ajouter la chanson à la playlist: ${e.toString()}");
    }
  }
  // Potentiellement d'autres méthodes pour les playlists : deletePlaylist, removeSongFromPlaylist, fetchPlaylistById

  // --- Historique d'écoute (User History) ---
  Future<List<Song>> fetchUserHistory({required String authToken}) async {
    if (kDebugMode) print("ApiService: fetchUserHistory");
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/api/users/history'), // Endpoint pour l'historique de l'utilisateur connecté
          headers: _getHeaders(authToken: authToken, isJsonContent: false)
      ).timeout(const Duration(seconds: 20));
      final jsonResponse = _handleResponse(response);
      if (jsonResponse == null || jsonResponse is! List) return [];
      // L'historique retourne souvent des objets Song directement, ou des objets "HistoryEntry"
      // qui contiennent une chanson. Adaptez Song.fromJson si nécessaire.
      return (jsonResponse as List<dynamic>).map((data) {
        // Si l'API retourne un objet HistoryEntry qui a un champ 'song' :
        // if (data is Map<String, dynamic> && data.containsKey('song')) {
        //   return Song.fromJson(data['song']);
        // }
        return Song.fromJson(data); // Si l'API retourne directement des chansons
      }).toList();
    } catch (e) {
      if (kDebugMode) print("Erreur récupération historique utilisateur: $e");
      throw Exception("Impossible de charger votre historique: ${e.toString()}");
    }
  }
}