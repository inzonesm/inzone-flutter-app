import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test if the backend notification API is working
Future<void> testBackendNotificationAPI() async {
  print('🧪 Testing backend notification API...');
  
  const String apiUrl = 'https://inzoneapi-912424781531.us-central1.run.app';
  
  try {
    // Test 1: Check if the API is reachable
    print('\n1. Testing API health...');
    final healthResponse = await http.get(
      Uri.parse('$apiUrl/health'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    print('Health check status: ${healthResponse.statusCode}');
    if (healthResponse.statusCode == 200) {
      print('✅ Backend API is reachable');
    } else {
      print('❌ Backend API health check failed: ${healthResponse.body}');
    }
    
    // Test 2: Test notification event endpoint
    print('\n2. Testing notification event endpoint...');
    final notificationResponse = await http.post(
      Uri.parse('$apiUrl/api/notifications/events/direct-message'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chatId': 'test-chat-123',
        'content': 'Test notification message',
        'senderId': 'test-sender-123',
        'receiverId': 'test-receiver-123',
        'timestamp': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 10));
    
    print('Notification event status: ${notificationResponse.statusCode}');
    print('Notification event response: ${notificationResponse.body}');
    
    if (notificationResponse.statusCode == 200) {
      print('✅ Notification event endpoint is working');
    } else {
      print('❌ Notification event endpoint failed');
    }
    
    // Test 3: Test token registration endpoint
    print('\n3. Testing token registration endpoint...');
    final tokenResponse = await http.post(
      Uri.parse('$apiUrl/api/notifications/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': 'test-user-123',
        'token': 'test-fcm-token-123',
      }),
    ).timeout(const Duration(seconds: 10));
    
    print('Token registration status: ${tokenResponse.statusCode}');
    print('Token registration response: ${tokenResponse.body}');
    
    if (tokenResponse.statusCode == 200) {
      print('✅ Token registration endpoint is working');
    } else {
      print('❌ Token registration endpoint failed');
    }
    
  } catch (e) {
    print('❌ Error testing backend API: $e');
  }
}

void main() async {
  await testBackendNotificationAPI();
}
