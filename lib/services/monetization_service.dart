import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonetizationService {
  // Product IDs
  static final String _subscriptionId =
      Platform.isIOS ? 'InCashGold' : '2025incashgold';
  static final Map<String, String> _productIds = {
    // iOS packages
    'gold_subscription': 'InCashGold', // Monthly subscription
    'elite_package': 'InCashElite2025', // One-time purchase
    'advanced_package': 'InCashAdvanced2025',
    'basic_package': 'InCashBasic2025',

    // Android packages
    'gold_subscription_android': '2025incashgold', // Monthly subscription
    'elite_package_android': '2025incashelite', // One-time purchase
    'advanced_package_android': '2025incashadvanced',
    'basic_package_android': '2025incashbasic',
  };

  // Get the appropriate product ID based on platform
  String getProductId(String key) {
    final platformKey = Platform.isIOS ? key : '${key}_android';
    return _productIds[platformKey] ?? '';
  }

  static const String baseUrl =
      'https://inzoneapi-912424781531.us-central1.run.app/';
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  String get userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  MonetizationService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check if the store is available
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      // Store is not available, handle accordingly
      debugPrint('Store is not available');
      return;
    }

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _handlePurchases(purchaseDetailsList);
    });
  }

  Future<void> _handlePurchases(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Process the purchase with our backend
        await _registerPurchaseWithBackend(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Error handling
        debugPrint('Purchase error: ${purchaseDetails.error}');
      }

      // Always complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    }

    _purchaseController.add(purchaseDetailsList);
  }

  Future<void> _registerPurchaseWithBackend(
      PurchaseDetails purchaseDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get the receipt data from the purchase details
      String receiptData;

      // For iOS, we need to use serverVerificationData for backend verification
      // For Android, localVerificationData contains the purchase token
      if (Platform.isIOS) {
        // On iOS, serverVerificationData contains the receipt data needed for verification
        receiptData = purchaseDetails.verificationData.serverVerificationData;
      } else {
        // On Android, localVerificationData contains the purchase token
        receiptData = purchaseDetails.verificationData.localVerificationData;

        // For Android, we might need to parse the JSON to get the purchase token
        try {
          final Map<String, dynamic> purchaseData = json.decode(receiptData);
          if (purchaseData.containsKey('purchaseToken')) {
            receiptData = purchaseData['purchaseToken'];
          }
        } catch (e) {
          // If parsing fails, use the original receipt data
          debugPrint('Error parsing Android purchase data: $e');
        }
      }

      String packageId = purchaseDetails.productID;
      String platform = Platform.isIOS ? 'ios' : 'android';

      // Send purchase information to backend
      await purchaseInCash(packageId, platform, receiptData);

      // If this is a subscription, update subscription status
      if (packageId == _subscriptionId) {
        await updateSubscriptionStatus(platform, packageId, receiptData);
      }
    } catch (e) {
      debugPrint('Error registering purchase: $e');
    }
  }

  Future<List<ProductDetails>> getProducts(List<String> productIds) async {
    // First check if the store is available
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('Store is not available');
      return [];
    }

    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(productIds.toSet());
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }
    return response.productDetails;
  }

  Future<bool> purchaseProduct(ProductDetails product) async {
    try {
      // bool isSubscription = product.id == _subscriptionId;

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId,
      );

      return await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error purchasing product: $e');
      return false;
    }
  }

  Future<bool> subscribeToGoldPlan() async {
    try {
      final List<ProductDetails> products =
          await getProducts([_subscriptionId]);
      if (products.isEmpty) {
        debugPrint('Subscription product not found: $_subscriptionId');
        // Print all available product IDs for debugging
        final allProducts = await getProducts(_productIds.values.toList());
        debugPrint(
            'Available products: ${allProducts.map((p) => p.id).toList()}');
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: products.first,
        applicationUserName: userId,
      );

      // For both iOS and Android, subscriptions should use buyNonConsumable
      return await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error subscribing to Gold plan: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      // Check if the store is available
      final bool isAvailable = await _inAppPurchase.isAvailable();
      if (!isAvailable) {
        debugPrint('Store is not available');
        return false;
      }

      // For iOS, we need to use the StoreKit API
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatformAddition.setDelegate(null);
      }

      await _inAppPurchase.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  void dispose() {
    _purchaseController.close();
  }

  // Generate referral code
  Future<Map<String, dynamic>> generateReferralCode() async {
    // Mock for debug mode
    if (kDebugMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'data': {
          'referral_code': 'DEBUG-REF-CODE-1234',
        },
      };
    }

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
    // Mock for debug mode
    if (kDebugMode) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'data': {
          'referral_history': [
            {
              'name': 'Test User',
              'photo_url': '',
              'date': DateTime.now().toUtc().toString().split(' ')[0],
              'phone': '1234567890', // normalized phone number (digits only)
            },
          ],
        },
      };
    }

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

  Future<Map<String, dynamic>> getBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.isEmpty) {
      throw Exception('User not logged in or UID missing');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/wallet/balance?UserDocumentId=${user.uid}'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get balance');
    }
  }

  Future<Map<String, dynamic>> purchaseInCash(
      String packageId, String platform, String receiptData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
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

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Failed to process purchase');
      }
    } catch (e) {
      debugPrint('Error in purchaseInCash: $e');
      rethrow;
    }
  }

  // Update subscription status with the backend - public method that can be called from outside
  Future<Map<String, dynamic>> updateSubscriptionStatus(
      String platform, String subscriptionId, String receiptData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/update-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'UserDocumentId': user.uid,
          'Platform': platform,
          'SubscriptionId': subscriptionId,
          'ReceiptData': receiptData,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(
            responseData['error'] ?? 'Failed to update subscription status');
      }
    } catch (e) {
      debugPrint('Error updating subscription status: $e');
      rethrow;
    }
  }

  // Spend InCash to join a group chat
  Future<Map<String, dynamic>> spendInCashForGroupAccess(
      String groupId, int cost) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet/spend-incash'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'UserDocumentId': user.uid,
          'Amount': cost,
          'Purpose': 'group_access',
          'GroupId': groupId,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Failed to process payment');
      }
    } catch (e) {
      debugPrint('Error in spendInCashForGroupAccess: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Send tip to another user
  Future<Map<String, dynamic>> sendTip(
      String recipientHandle, int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/tip/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender_id': user.uid,
          'recipient_handle': recipientHandle,
          'amount': amount,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': {
            'newBalance': responseData['new_balance'],
            'tipId': responseData['tip_id'],
          }
        };
      } else {
        throw Exception(responseData['error'] ?? 'Failed to send tip');
      }
    } catch (e) {
      debugPrint('Error in sendTip: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

//   // Check subscription status
//   Future<bool> isSubscribed({bool verify = false}) async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) return false;

//       final response = await http.get(
//         Uri.parse(
//             '$baseUrl/wallet/subscription-status?UserDocumentId=${user.uid}&verify=${verify ? 'true' : 'false'}'),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data['data']['isSubscribed'] ?? false;
//       } else {
//         return false;
//       }
//     } catch (e) {
//       debugPrint('Error checking subscription status: $e');
//       return false;
//     }
//   }
}
