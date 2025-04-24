import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class MonetizationService {
  static const String baseUrl =
      'https://inzoneapi-912424781531.us-central1.run.app/';
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final StreamController<List<PurchaseDetails>> _purchaseController =
      StreamController<List<PurchaseDetails>>.broadcast();
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseController.stream;

  // Product IDs and their corresponding package IDs
  static const Map<String, String> productToPackageMap = {
    'InCashElite2025': 'elite_1500',
    'InCashAdvanced2025': 'advanced_500',
    'InCashBasic2025': 'basic_100',
    'InCashGold2025': 'gold_2500'
  };

  static const List<String> productIds = [
    'InCashElite2025',
    'InCashAdvanced2025',
    'InCashBasic2025'
  ];
  static const String subscriptionId = 'InCashGold2025';

  MonetizationService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (Platform.isIOS) {
      final storeKit = InAppPurchaseStoreKitPlatformAddition();
      await storeKit.setDelegate(null);
    }

    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    purchaseUpdated.listen(_handlePurchases);
  }

  Future<void> _handlePurchases(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        await _verifyAndDeliverProduct(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        print('Purchase error: ${purchaseDetails.error}');
        _purchaseController.add([purchaseDetails]);
      }
    }
  }

  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final platform = Platform.isIOS ? 'ios' : 'android';
      final verificationData = purchaseDetails.verificationData;
      final packageId = productToPackageMap[purchaseDetails.productID];

      if (packageId == null) {
        throw Exception('Invalid product ID');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/wallet/purchase-incash'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'UserDocumentId': user.uid,
          'PackageId': packageId,
          'Platform': platform,
          'ReceiptData': verificationData.localVerificationData,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          // For consumable products, complete the purchase after successful verification
          if (productIds.contains(purchaseDetails.productID)) {
            await _inAppPurchase.completePurchase(purchaseDetails);
          }
          _purchaseController.add([purchaseDetails]);
        } else {
          throw Exception(result['error'] ?? 'Purchase verification failed');
        }
      } else {
        throw Exception(
            'Purchase verification failed with status ${response.statusCode}');
      }
    } catch (e) {
      // print('Verification error: $e');
      // _purchaseController.add([
      //   PurchaseDetails(
      //     productID: purchaseDetails.productID,
      //     status: PurchaseStatus.error,
      //     error: PurchaseErrorDetails(
      //       code: PurchaseErrorCode.verificationFailed,
      //       message: e.toString(),
      //     ),
      //   )
      // ]);
    }
  }

  Future<List<ProductDetails>> getProducts() async {
    try {
      final ProductDetailsResponse response = await _inAppPurchase
          .queryProductDetails({...productIds, subscriptionId}.toSet());

      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found: ${response.notFoundIDs}');
      }

      if (response.error != null) {
        print('Error querying products: ${response.error}');
      }

      return response.productDetails;
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  Future<bool> purchaseProduct(String productId) async {
    try {
      final products = await getProducts();
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found'),
      );

      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );

      return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('Purchase error: $e');
      return false;
    }
  }

  Future<bool> subscribeToGoldPlan() async {
    try {
      final products = await getProducts();
      final product = products.firstWhere(
        (p) => p.id == subscriptionId,
        orElse: () => throw Exception('Subscription product not found'),
      );

      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: null,
      );

      return await _inAppPurchase.buyNonConsumable(
          purchaseParam: purchaseParam);
    } catch (e) {
      print('Subscription error: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      print('Restore error: $e');
    }
  }

  Future<Map<String, dynamic>> getBalance() async {
    try {
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
    } catch (e) {
      print('Error getting balance: $e');
      rethrow;
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

  Future<Map<String, dynamic>> purchaseInCash(
      String packageId, String platform, String receiptData) async {
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
