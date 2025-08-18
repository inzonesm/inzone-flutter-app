import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:inzone/data/avatar_data.dart';

class AvatarService {
  static const String baseUrl =
      'https://inzoneapi-912424781531.us-central1.run.app';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Access-Control-Allow-Origin': '*',
  };

  static const Duration _apiTimeout = Duration(minutes: 5);

  Future<AvatarData> generateAvatar(String prompt) async {
    try {
      debugPrint('Sending request to API: $baseUrl/api/generate_3d_avatar');
      debugPrint('Prompt: $prompt');

      final requestBody = jsonEncode({'prompt': prompt});
      debugPrint('Request body: $requestBody');

      final client = http.Client();

      final response = await client
          .post(
        Uri.parse('$baseUrl/api/generate_3d_avatar'),
        headers: _headers,
        body: requestBody,
      )
          .timeout(_apiTimeout, onTimeout: () {
        client.close();
        throw Exception(
            'API request timed out after 5 minutes. The server might be busy, please try again later.');
      });

      client.close();

      debugPrint('Response status code: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return AvatarData.fromJson(data);
      } else {
        String errorMessage;
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? 'Failed to generate avatar';
        } catch (e) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        debugPrint('API error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('API Error details: $e');
      if (e.toString().contains("HEADERS")) {
        throw Exception(
            'API configuration error. Please check connection and try again.');
      } else if (e.toString().contains("SocketException")) {
        throw Exception(
            'Network connection failed. Please check your internet connection.');
      } else if (e.toString().contains("TimeoutException")) {
        throw Exception(
            'Request timed out after 5 minutes. The server might be busy, please try again later.');
      }
      throw Exception('Network error: $e');
    }
  }

  Future<AvatarData> generateMockAvatar(String prompt) async {
    await Future.delayed(const Duration(seconds: 3));

    return AvatarData(
      modelGlb: 'assets/3d/first.glb',
      modelObj: '',
      texture: '',
      thumbnail: '',
      seed: 12345,
    );
  }
}
