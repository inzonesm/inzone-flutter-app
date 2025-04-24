import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class MonetizationService {
  static const String _subscriptionId = 'InCashGold2025';
  static const String baseUrl = 'https://inzoneapi-912424781531.us-central1.run.app/';
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final StreamController<List<PurchaseDetails>> _purchaseController = StreamController<List<PurchaseDetails>>.broadcast();
  Stream<List<PurchaseDetails>> get purchaseStream => _purchaseController.stream;

  MonetizationService() {
    _initialize();
  }

  Future<void> _initialize() async {
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
      _handlePurchases(purchaseDetailsList);
    });
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Handle successful purchase
        await _verifyAndDeliverProduct(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle purchase error
        print('Purchase error: ${purchaseDetails.error}');
      }
    }
    _purchaseController.add(purchaseDetailsList);
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    // Verify the purchase with your backend
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  Future<List<ProductDetails>> getProducts(List<String> productIds) async {
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(productIds.toSet());
    if (response.notFoundIDs.isNotEmpty) {
      print('Products not found: ${response.notFoundIDs}');
    }
    return response.productDetails;
  }

  Future<bool> purchaseProduct(ProductDetails product) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null,
    );

    return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<bool> subscribeToGoldPlan() async {
    final List<ProductDetails> products = await getProducts([_subscriptionId]);
    if (products.isEmpty) {
      print('Subscription product not found');
      return false;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: products.first,
      applicationUserName: null,
    );

    return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
    }
  }

  void dispose() {
    _purchaseController.close();
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
      throw Exception('Failed to process purchase');
    }
  }
}
class InAppPurchaseProvider extends ChangeNotifier {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final List<String> _productIds = [
    'InCashGold2025',
    'InCashElite2025',
    'InCashAdvanced2025',
    'InCashBasic2025',
  ];

  bool _isAvailable = false;
  List<ProductDetails> _products = [];

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;

  InAppPurchaseProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    notifyListeners();

    if (_isAvailable) {
      _listenToPurchases();
      await _getProducts();
    }
  }

  void _listenToPurchases() {
    _inAppPurchase.purchaseStream.listen((purchases) {
      _handlePurchaseUpdates(purchases);
    });
  }

  Future<void> _getProducts() async {
    final response = await _inAppPurchase.queryProductDetails(_productIds.toSet());
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyPurchase(purchase);
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        // Use your own error display logic here, e.g. a dialog or snackbar
        // For example, you could use a callback or a custom error notifier
        debugPrint('Purchase failed: ${purchase.error?.message}');
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      final platform = Theme.of(Get.context!).platform == TargetPlatform.iOS ? 'ios' : 'android';
      final response = await MonetizationService().purchaseInCash(
        purchase.productID,
        platform,
        purchase.verificationData.localVerificationData,
      );
      
      if (response['success'] == true) {
        Get.snackbar(
          'Success',
          'Purchase successful!',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        throw Exception('Purchase verification failed');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Purchase verification failed: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> buyProduct(String productId) async {
    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );

      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );

      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to purchase: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to restore purchases: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
} 
