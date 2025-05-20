// lib/services/api_service.dart
import 'dart:convert'; // Pour jsonEncode/Decode
import 'dart:io'; // Pour File (upload)
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Pour MediaType (upload)

import '../../config/api_config.dart'; // Votre URL de base API_BASE_URL

import '../../models/comment.dart'; // Assurez-vous que Comment.fromJson existe
import '../../models/playlist.dart'; // Assurez-vous que Playlist.fromJson existe
import '../../models/reaction.dart'; // Assurez-vous que Reaction.fromJson existe
import '../../models/song.dart';     // Assurez-vous que Song.fromJson existe
import '../../models/tag.dart';      // Assurez-vous que Tag.fromJson existe

class ApiService {
  final String _baseUrl = API_BASE_URL; // Utiliser la variable de classe

  // Helper pour gérer les réponses communes et les erreurs
  dynamic _handleResponse(http.Response response) {
    final String responseBody = utf8.decode(response.bodyBytes);

    if (kDebugMode) {
      print("API Request: ${response.request?.method} ${response.request?.url}");
      print("API Response Status: ${response.statusCode}");
      if (responseBody.length < 500) { // Éviter les logs trop longs
        print("API Response Body: $responseBody");
      } else {
        print("API Response Body: (Truncated) ${responseBody.substring(0,500)}...");
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty || response.statusCode == 204) {
        return null; // Succès sans contenu
      }
      try {
        return jsonDecode(responseBody);
      } catch (e) {
        if (kDebugMode) {
          print("Erreur de décodage JSON: $e");
          print("Corps de la réponse (brut) ayant causé l'erreur: $responseBody");
        }
        throw Exception('Réponse invalide du serveur (JSON mal formé).');
      }
    } else {
      String errorMessage = 'Erreur serveur (${response.statusCode})';
      if (responseBody.isNotEmpty) {
        try {
          final errorJson = jsonDecode(responseBody);
          if (errorJson is Map) {
            if (errorJson.containsKey('message')) {
              errorMessage = errorJson['message'];
            } else if (errorJson.containsKey('error')) {
              errorMessage = errorJson['error'];
            } else if (errorJson.containsKey('detail')) {
              errorMessage = errorJson['detail'];
            } else {
              // Essayer de concaténer les erreurs si c'est une map de listes (validation Laravel par ex)
              if (errorJson.values.every((v) => v is List && v.isNotEmpty && v.first is String)) {
                errorMessage = errorJson.values.map((v) => (v as List).first as String).join(' ');
              } else {
                errorMessage = responseBody; // Si c'est juste une chaîne d'erreur non JSON
              }
            }
          } else if (errorJson is String) {
            errorMessage = errorJson;
          }
        } catch (_) {
          // Si le corps de l'erreur n'est pas du JSON, utiliser le corps brut si pertinent
          errorMessage = responseBody.length < 200 ? responseBody : 'Erreur serveur (${response.statusCode})';
        }
      } else if (response.reasonPhrase != null && response.reasonPhrase!.isNotEmpty) {
        errorMessage = response.reasonPhrase!;
      }
      throw Exception(errorMessage);
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
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(response) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> signupUser(String name, String email, String password) async {
    if (kDebugMode) print("ApiService: signupUser - Email: $email, Name: $name");
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'name': name, 'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(response) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> refreshToken(String currentRefreshToken) async {
    if (kDebugMode) print("ApiService: Attempting to refresh token");
    // L'endpoint et le corps dépendent de votre API (ex: OAuth2)
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/refresh'), // Endpoint hypothétique
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'refreshToken': currentRefreshToken}),
    ).timeout(const Duration(seconds: 15));
    // Devrait retourner un nouveau 'token' et potentiellement un nouveau 'refreshToken'
    return _handleResponse(response) as Map<String, dynamic>?;
  }

  Future<void> logoutUser(String authToken) async {
    if (kDebugMode) print("ApiService: Attempting to logout user via API");
    // Invalider le token côté serveur si l'API le supporte
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/auth/logout'), // Endpoint hypothétique
        headers: _getHeaders(authToken: authToken, isJsonContent: false, acceptJson: false),
      ).timeout(const Duration(seconds: 10));
      // On ne se soucie pas de la réponse, sauf si c'est une erreur que l'on veut explicitement gérer
    } catch (e) {
      if (kDebugMode) print("ApiService: Error during API logout: $e (token might be already invalid or server down). This error is ignored for client-side logout.");
      // Ne pas relancer l'exception ici, le logout côté client doit continuer.
    }
  }


  // --- Chansons (Songs) ---

  Future<List<Song>> fetchSongs({String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongs");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/songs'),
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<Song?> fetchSongById(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongById - ID: $songId");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/songs/$songId'),
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null) return null;
    return Song.fromJson(jsonResponse as Map<String,dynamic>);
  }

  Future<List<Song>> fetchdSongsByIds(List<String> songIds, {String? authToken}) async {
    if (songIds.isEmpty) return [];
    if (kDebugMode) print("ApiService: fetchSongsByIds - Count: ${songIds.length}");

    // L'implémentation dépend de votre API.
    // Option 1: Query parameters (si pas trop d'IDs)
    // final queryParameters = {'ids': songIds.join(',')};
    // final uri = Uri.parse('$_baseUrl/api/songs/batch').replace(queryParameters: queryParameters);
    // final response = await http.get(uri, headers: _getHeaders(authToken: authToken, isJsonContent: false));

    // Option 2: Corps POST (plus robuste pour beaucoup d'IDs)
    final uri = Uri.parse('$_baseUrl/api/songs/batch'); // Endpoint exemple
    final response = await http.post(
      uri,
      headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut
      body: jsonEncode({'ids': songIds}),
    ).timeout(const Duration(seconds: 25));

    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
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
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/songs/upload'));
    final headers = _getHeaders(authToken: authToken, isJsonContent: false, acceptJson: true);
    request.headers.addAll(headers);

    request.fields['title'] = title;
    request.fields['artist'] = artist;
    request.fields['genre'] = genre;

    request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path, contentType: MediaType('audio', '*')));
    request.files.add(await http.MultipartFile.fromPath('cover', coverImageFile.path, contentType: MediaType('image', '*')));

    final streamedResponse = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamedResponse);
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null) return null;
    return Song.fromJson(jsonResponse as Map<String,dynamic>);
  }

  Future<bool> deleteSong(String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: deleteSong - ID: $songId");
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/songs/$songId'),
      headers: _getHeaders(authToken: authToken, isJsonContent: false),
    ).timeout(const Duration(seconds: 15));
    _handleResponse(response); // Vérifie succès (200-204)
    return true;
  }

  Future<void> incrementSongView(String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: incrementSongView - SongID: $songId");
    try {
      // Pas de corps JSON nécessaire pour cet appel POST si le backend ne l'attend pas
      await http.post(
        Uri.parse('$_baseUrl/api/songs/$songId/view'),
        headers: _getHeaders(authToken: authToken, isJsonContent: false, acceptJson: false),
      ).timeout(const Duration(seconds: 10));
      // Pas besoin de _handleResponse si succès est 204 No Content ou si on ne se soucie pas de la réponse
    } catch (e) {
      if (kDebugMode) print("ApiService: Erreur lors de l'incrémentation de la vue pour $songId: $e. Cette erreur est ignorée.");
      // Ne pas relancer l'exception, car l'échec de l'incrémentation des vues
      // ne devrait pas bloquer l'expérience utilisateur principale.
    }
  }

  Future<List<Song>> fetchRecommendations({String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchRecommendations (générales)");
    final url = Uri.parse('$_baseUrl/api/songs/recommendations');
    final response = await http.get(url, headers: _getHeaders(authToken: authToken, isJsonContent: false)).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<List<Song>> fetchRecommendedSongs(String basedOnSongId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchRecommendations based on song $basedOnSongId");
    final url = Uri.parse('$_baseUrl/api/songs/$basedOnSongId/recommendations');
    final response = await http.get(url, headers: _getHeaders(authToken: authToken, isJsonContent: false)).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
  }

  // --- Tags ---
  Future<List<Tag>> fetchTags({String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchTags");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Tag.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<List<Song>> fetchSongsByTag(String tagId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchSongsByTag - ID: $tagId");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/songs?tagId=$tagId'), // Ou /api/tags/$tagId/songs
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
  }

  // --- Comments ---
  Future<List<Comment>> fetchComments(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchComments - SongID: $songId");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/comments/$songId'), // Endpoint GET pour les commentaires d'une chanson
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Comment.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<Comment?> postComment(String songId, String text, {required String authToken}) async {
    if (kDebugMode) print("ApiService: postComment - SongID: $songId, Text: $text");
    final response = await http.post(
      Uri.parse('$_baseUrl/api/comments/$songId'), // Endpoint POST pour ajouter un commentaire
      headers: _getHeaders(authToken: authToken), // isJsonContent: true par défaut
      body: jsonEncode({'text': text}),
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null) return null;
    return Comment.fromJson(jsonResponse as Map<String,dynamic>);
  }

  // --- Reactions ---
  Future<List<Reaction>> fetchReactions(String songId, {String? authToken}) async {
    if (kDebugMode) print("ApiService: fetchReactions - SongID: $songId");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/reactions/$songId'), // Endpoint GET pour les réactions d'une chanson
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Reaction.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<Reaction?> postReaction(String songId, String emoji, {required String? authToken}) async {
    if (kDebugMode) print("ApiService: postReaction - SongID: $songId, Emoji: $emoji");
    if (authToken == null) throw Exception("Authentification requise pour poster une réaction.");

    final response = await http.post(
      Uri.parse('$_baseUrl/api/reactions/$songId'), // Endpoint POST pour ajouter/màj une réaction
      headers: _getHeaders(authToken: authToken),
      body: jsonEncode({'emoji': emoji}),
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null) return null;
    return Reaction.fromJson(jsonResponse as Map<String,dynamic>);
  }

  Future<bool> deleteReactionByEmoji(String songId, String emoji, {required String authToken}) async {
    if (kDebugMode) print("ApiService: deleteReactionByEmoji - SongID: $songId, Emoji: $emoji");
    final encodedEmoji = Uri.encodeComponent(emoji); // Important pour les caractères spéciaux dans l'URL
    // Endpoint exemple: DELETE /api/songs/{songId}/reactions/{emoji} (suppose que l'emoji est l'identifiant unique de la réaction de l'utilisateur pour cette chanson)
    // Ou votre API pourrait nécessiter DELETE /api/reactions/{reactionId} si vous stockez un reactionId.
    // Adaptez cet URL à votre API.
    final url = Uri.parse('$_baseUrl/api/songs/$songId/reactions/$encodedEmoji');

    final response = await http.delete(
      url,
      headers: _getHeaders(authToken: authToken, isJsonContent: false),
    ).timeout(const Duration(seconds: 15));
    _handleResponse(response); // Vérifie le succès (200-204)
    return true;
  }

  // --- Playlists ---
  Future<List<Playlist>> fetchUserPlaylists({required String authToken}) async {
    if (kDebugMode) print("ApiService: fetchUserPlaylists");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/playlists/me'), // Endpoint pour les playlists de l'utilisateur connecté
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Playlist.fromJson(data as Map<String,dynamic>)).toList();
  }

  Future<Playlist?> createPlaylist({
    required String name,
    String? description,
    bool isPublic = true,
    required String authToken
  }) async {
    if (kDebugMode) print("ApiService: createPlaylist - Name: $name");
    final body = <String, dynamic>{'name': name, 'isPublic': isPublic};
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    } else {
      body['description'] = ""; // Ou null si votre API le permet
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/playlists'),
      headers: _getHeaders(authToken: authToken),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null) return null;
    return Playlist.fromJson(jsonResponse as Map<String,dynamic>);
  }

  Future<bool> addSongToPlaylist(String playlistId, String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: addSongToPlaylist - PlaylistID: $playlistId, SongID: $songId");
    // Endpoint exemple: POST /api/playlists/{playlistId}/songs
    // avec le songId dans le corps
    final response = await http.post(
      Uri.parse('$_baseUrl/api/playlists/$playlistId/songs'),
      headers: _getHeaders(authToken: authToken),
      body: jsonEncode({'songId': songId}),
    ).timeout(const Duration(seconds: 15));
    _handleResponse(response); // Vérifie succès (200-201)
    return true;
  }

  Future<bool> removeSongFromPlaylist(String playlistId, String songId, {required String authToken}) async {
    if (kDebugMode) print("ApiService: removeSongFromPlaylist - PlaylistID: $playlistId, SongID: $songId");
    // Endpoint exemple: DELETE /api/playlists/{playlistId}/songs/{songId}
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/playlists/$playlistId/songs/$songId'),
      headers: _getHeaders(authToken: authToken, isJsonContent: false),
    ).timeout(const Duration(seconds: 15));
    _handleResponse(response); // Vérifie succès (200-204)
    return true;
  }

  // --- Historique d'écoute (User History) ---
  Future<List<Song>> fetchUserHistory({required String authToken}) async {
    if (kDebugMode) print("ApiService: fetchUserHistory");
    final response = await http.get(
        Uri.parse('$_baseUrl/api/users/history'), // Endpoint pour l'historique
        headers: _getHeaders(authToken: authToken, isJsonContent: false)
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return (jsonResponse as List<dynamic>).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
  }

  // --- Recherche ---
  Future<List<dynamic>> search(String query, {String? type, String? authToken}) async {
    if (kDebugMode) print("ApiService: search - Query: '$query', Type: $type");
    final queryParams = {'q': query};
    if (type != null && type.isNotEmpty) queryParams['type'] = type;

    final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: _getHeaders(authToken: authToken, isJsonContent: false),
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! List) return [];
    return jsonResponse as List<dynamic>; // Le type de retour dépend de ce que l'API de recherche renvoie
  }

  Future<Map<String, List<dynamic>>> searchAll(String query, {String? authToken}) async {
    if (kDebugMode) print("ApiService: searchAll - Query: '$query'");
    final uri = Uri.parse('$_baseUrl/api/search/all').replace(queryParameters: {'q': query});
    final response = await http.get(
      uri,
      headers: _getHeaders(authToken: authToken, isJsonContent: false),
    ).timeout(const Duration(seconds: 20));
    final jsonResponse = _handleResponse(response);
    if (jsonResponse == null || jsonResponse is! Map<String,dynamic>) return {};

    Map<String, List<dynamic>> results = {};
    if (jsonResponse['songs'] is List) {
      results['songs'] = (jsonResponse['songs'] as List).map((data) => Song.fromJson(data as Map<String,dynamic>)).toList();
    }
    if (jsonResponse['tags'] is List) {
      results['tags'] = (jsonResponse['tags'] as List).map((data) => Tag.fromJson(data as Map<String,dynamic>)).toList();
    }
    if (jsonResponse['playlists'] is List) {
      results['playlists'] = (jsonResponse['playlists'] as List).map((data) => Playlist.fromJson(data as Map<String,dynamic>)).toList();
    }
    // Ajoutez d'autres types comme artistes, albums si votre API les supporte
    return results;
  }
}