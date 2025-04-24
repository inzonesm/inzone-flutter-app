import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:inzone/components/bottom-sheet/bottom_sheet_bar.dart';
import 'package:inzone/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  int _balance = 0;
  bool _isLoading = true;

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        headers: <String, String>{"header_key": "header_value"},
      );
    } else {
      throw "Could not launch $url";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final response = await _monetizationService.getBalance();
      if (response['success'] == true) {
        setState(() {
          _balance = response['data']['balance'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading balance: $e')),
        );
      }
    }
  }

  Future<void> _purchasePackage(String packageId) async {
    try {
      // In a real app, you would get the receipt data from the platform's purchase API
      // For now, we'll use a placeholder
      final platform =
          Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';
      const receiptData = 'placeholder_receipt_data';

      final response = await _monetizationService.purchaseInCash(
          packageId, platform, receiptData);
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase successful')),
        );
        _loadBalance(); // Refresh balance
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error purchasing package: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  width: MediaQuery.of(context).size.width,
                  height: 60,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side:
                          const BorderSide(width: 1, color: Color(0XFFA3A3A3)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                        "Balance",
                        style: GoogleFonts.outfit(
                            color: const Color(0XFF17181C),
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                      )),
                      Row(
                        children: [
                          Image.asset("icons/settings/balance.png",
                              width: 20, height: 20),
                          const SizedBox(width: 5),
                          Text(
                            _balance.toString(),
                            style: GoogleFonts.outfit(
                                color: const Color(0XFF17181C),
                                fontSize: 16,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Image.asset(
                    "assets/images/subscription_header.png",
                    fit: BoxFit.fitWidth,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "InCash  Packages",
                    style: GoogleFonts.outfit(
                        color: const Color(0XFF17181C),
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w400),
                      children: <TextSpan>[
                        const TextSpan(
                            text: "By purchasing InCash, you agree to our"),
                        TextSpan(
                            text: ' Terms of Use',
                            style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _launchInBrowser(
                                    "https://inzone.ai/terms-conditions");
                              }),
                        const TextSpan(text: ' and '),
                        TextSpan(
                            text: 'Privacy Policy',
                            style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _launchInBrowser(
                                    "https://inzone.ai/privacy-policy");
                              }),
                        const TextSpan(
                            text: ", including the arbitration clause and "),
                        TextSpan(
                            text: 'revocation policy',
                            style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _launchInBrowser(
                                    "https://inzone.ai/revocation-policy");
                              }),
                        const TextSpan(
                            text:
                                ". You consent to the immediate performance of the contract and acknowledge that you thereby lose your right of withdrawal."),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      CustomBottomSheet(
                          backgroundColor: Colors.white,
                          isNeedMargin: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BottomSheetBar(),
                              const SizedBox(height: 16),
                              Text(
                                "In Cash Gold Plan",
                                style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                child: const PurchaseSubscriptionScreen(
                                  planName: "Gold Plan",
                                  price: 9.99,
                                  coins: 2500,
                                  productId: "InCashGold2025",
                                  isSubscription: true,
                                ),
                              )
                            ],
                          )).customBottomSheet(context);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        color: const Color(0xFFE0E0E0),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(width: 1, color: Colors.white),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration:
                                const BoxDecoration(color: Color(0xFF228AF3)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Gold Plan',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '\$9.99/ ',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Month',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Coins',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF17181C),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                                "icons/settings/balance.png",
                                                width: 20,
                                                height: 20),
                                            const SizedBox(width: 8),
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '2500/ ',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(
                                                          0xFF17181C),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: 'Month',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(
                                                          0xFF17181C),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      CustomBottomSheet(
                          backgroundColor: Colors.white,
                          isNeedMargin: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BottomSheetBar(),
                              const SizedBox(height: 16),
                              Text(
                                "In Cash Elite Plan",
                                style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                child: const PurchaseSubscriptionScreen(
                                  planName: "Elite Plan",
                                  price: 9.99,
                                  coins: 1500,
                                  productId: "InCashElite2025",
                                  isSubscription: false,
                                ),
                              )
                            ],
                          )).customBottomSheet(context);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: Colors.white),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE0E0E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Elite',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF17181C),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                                Container(
                                  child: Row(
                                    children: [
                                      Image.asset("icons/settings/balance.png",
                                          width: 20, height: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '1500',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF17181C),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$9.99',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF212121),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      CustomBottomSheet(
                          backgroundColor: Colors.white,
                          isNeedMargin: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BottomSheetBar(),
                              const SizedBox(height: 16),
                              Text(
                                "In Cash Advanced Plan",
                                style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                child: const PurchaseSubscriptionScreen(
                                  planName: "Advanced Plan",
                                  price: 4.99,
                                  coins: 500,
                                  productId: "InCashAdvanced2025",
                                  isSubscription: false,
                                ),
                              )
                            ],
                          )).customBottomSheet(context);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: Colors.white),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE0E0E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Advanced',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF17181C),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                                Container(
                                  child: Row(
                                    children: [
                                      Image.asset("icons/settings/balance.png",
                                          width: 20, height: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '500',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF17181C),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$4.99',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF212121),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      CustomBottomSheet(
                          backgroundColor: Colors.white,
                          isNeedMargin: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const BottomSheetBar(),
                              const SizedBox(height: 16),
                              Text(
                                "In Cash Basic Plan",
                                style: GoogleFonts.outfit(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                child: const PurchaseSubscriptionScreen(
                                  planName: "Basic Plan",
                                  price: 1.99,
                                  coins: 100,
                                  productId: "InCashBasic2025",
                                  isSubscription: false,
                                ),
                              )
                            ],
                          )).customBottomSheet(context);
                    },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: Colors.white),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE0E0E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Basic',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF17181C),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                                Container(
                                  child: Row(
                                    children: [
                                      Image.asset("icons/settings/balance.png",
                                          width: 20, height: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '100',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF17181C),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$1.99',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF212121),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ])
              ]),
            ),
    );
  }
}

