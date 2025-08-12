import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VoiceResponse {
  final String userSpeechText;
  final String aiResponseText;
  final String aiResponseAudio; // base64 encoded
  final String conversationId;
  final int coinsDeducted;
  final int remainingBalance;

  VoiceResponse({
    required this.userSpeechText,
    required this.aiResponseText,
    required this.aiResponseAudio,
    required this.conversationId,
    required this.coinsDeducted,
    required this.remainingBalance,
  });

  factory VoiceResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return VoiceResponse(
      userSpeechText: data['user_message_text'] ??
          data['user_speech_text'] ??
          '', // Support both field names
      aiResponseText: data['ai_response_text'] ?? '',
      aiResponseAudio: data['ai_response_audio'] ?? '',
      conversationId: data['conversation_id'] ?? '',
      coinsDeducted: data['coins_spent'] ??
          data['coins_deducted'] ??
          0, // Support both field names
      remainingBalance: data['new_balance'] ??
          data['remaining_balance'] ??
          0, // Support both field names
    );
  }
}

class VoiceError {
  final String message;
  final int currentBalance;
  final int requiredCoins;

  VoiceError({
    required this.message,
    required this.currentBalance,
    required this.requiredCoins,
  });

  factory VoiceError.fromJson(Map<String, dynamic> json) {
    return VoiceError(
      message: json['error'] ?? 'Unknown error',
      currentBalance: json['current_balance'] ?? 0,
      requiredCoins: json['required_coins'] ?? 0,
    );
  }
}

class VoiceService {
  static const String baseUrl =
      'https://inzoneapi-912424781531.us-central1.run.app';
  static const String voiceEndpoint = '/api/ai/voice/full-conversation';
  static const String voiceChatEndpoint = '/api/ai/voice/chat';

  final Dio _dio = Dio();

  // New method: Send text message and get voice response
  Future<({VoiceResponse? response, VoiceError? error})> sendTextForVoice({
    required String userId,
    required String aiCharacterId,
    required String message,
  }) async {
    try {
      debugPrint('Sending text message for voice response...');
      debugPrint('User ID: $userId');
      debugPrint('AI Character ID: $aiCharacterId');
      debugPrint('Message: $message');

      final response = await _dio.post(
        '$baseUrl$voiceChatEndpoint',
        data: {
          'user_id': userId,
          'ai_character_id': aiCharacterId,
          'message': message,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('========== Full API Response Data ==========');
      debugPrint(jsonEncode(response.data));
      debugPrint('============================================');

      if (response.statusCode == 200 && response.data['success'] == true) {
        // Adapt the response to match VoiceResponse format
        final data = response.data['data'];

        debugPrint('========== Parsed Response Fields ==========');
        debugPrint('AI Response Text: ${data['ai_response_text']}');
        debugPrint('Coins Spent: ${data['coins_spent']}');
        debugPrint('New Balance: ${data['new_balance']}');
        debugPrint(
            'Audio Data Present: ${data['ai_response_audio'] != null ? 'Yes' : 'No'}');
        if (data['ai_response_audio'] != null) {
          debugPrint(
              'Audio Data Length: ${(data['ai_response_audio'] as String).length} chars');
        }
        debugPrint('============================================');

        final adaptedResponse = {
          'success': true,
          'data': {
            'user_message_text': message, // Use the sent message
            'ai_response_text': data['ai_response_text'],
            'ai_response_audio': data['ai_response_audio'],
            'conversation_id':
                '', // This endpoint doesn't return conversation_id
            'coins_spent': data['coins_spent'],
            'new_balance': data['new_balance'],
          }
        };
        return (response: VoiceResponse.fromJson(adaptedResponse), error: null);
      } else {
        debugPrint('API request failed: ${response.data}');
        return (response: null, error: null);
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.message}');
      debugPrint('Dio error type: ${e.type}');
      if (e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
        debugPrint('Error response status: ${e.response?.statusCode}');

        // Handle specific error responses
        if (e.response?.statusCode == 400 && e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData['success'] == false && errorData.containsKey('error')) {
            final voiceError = VoiceError.fromJson(errorData);
            return (response: null, error: voiceError);
          }
        }
      }
      return (response: null, error: null);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return (response: null, error: null);
    }
  }

  Future<({VoiceResponse? response, VoiceError? error})> sendVoiceMessage({
    required String userId,
    required String aiCharacterId,
    required File audioFile,
  }) async {
    try {
      debugPrint('Sending voice message to API...');
      debugPrint('User ID: $userId');
      debugPrint('AI Character ID: $aiCharacterId');
      debugPrint('Audio file path: ${audioFile.path}');

      FormData formData = FormData.fromMap({
        'user_id': userId,
        'ai_character_id': aiCharacterId,
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'recording.wav',
        ),
      });

      final response = await _dio.post(
        '$baseUrl$voiceEndpoint',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('========== Full Voice API Response Data ==========');
      debugPrint(jsonEncode(response.data));
      debugPrint('==================================================');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        debugPrint('========== Parsed Voice Response Fields ==========');
        debugPrint(
            'User Speech Text: ${data['user_speech_text'] ?? data['user_message_text'] ?? 'N/A'}');
        debugPrint('AI Response Text: ${data['ai_response_text']}');
        debugPrint('Conversation ID: ${data['conversation_id'] ?? 'N/A'}');
        debugPrint(
            'Coins Spent/Deducted: ${data['coins_spent'] ?? data['coins_deducted'] ?? 'N/A'}');
        debugPrint(
            'New/Remaining Balance: ${data['new_balance'] ?? data['remaining_balance'] ?? 'N/A'}');
        debugPrint(
            'Audio Data Present: ${data['ai_response_audio'] != null ? 'Yes' : 'No'}');
        if (data['ai_response_audio'] != null) {
          debugPrint(
              'Audio Data Length: ${(data['ai_response_audio'] as String).length} chars');
        }
        debugPrint('==================================================');

        return (response: VoiceResponse.fromJson(response.data), error: null);
      } else {
        debugPrint('API request failed: ${response.data}');
        return (response: null, error: null);
      }
    } on DioException catch (e) {
      debugPrint('Dio error: ${e.message}');
      debugPrint('Dio error type: ${e.type}');
      if (e.response != null) {
        debugPrint('Error response data: ${e.response?.data}');
        debugPrint('Error response status: ${e.response?.statusCode}');

        // Handle specific error responses
        if (e.response?.statusCode == 400 && e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData['success'] == false && errorData.containsKey('error')) {
            final voiceError = VoiceError.fromJson(errorData);
            return (response: null, error: voiceError);
          }
        }
      }
      return (response: null, error: null);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return (response: null, error: null);
    }
  }
}
