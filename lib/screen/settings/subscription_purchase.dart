import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/components/bottom-sheet/bottom_sheet_bar.dart';
import 'package:inzone/components/bottom-sheet/custom_bottom_sheet.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:inzone/screen/settings/subcription_tile.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  int _balance = 0;
  bool _isLoading = true;
  String? _selectedPlan;

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
    return ColorfulSafeArea(
      top: false,
      color: Theme.of(context).cardColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Image.asset(
                          "assets/images/subImage.png",
                          fit: BoxFit.fitWidth,
                          width: MediaQuery.of(context).size.width,
                          height: 300,
                        ),
                        Positioned(
                          top: 70,
                          right: 20,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .cardColor
                                    .withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(FeatherIcons.x, size: 20),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Theme.of(context).cardColor.withOpacity(0),
                                  Theme.of(context).cardColor.withOpacity(0.6),
                                  Theme.of(context).cardColor,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            "InCash Packages",
                            style: Theme.of(context)
                                .textTheme
                                .headlineLarge!
                                .copyWith(fontSize: 24),
                            maxLines: 1,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).canvasColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset("icons/settings/balance.png",
                                  width: 20, height: 20),
                              const SizedBox(width: 5),
                              Text(
                                "Balance",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                      fontSize: 16,
                                    ),
                                maxLines: 1,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _balance.toString(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge!
                                    .copyWith(
                                      fontSize: 16,
                                    ),
                                maxLines: 1,
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    SubscriptionTile(
                      price: "\$9.99",
                      coins: "2500",
                      onLeftButtonClick: () {
                        setState(() {
                          _selectedPlan = "Gold";
                        });
                      },
                      isSelected: _selectedPlan == "Gold",
                      isMonth: true,
                    ),
                    SubscriptionTile(
                      price: "\$9.99",
                      coins: "1500",
                      onLeftButtonClick: () {
                        setState(() {
                          _selectedPlan = "Elite";
                        });
                      },
                      isSelected: _selectedPlan == "Elite",
                      isMonth: false,
                    ),
                    SubscriptionTile(
                      price: "\$4.99",
                      coins: "500",
                      onLeftButtonClick: () {
                        setState(() {
                          _selectedPlan = "Advanced";
                        });
                      },
                      isSelected: _selectedPlan == "Advanced",
                      isMonth: false,
                    ),
                    SubscriptionTile(
                      price: "\$1.99",
                      coins: "100",
                      onLeftButtonClick: () {
                        setState(() {
                          _selectedPlan = "Basic";
                        });
                      },
                      isSelected: _selectedPlan == "Basic",
                      isMonth: false,
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          children: <TextSpan>[
                            const TextSpan(
                              text: "By purchasing InCash, you agree to our ",
                            ),
                            TextSpan(
                              text: 'Terms of Use',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _launchInBrowser(
                                      "https://inzone.ai/terms-conditions");
                                },
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _launchInBrowser(
                                      "https://inzone.ai/privacy-policy");
                                },
                            ),
                            const TextSpan(
                                text:
                                    ", including arbitration and revocation policies. "),
                            TextSpan(
                              text: 'Revocation Policy',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _launchInBrowser(
                                      "https://inzone.ai/revocation-policy");
                                },
                            ),
                            const TextSpan(
                                text:
                                    " You consent to immediate performance of the contract and acknowledge losing your right of withdrawal."),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
        bottomNavigationBar: (_selectedPlan != null)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () async {
                    if (_selectedPlan == "Gold") {
                      // Gold면 CustomBottomSheet만 띄운다 (아무 결제하지 마라)
                      CustomBottomSheet.show(
                        context: context,
                        backgroundColor: Theme.of(context).cardColor,
                        isNeedMargin: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const BottomSheetBar(),
                            const SizedBox(height: 16),
                            Text(
                              "In Cash $_selectedPlan Plan",
                              style: GoogleFonts.outfit(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            PurchaseSubscriptionScreen(
                              planName: "$_selectedPlan Plan",
                              price: 9.99,
                              coins: 2500,
                              productId: "InCashGold",
                              isSubscription: true,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    } else {
                      // 나머지는 바로 구매
                      final productId = _selectedPlan == "Elite"
                          ? "InCashElite2025"
                          : _selectedPlan == "Advanced"
                              ? "InCashAdvanced2025"
                              : "InCashBasic2025";

                      final products =
                          await _monetizationService.getProducts([productId]);
                      if (products.isNotEmpty) {
                        await _monetizationService
                            .purchaseProduct(products.first);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Product not found')),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment(1.00, 0.00),
                        end: Alignment(-1, 0),
                        colors: [Color(0xFF125455), Color(0xFF29BABB)],
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      "Buy Now",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
            : null,
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
  int _balance = 0;
  bool _isPurchasing = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isDisposed = false;

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
    _subscription = _monetizationService.purchaseStream.listen(_handlePurchase);
  }

  Future<void> _initializePurchase() async {
    try {
      _subscription =
          _monetizationService.purchaseStream.listen(_handlePurchase);
      await _loadBalance();
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing purchase: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final response = await _monetizationService.getBalance();
      if (response['success'] == true && response['data'] != null) {
        if (!_isDisposed) {
          setState(() {
            _balance = response['data']['balance'] as int;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading balance: $e');
    }
  }

  void _handlePurchase(List<PurchaseDetails> purchases) {
    if (_isDisposed) return;

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
    if (!_isDisposed) {
      setState(() {
        _isPurchasing = false;
      });
    }
  }

  Future<void> _purchase() async {
    if (_isPurchasing) return;

    setState(() {
      _isPurchasing = true;
    });

    try {
      final products =
          await _monetizationService.getProducts([widget.productId]);
      if (products.isEmpty) {
        throw Exception('Product not found');
      }

      await _monetizationService.purchaseProduct(products.first);
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            width: MediaQuery.of(context).size.width,
            height: 60,
            decoration: ShapeDecoration(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                side:
                    BorderSide(width: 1, color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                  "Balance",
                  style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'InCash ${widget.planName}',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
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
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Renews on: 10/08/2024',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'One-time Purchase',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${widget.coins} Coins',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
              children: <TextSpan>[
                const TextSpan(
                    text:
                        "By clicking Purchase you acknowledge that you are 18 years of age, or that you are the parent or legal guardian of the account owner, and that you agree to our"),
                TextSpan(
                    text: ' Terms of Use',
                    style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ))),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _isPurchasing ? null : _purchase,
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
                  ),
                ),
              ),
            ],
          )
        ]));
  }
}
