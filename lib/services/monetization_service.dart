import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inzone/data/inzone_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonetizationService {
  static const String baseUrl = 'https://inzoneapi-912424781531.us-central1.run.app/'; // Replace with your actual API URL

  // Get user's balance
  Future<Map<String, dynamic>> getBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/wallet/balance?UserDocumentId=${user.uid}'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get balance');
    }
  }

  // Purchase InCash
  Future<Map<String, dynamic>> purchaseInCash(String packageId, String platform, String receiptData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/wallet/purchase-incash'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'UserDocumentId': user.uid,
        'PackageId': packageId,
        'Platform': platform,
        'ReceiptData': receiptData,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to purchase InCash');
    }
  }

  // Get transaction history
  Future<Map<String, dynamic>> getTransactionHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/wallet/transaction-history?UserDocumentId=${user.uid}'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get transaction history');
    }
  }

  // Generate referral code
  Future<Map<String, dynamic>> generateReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/user/generate-referral-code'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'UserDocumentId': user.uid,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to generate referral code');
    }
  }

  // Apply referral code
  Future<Map<String, dynamic>> applyReferralCode(String referralCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.post(
      Uri.parse('$baseUrl/user/apply-referral'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'UserDocumentId': user.uid,
        'ReferralCode': referralCode,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to apply referral code');
    }
  }

  // Get referral stats
  Future<Map<String, dynamic>> getReferralStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final response = await http.get(
      Uri.parse('$baseUrl/user/referral-stats?UserDocumentId=${user.uid}'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get referral stats');
    }
  }
} 