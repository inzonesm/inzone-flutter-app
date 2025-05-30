import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:inzone/data/avatar_data.dart';

class AvatarService {
  // API endpoint URL
  static const String baseUrl =
      'https://inzoneapi-912424781531.us-central1.run.app';

  // Common headers for API requests
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Access-Control-Allow-Origin': '*', // For CORS issues
  };

  // 더 긴 타임아웃 설정 (5분 = 300초)
  static const Duration _apiTimeout = Duration(minutes: 5);

  // Generate 3D avatar from prompt
  Future<AvatarData> generateAvatar(String prompt) async {
    try {
      debugPrint('Sending request to API: $baseUrl/api/generate_3d_avatar');
      debugPrint('Prompt: $prompt');

      final requestBody = jsonEncode({'prompt': prompt});
      debugPrint('Request body: $requestBody');

      // HTTP 클라이언트 생성 및 타임아웃 설정
      final client = http.Client();

      // API 호출 (타임아웃 5분)
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

      // 요청 완료 후 클라이언트 닫기
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
      // 오류 메시지에 따른 구체적인 피드백
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

  // For development and testing - returns mock data
  Future<AvatarData> generateMockAvatar(String prompt) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 3));

    // Return mock data with a known valid asset path
    return AvatarData(
      modelGlb:
          'assets/3d/first.glb', // Make sure this file exists in your assets
      modelObj: '', // Optional, can be empty
      texture: '',
      thumbnail: '',
      seed: 12345,
    );
  }
}
