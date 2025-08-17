import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
      userSpeechText:
          data['user_message_text'] ?? data['user_speech_text'] ?? '',
      aiResponseText: data['ai_response_text'] ?? '',
      aiResponseAudio: data['ai_response_audio'] ?? '',
      conversationId: data['conversation_id'] ?? '',
      coinsDeducted: data['coins_spent'] ?? data['coins_deducted'] ?? 0,
      remainingBalance: data['new_balance'] ?? data['remaining_balance'] ?? 0,
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

class EnhancedVoiceService {
  final Dio _dio = Dio();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⚠️ HARDCODED API KEY - 여기에 실제 API 키를 입력하세요!
  // ElevenLabs API 키: https://elevenlabs.io/api 에서 발급
  static const String ELEVENLABS_API_KEY =
      "sk_ad6f50123f65e1194a132e66907c72eb8275d378594a6527"; // ElevenLabs API 키

  // API URLs
  static const String _elevenLabsUrl =
      'https://api.elevenlabs.io/v1/text-to-speech';

  // AI Chat API endpoint (reusing existing endpoint)
  static const String _aiChatUrl =
      'https://ai-apis-912424781531.us-east1.run.app/chat/popularCharacter';

  /// Main method: Send text message and get AI voice response
  /// This method handles everything on the frontend:
  /// 1. Gets AI text response
  /// 2. Converts to speech using ElevenLabs
  /// 3. Saves conversation to Firebase
  Future<({VoiceResponse? response, VoiceError? error})> sendTextForVoice({
    required String userId,
    required String aiCharacterId,
    required String message,
    List<Set>? chatHistory,
  }) async {
    try {
      debugPrint('EnhancedVoiceService: Processing voice chat request...');
      debugPrint('User ID: $userId');
      debugPrint('AI Character ID: $aiCharacterId');
      debugPrint('Message: $message');

      // Debug: List available voices (remove this in production)
      await debugListAvailableVoices();

      // Step 1: Get AI character details from Firebase
      final aiCharDoc = await _firestore
          .collection('popularCharacters')
          .doc(aiCharacterId)
          .get();

      if (!aiCharDoc.exists) {
        return (
          response: null,
          error: VoiceError(
            message: 'AI character not found',
            currentBalance: 0,
            requiredCoins: 0,
          )
        );
      }

      final aiCharacter = aiCharDoc.data()!;
      // Voice ID is now directly on the document, not under voice_settings
      final voiceId =
          aiCharacter['voice_id'] as String? ?? 'JBFqnCBsd6RMkjVDRZzb';

      // Step 2: Check user's coin balance
      final userDoc =
          await _firestore.collection('humanUsers').doc(userId).get();

      if (!userDoc.exists) {
        return (
          response: null,
          error: VoiceError(
            message: 'User not found',
            currentBalance: 0,
            requiredCoins: 0,
          )
        );
      }

      final userData = userDoc.data()!;
      final currentBalance =
          userData['balance'] ?? 0; // Changed from 'incoin' to 'balance'
      const requiredCoins = 25; // Voice chat cost

      if (currentBalance < requiredCoins) {
        return (
          response: null,
          error: VoiceError(
            message: 'Insufficient balance',
            currentBalance: currentBalance,
            requiredCoins: requiredCoins,
          )
        );
      }

      // Step 3: Generate AI text response
      debugPrint('Generating AI response...');
      final aiResponseText = await _generateAIResponse(
        message: message,
        aiCharacterId: aiCharacterId,
        userId: userId,
        chatHistory: chatHistory,
      );

      if (aiResponseText == null) {
        return (
          response: null,
          error: VoiceError(
            message: 'Failed to generate AI response',
            currentBalance: currentBalance,
            requiredCoins: 0,
          )
        );
      }

      // Step 4: Convert AI response to speech using ElevenLabs
      debugPrint('Converting text to speech with voice ID: $voiceId');
      final audioBase64 = await _convertTextToSpeech(
        text: aiResponseText,
        voiceId: voiceId,
        voiceSettings: {}, // Using default voice settings
      );

      if (audioBase64 == null) {
        return (
          response: null,
          error: VoiceError(
            message: 'Failed to generate voice',
            currentBalance: currentBalance,
            requiredCoins: 0,
          )
        );
      }

      // Step 5: Save conversation to Firebase
      final conversationRef =
          await _firestore.collection('voice_conversations').add({
        'user_id': userId,
        'ai_character_id': aiCharacterId,
        'user_message': message,
        'ai_response': aiResponseText,
        'timestamp': FieldValue.serverTimestamp(),
        'interaction_type': 'voice_chat',
        'voice_id': voiceId,
        'coins_spent': requiredCoins,
      });

      // Step 6: Update user's coin balance
      await _firestore.collection('humanUsers').doc(userId).update({
        'balance': FieldValue.increment(
            -requiredCoins), // Changed from 'incoin' to 'balance'
      });

      // Step 7: Log analytics event
      await _logVoiceInteraction(
        userId: userId,
        aiCharacterId: aiCharacterId,
        conversationId: conversationRef.id,
      );

      return (
        response: VoiceResponse(
          userSpeechText: message,
          aiResponseText: aiResponseText,
          aiResponseAudio: audioBase64,
          conversationId: conversationRef.id,
          coinsDeducted: requiredCoins,
          remainingBalance: currentBalance - requiredCoins,
        ),
        error: null
      );
    } catch (e) {
      debugPrint('Error in sendTextForVoice: $e');
      return (
        response: null,
        error: VoiceError(
          message: 'An unexpected error occurred',
          currentBalance: 0,
          requiredCoins: 0,
        )
      );
    }
  }