class PurchaseSubscriptionScreen extends StatefulWidget {
  final String planName;
  final double price;
  final int coins;
  final bool isSubscription;
  final String productId;

  const PurchaseSubscriptionScreen({
    super.key,
    required this.planName,
    required this.price,
    required this.coins,
    required this.productId,
    this.isSubscription = false,
  });

  @override
  State<PurchaseSubscriptionScreen> createState() =>
      _PurchaseSubscriptionScreenState();
}

class _PurchaseSubscriptionScreenState
    extends State<PurchaseSubscriptionScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  bool _isPurchasing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _monetizationService.purchaseStream.listen(_handlePurchase);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handlePurchase(List<PurchaseDetails> purchases) {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase successful!')),
        );
        Navigator.of(context).pop();
      } else if (purchase.status == PurchaseStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Purchase failed: ${purchase.error?.message}')),
        );
      }
    }
    setState(() {
      _isPurchasing = false;
    });
  }

  Future<void> _purchase() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final products =
          await _monetizationService.getProducts([widget.productId]);
      if (products.isEmpty) {
        throw Exception('Product not found');
      }

      final success =
          await _monetizationService.purchaseProduct(products.first);
      if (!success) {
        throw Exception('Purchase failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        headers: <String, String>{"header_key": "header_value"},
      );
    } else {
      throw "Could not launch $url";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            width: MediaQuery.of(context).size.width,
            height: 60,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0XFFA3A3A3)),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                  "Balance",
                  style: GoogleFonts.outfit(
                      color: const Color(0XFF17181C),
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                )),
                Row(
                  children: [
                    Image.asset("icons/settings/balance.png",
                        width: 20, height: 20),
                    const SizedBox(width: 5),
                    Text(
                      "2345",
                      style: GoogleFonts.outfit(
                          color: const Color(0XFF17181C),
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                    )
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: ShapeDecoration(
              color: const Color(0xFFF5F5F5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'InCash ${widget.planName}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF17181C),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isSubscription) ...[
                          Text(
                            'Monthly',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF17181C),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Renews on: 10/08/2024',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF17181C),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'One-time Purchase',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF17181C),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${widget.coins} Coins',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF17181C),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '\$${widget.price.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF17181C),
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
              children: <TextSpan>[
                const TextSpan(
                    text:
                        "By clicking Purchase you acknowledge that you are 18 years of age, or that you are the parent or legal guardian of the account owner, and that you agree to our"),
                TextSpan(
                    text: ' Terms of Use',
                    style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchInBrowser("https://inzone.ai/terms-conditions");
                      }),
                const TextSpan(text: ' and '),
                TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchInBrowser("https://inzone.ai/privacy-policy");
                      }),
                const TextSpan(text: ", including the arbitration clause and "),
                TextSpan(
                    text: 'revocation policy',
                    style: GoogleFonts.outfit(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _launchInBrowser("https://inzone.ai/revocation-policy");
                      }),
                TextSpan(
                    text: widget.isSubscription
                        ? ". You consent to the immediate performance of the contract and acknowledge that you thereby lose your right of withdrawal. You will be charged \$${widget.price.toStringAsFixed(2)} monthly. Cancel anytime by contacting your app store - more information"
                        : ". You consent to the immediate performance of the contract and acknowledge that you thereby lose your right of withdrawal. This is a one-time purchase of \$${widget.price.toStringAsFixed(2)} for ${widget.coins} coins."),
                if (widget.isSubscription)
                  TextSpan(
                      text: ' here',
                      style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _launchInBrowser(
                              "https://inzone.ai/subscription-info");
                        }),
                const TextSpan(text: ". No partial refunds."),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(width: 1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))),
              const SizedBox(width: 10),
              Expanded(
                  child: GestureDetector(
                      onTap: _isPurchasing
                          ? null
                          : () => Get.find<InAppPurchaseController>()
                              .buyProduct(widget.productId),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(1.00, 0.00),
                            end: Alignment(-1, 0),
                            colors: [Color(0xFF125455), Color(0xFF29BABB)],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          _isPurchasing ? 'Processing...' : 'Purchase',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))),
            ],
          )
        ]));
  }
}