  /// Process voice message (audio to text, then get AI response with voice)
  /// Note: This method requires speech_to_text to be handled by voice_screen.dart
  Future<({VoiceResponse? response, VoiceError? error})> sendVoiceMessage({
    required String userId,
    required String aiCharacterId,
    required File audioFile,
    List<Set>? chatHistory,
  }) async {
    try {
      debugPrint('Processing voice message...');

      // Voice screen already handles speech recognition using speech_to_text package
      // and sends the text directly to sendTextForVoice method
      // This method is kept for compatibility but not actively used

      return (
        response: null,
        error: VoiceError(
          message: 'Voice input should be processed through voice_screen.dart',
          currentBalance: 0,
          requiredCoins: 0,
        )
      );
    } catch (e) {
      debugPrint('Error in sendVoiceMessage: $e');
      return (
        response: null,
        error: VoiceError(
          message: 'Failed to process voice message',
          currentBalance: 0,
          requiredCoins: 0,
        )
      );
    }
  }

  /// Generate AI response using existing backend endpoint
  Future<String?> _generateAIResponse({
    required String message,
    required String aiCharacterId,
    required String userId,
    List<Set>? chatHistory,
  }) async {
    try {
      final chatHistoryJson =
          chatHistory?.map((s) => s.toList()).toList() ?? [];

      final response = await http.post(
        Uri.parse(_aiChatUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'ai_id': aiCharacterId,
          'user_id': userId,
          'chat_history': chatHistoryJson,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] != null) {
          return jsonResponse['data']['message'];
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error generating AI response: $e');
      return null;
    }
  }

  /// Convert text to speech using ElevenLabs API
  Future<String?> _convertTextToSpeech({
    required String text,
    required String voiceId,
    Map<String, dynamic>? voiceSettings,
  }) async {
    try {
      // Try with the provided voice ID first
      debugPrint('Attempting TTS with voice ID: $voiceId');

      final response = await _dio.post(
        '$_elevenLabsUrl/$voiceId',
        data: {
          'text': text,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': voiceSettings?['stability'] ?? 0.5,
            'similarity_boost': voiceSettings?['similarity_boost'] ?? 0.75,
            'style': voiceSettings?['style'] ?? 0.0,
            'use_speaker_boost': voiceSettings?['use_speaker_boost'] ?? true,
          }
        },
        options: Options(
          headers: {
            'Accept': 'audio/mpeg',
            'Content-Type': 'application/json',
            'xi-api-key': ELEVENLABS_API_KEY,
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('Successfully generated voice with ID: $voiceId');
        // Convert audio bytes to base64
        final bytes = response.data as List<int>;
        return base64Encode(bytes);
      }

      return null;
    } catch (e) {
      // Check if it's a 404 error (voice not found)
      if (e is DioException && e.response?.statusCode == 404) {
        debugPrint(
            'Voice ID $voiceId not found in ElevenLabs, trying fallback voice...');

        // Try with fallback voice ID
        const fallbackVoiceId = 'JBFqnCBsd6RMkjVDRZzb'; // George voice

        try {
          final fallbackResponse = await _dio.post(
            '$_elevenLabsUrl/$fallbackVoiceId',
            data: {
              'text': text,
              'model_id': 'eleven_monolingual_v1',
              'voice_settings': {
                'stability': 0.5,
                'similarity_boost': 0.75,
                'style': 0.0,
                'use_speaker_boost': true,
              }
            },
            options: Options(
              headers: {
                'Accept': 'audio/mpeg',
                'Content-Type': 'application/json',
                'xi-api-key': ELEVENLABS_API_KEY,
              },
              responseType: ResponseType.bytes,
            ),
          );

          if (fallbackResponse.statusCode == 200) {
            debugPrint(
                'Successfully generated voice with fallback ID: $fallbackVoiceId');
            // Convert audio bytes to base64
            final bytes = fallbackResponse.data as List<int>;
            return base64Encode(bytes);
          }
        } catch (fallbackError) {
          debugPrint('Fallback voice also failed: $fallbackError');
          return null;
        }
      }

      debugPrint('Error in text to speech conversion: $e');
      return null;
    }
  }

  /// Log voice interaction for analytics
  Future<void> _logVoiceInteraction({
    required String userId,
    required String aiCharacterId,
    required String conversationId,
  }) async {
    try {
      // Log to Firebase Analytics collection
      await _firestore.collection('voice_analytics').add({
        'user_id': userId,
        'ai_character_id': aiCharacterId,
        'conversation_id': conversationId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      debugPrint('Error logging voice interaction: $e');
    }
  }

  /// Get conversation history
  Future<List<Map<String, dynamic>>> getConversationHistory({
    required String userId,
    required String aiCharacterId,
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('voice_conversations')
          .where('user_id', isEqualTo: userId)
          .where('ai_character_id', isEqualTo: aiCharacterId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting conversation history: $e');
      return [];
    }
  }

  /// Debug function to list all available voices from ElevenLabs
  Future<void> debugListAvailableVoices() async {
    try {
      debugPrint('=== FETCHING AVAILABLE VOICES FROM ELEVENLABS ===');

      final response = await _dio.get(
        'https://api.elevenlabs.io/v1/voices',
        options: Options(
          headers: {
            'xi-api-key': ELEVENLABS_API_KEY,
          },
        ),
      );

      if (response.statusCode == 200) {
        final voices = response.data['voices'] as List;
        debugPrint('Found ${voices.length} voices in your account:');

        for (var voice in voices) {
          debugPrint('Voice: ${voice['name']} - ID: ${voice['voice_id']}');
        }

        // Check if the problematic voice ID exists
        const problematicId = 'SMHkF9u8z4tpQZiNqJ14';
        final voiceExists = voices.any((v) => v['voice_id'] == problematicId);

        if (voiceExists) {
          debugPrint('✅ Voice ID $problematicId FOUND in your account');
        } else {
          debugPrint('❌ Voice ID $problematicId NOT FOUND in your account');
          debugPrint('This voice might be:');
          debugPrint('  - Created in a different ElevenLabs account');
          debugPrint('  - Deleted from ElevenLabs');
          debugPrint('  - Not added to "My Voices" yet');
        }
      }

      debugPrint('===========================================');
    } catch (e) {
      debugPrint('Error fetching voices: $e');
    }
  }
}
