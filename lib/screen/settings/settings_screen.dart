import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:inzone/components/settings/settings_tile.dart';
import 'package:inzone/components/ui/appbar.dart';
import 'package:toasty_box/toast_service.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:purchases_flutter/models/store_transaction.dart'
    show StoreTransaction;
import 'package:purchases_flutter/purchases_flutter.dart' show Purchases;
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:inzone/services/auth_service.dart';
import 'package:inzone/services/reward_ad_service.dart';
import 'package:inzone/services/account_lifecycle_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  final RewardAdService _rewardAdService = RewardAdService();
  final AccountLifecycleService _accountLifecycleService =
      AccountLifecycleService();
  final adunitId = Platform.isAndroid
      ? "ca-app-pub-4474122990542651/6949210208"
      : "ca-app-pub-4474122990542651/7222071742";

  int _remainingAds = 5;
  String _freeInCashSubtitle = "Watch ads to earn InCash (5 per day)";

  @override
  void initState() {
    super.initState();
    _loadRemainingAds();
  }

  /// Load remaining ads count and update subtitle
  Future<void> _loadRemainingAds() async {
    final remaining = await _rewardAdService.getRemainingRewardAds();
    setState(() {
      _remainingAds = remaining;
      _freeInCashSubtitle =
          "Watch ads to earn InCash ($remaining remaining today)";
    });
  }

  Future<void> _launchInBrowser(String url) async {
    try {
      if (await canLaunch(url)) {
        await launch(
          url,
          forceSafariVC: false,
          forceWebView: false,
          headers: <String, String>{"header_key": "header_value"},
        );
      } else {
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Unable to open the link. Please try again later.',
          );
        }
      }
    } catch (e) {
      print('Error launching URL: $e');
      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons.error,
            color: Colors.redAccent,
          ),
          message:
              'Unable to open the link. Please check your internet connection.',
        );
      }
    }
  }

  void presentPaywall() async {
    try {
      // Check if user is authenticated first
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
            ),
            message: 'Please sign in to view subscription options.',
          );
        }
        return;
      }

      // Try to check if RevenueCat is configured
      try {
        await Purchases.getCustomerInfo();
      } catch (e) {
        print('RevenueCat not initialized, attempting to configure...');
        // RevenueCat might not be initialized, show error
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message:
                'Unable to load subscription service. Please restart the app.',
          );
        }
        return;
      }

      final paywallResult = await RevenueCatUI.presentPaywall();

      print('Paywall result: $paywallResult ${paywallResult.name}');
      if (paywallResult == PaywallResult.purchased ||
          paywallResult == PaywallResult.restored) {
        // Retrieve the latest customer information
        final customerInfo = await Purchases.getCustomerInfo();
        final transactions = List<StoreTransaction>.from(
            customerInfo.nonSubscriptionTransactions);
        if (transactions.isNotEmpty) {
          // Sort transactions by purchase date in descending order
          print(transactions);
          transactions.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

          for (var item in transactions) {
            print(item.productIdentifier);
            print(item.purchaseDate);
            print("\n\n");
          }

          try {
            // Get the most recent transaction
            final latestTransaction = transactions.first;
            final String productId = latestTransaction.productIdentifier;
            final String platform = Platform.isIOS ? 'ios' : 'android';

            // Get receipt data from the transaction
            final String receiptData = latestTransaction.transactionIdentifier;

            // Process the purchase with our backend
            if (Platform.isAndroid) {
              if (productId == "2025incashadvanced") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "2025incashelite") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "2025incashbasic") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "2025incashgold" ||
                  productId == "2025incashgold:2025incashgold") {
                // For subscription, we also need to update subscription status
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              }
            } else if (Platform.isIOS) {
              if (productId == "InCashGold") {
                // For subscription, we also need to update subscription status
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "InCashAdvanced2025") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "InCashElite2025") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              } else if (productId == "InCashBasic2025") {
                await _monetizationService.purchaseInCash(
                    productId, platform, receiptData);
              }
            }

            // Show success message
            if (mounted) {
              ToastService.showToast(
                context,
                backgroundColor: Theme.of(context).canvasColor,
                shadowColor: Colors.transparent,
                leading: const Icon(
                  Icons.check_circle,
                  color: Colors.greenAccent,
                ),
                message: 'Purchase successful!',
              );
            }
          } catch (e) {
            print('Error processing purchase: $e');
            if (mounted) {
              ToastService.showToast(
                context,
                backgroundColor: Theme.of(context).canvasColor,
                shadowColor: Colors.transparent,
                leading: const Icon(
                  Icons.error,
                  color: Colors.redAccent,
                ),
                message: 'Error processing purchase: ${e.toString()}',
              );
            }
          }
        }
      } else if (paywallResult == PaywallResult.cancelled) {
        print("User closed the paywall without making a purchase.");
      } else if (paywallResult == PaywallResult.error) {
        print("An error occurred while presenting the paywall.");
        if (mounted) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Unable to load subscription options. Please try again.',
          );
        }
      }
    } catch (e) {
      print('Error presenting paywall: $e');

      // Check for specific error types
      String errorMessage =
          'Unable to open subscription page. Please try again later.';

      if (e.toString().contains('PAYWALLS_MISSING_WRONG_ACTIVITY') ||
          e.toString().contains('FlutterFragmentActivity')) {
        errorMessage =
            'App configuration error. Please update and restart the app.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      if (mounted) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons.error,
            color: Colors.redAccent,
          ),
          message: errorMessage,
        );
      }
    }
  }

  Future<String?> _showAccountActionDialog(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        'Manage Account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose one option below. For your security, you\'ll be asked to log in again before continuing.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deactivate account',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your profile and posts become hidden until your next login, when your account is restored automatically.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '• Login remains available.\n• On your next successful login, your account is reactivated automatically.\n• Your content is not permanently removed.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop('deactivate'),
                                  child: const Text('Deactivate account'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete account',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This starts a permanent deletion request with a 30-day waiting period.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '• Your account enters deletion pending status.\n• After 30 days, data can be permanently purged.\n• This action may not be reversible after purge.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop('delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Request account deletion'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, String>?> _showReauthDialog(BuildContext context) async {
    String email = FirebaseAuth.instance.currentUser?.email ?? '';
    String password = '';
    String? errorText;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).canvasColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confirm your identity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        initialValue: email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        onChanged: (value) => email = value.trim(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                        onChanged: (value) => password = value,
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(color: Colors.redAccent),
                        )
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(null),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              child: const Text('Continue'),
                              onPressed: () {
                                if (email.isEmpty || password.isEmpty) {
                                  setStateDialog(() {
                                    errorText =
                                        'Email and password are required.';
                                  });
                                  return;
                                }

                                Navigator.of(context).pop({
                                  'email': email,
                                  'password': password,
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return result;
  }

  Future<bool> _reauthenticateUser(String email, String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    return true;
  }

  Future<void> _handleAccountLifecycleAction(BuildContext context) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.error, color: Colors.redAccent),
        message: 'No user is signed in',
      );
      return;
    }

    final action = await _showAccountActionDialog(context);
    if (action == null) {
      return;
    }

    final credentials = await _showReauthDialog(context);
    if (credentials == null) {
      return;
    }

    try {
      await _reauthenticateUser(
        credentials['email']!,
        credentials['password']!,
      );
    } on FirebaseAuthException catch (e) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.error, color: Colors.redAccent),
        message: e.message ?? 'Re-authentication failed.',
      );
      return;
    } catch (e) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(Icons.error, color: Colors.redAccent),
        message: 'Re-authentication failed: $e',
      );
      return;
    }

    final uid = currentUser.uid;
    final result = action == 'deactivate'
      ? await _accountLifecycleService.deactivateAccount(uid)
      : await _accountLifecycleService.requestAccountDeletion(uid);

    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).canvasColor,
      shadowColor: Colors.transparent,
      leading: Icon(
        result.success ? Icons.check_circle : Icons.error,
        color: result.success ? Colors.greenAccent : Colors.redAccent,
      ),
      message: result.message,
    );

    if (!result.success) {
      return;
    }

    try {
      await Purchases.logOut();
    } catch (_) {}

    await AuthService().signOut();
    if (mounted) {
      context.go(Routes.onboarding);
    }
  }

  /// Show reward ad for Free InCash
  Future<void> _showRewardAd(BuildContext context) async {
    try {
      // Check if user can watch reward ad
      if (!await _rewardAdService.canWatchRewardAd()) {
        final remaining = await _rewardAdService.getRemainingRewardAds();
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          message: remaining > 0
              ? 'You have $remaining reward ads remaining today.'
              : 'Daily limit reached. Come back tomorrow for more free InCash!',
        );
        return;
      }

      // Initialize reward ad service if not already done
      if (!_rewardAdService.isRewardAdReady) {
        ToastService.showToast(
          context,
          backgroundColor: Theme.of(context).canvasColor,
          shadowColor: Colors.transparent,
          leading: const Icon(
            Icons.info,
            color: Colors.blue,
          ),
          message: 'Loading reward ad...',
        );
        await _rewardAdService.initialize();

        // Give a small delay to ensure ad is loaded
        await Future.delayed(const Duration(seconds: 2));
      }

      // Show reward ad
      await _rewardAdService.showRewardAd(
        context,
        onRewardEarned: () {
          // Success callback
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            message:
                'Congratulations! You earned ${RewardAdService.rewardAmountPerAd} InCash!',
          );

          // Update remaining ads count
          _loadRemainingAds();
        },
        onError: (String error) {
          // Error callback
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: error,
          );
        },
      );
    } catch (e) {
      print('Error showing reward ad: $e');
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          Icons.error,
          color: Colors.redAccent,
        ),
        message: 'Failed to show reward ad. Please try again.',
      );
    }
  }

  List<String> category = ["Personal", "Others"];

  List<String> personalTitleList = ["Interests", "Subscription", "Free InCash"];
  List<String> get personalSubtitleList => [
        "Select what you'd like to see in your feed",
        "Manage your InCash subscription",
        _freeInCashSubtitle
      ];
  List<VoidCallback> personalOnPressedList(BuildContext context) {
    return [
      () {
        try {
          context.push(Routes.contentSelection);
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to content selection: $e',
          );
        }
      },
      () {
        try {
          // context.push(Routes.subscription);
          presentPaywall();
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to subscription: $e',
          );
        }
      },
      () {
        // Handle Free InCash reward ad
        _showRewardAd(context);
      },
    ];
  }

  List<String> otherTitleList = [
    "Push Notifications",
    "Referral Program",
    "Contact Us",
    // "Unity Game Test",
    "Privacy Policy",
    "Terms & Conditions",
    "Manage Account",
    "LogOut"
  ];
  List<String> otherSubtitleList = [
    "Manage your notification preferences",
    "Invite friends and earn rewards",
    "Get help or ask us any questions",
    // "Test Unity web game integration",
    "Learn how we protect your personal information",
    "Understand the rules of using our services",
    "Deactivate account or request permanent deletion",
    "",
  ];
  List<VoidCallback> otherOnPressedList(BuildContext context) {
    return [
      () {
        try {
          context.push(Routes.notificationSettings);
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to user profile: $e',
          );
        }
      },
      () {
        try {
          context.push(Routes.referral);
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to referral: $e',
          );
        }
      },
      () {
        try {
          _launchInBrowser("mailto:contact@inzone.ai");
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error launching browser: $e',
          );
        }
      },
      // () {
      //   try {
      //     context.push(Routes.unityWebGame);
      //   } catch (e) {
      //     ToastService.showToast(
      //       context,
      //       backgroundColor: Theme.of(context).canvasColor,
      //       leading: const Icon(
      //         Icons.error,
      //         color: Colors.redAccent,
      //       ),
      //       message: 'Error navigating to Unity game: $e',
      //     );
      //   }
      // },
      () {
        try {
          context.push(Routes.privacyPolicy);
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to privacy policy: $e',
          );
        }
      },
      () {
        try {
          context.push(Routes.termsConditions);
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error navigating to terms & conditions: $e',
          );
        }
      },
      () {
        _handleAccountLifecycleAction(context);
      },
      () {
        try {
          Purchases.logOut();
          AuthService().signOut().then((_) {
            GoRouter.of(context).go(Routes.onboarding);
            ToastService.showToast(
              context,
              backgroundColor: Theme.of(context).canvasColor,
              shadowColor: Colors.transparent,
              leading: const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
              ),
              message: 'Logged out successfully',
            );
          });
        } catch (e) {
          ToastService.showToast(
            context,
            backgroundColor: Theme.of(context).canvasColor,
            shadowColor: Colors.transparent,
            leading: const Icon(
              Icons.error,
              color: Colors.redAccent,
            ),
            message: 'Error signing out: $e',
          );
        }
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      child: Scaffold(
        backgroundColor: Theme.of(context).canvasColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomAppBar(
              isHome: true,
              isSettings: true,
              isImage: false,
              title: "Settings",
              userPoints: "100",
              onSearchTap: () {},
              onProfileTap: () {},
              onPointsTap: () {},
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        category[0],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(personalTitleList.length, (index) {
                      return Column(
                        children: [
                          SettingsTile(
                            title: personalTitleList[index],
                            subtitle: personalSubtitleList[index],
                            onPressed: personalOnPressedList(context)[index],
                          ),
                          if (index != personalTitleList.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Divider(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                                thickness: 1,
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        category[1],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(otherTitleList.length, (index) {
                      return Column(
                        children: [
                          SettingsTile(
                            title: otherTitleList[index],
                            subtitle: otherSubtitleList[index],
                            onPressed: otherOnPressedList(context)[index],
                            isLogout: index == otherTitleList.length - 1,
                          ),
                          if (index != otherTitleList.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Divider(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                                thickness: 1,
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Container(
              //   width: MediaQuery.of(context).size.width - 20,
              //   decoration: BoxDecoration(
              //       color: Colors.white, borderRadius: BorderRadius.circular(15)),
              //   child: Column(children: [
              //     // SettingsTile(
              //     //     title: "InZone Schedule",
              //     //     imagePath: "icons/settings/content_scheduling.svg",
              //     //     onPressed: () {
              //     //       // Navigator.of(context)
              //     //       //     .push(MaterialPageRoute(builder: (context) {
              //     //       //   return const InZoneSchedule();
              //     //       // }));
              //     //     }),

              //     SettingsTile(
              //         title: "Content Selection",
              //         // imagePath: "icons/settings/content_selection.svg",
              //         onPressed: () {
              //           Navigator.of(context)
              //               .push(MaterialPageRoute(builder: (context) {
              //             return const ContentSelectionSettingsScreen();
              //           }));
              //         }),
              //   ]),
              // ),

              // Container(
              //   width: MediaQuery.of(context).size.width - 20,
              //   decoration: BoxDecoration(
              //       color: Colors.white, borderRadius: BorderRadius.circular(30)),
              //   child: Column(children: [
              //     SettingsTile(
              //         title: "Privacy Policy",
              //         // imagePath: "icons/settings/privacy_policy.svg",
              //         onPressed: () {
              //           _launchInBrowser("https://www.inzone.ai/privacypolicy");
              //         }),
              //     SettingsTile(
              //         title: "Terms & Conditions",
              //         // imagePath: "icons/settings/terms_and_conditions.svg",
              //         onPressed: () {
              //           _launchInBrowser("https://www.inzone.ai/terms-condition");
              //         }),
              //     SettingsTile(
              //       title: "Delete Account",
              //       // imagePath: "icons/settings/delete_account.svg",
              //       onPressed: () {
              //         showDialog(
              //           context: context,
              //           builder: (BuildContext context) {
              //             return AlertDialog(
              //               title: const Text('Delete Account'),
              //               content: const Text(
              //                   'Are you sure you want to delete your account? This cannot be undone.'),
              //               actions: <Widget>[
              //                 TextButton(
              //                   child: const Text('Cancel'),
              //                   onPressed: () {
              //                     Navigator.of(context).pop();
              //                   },
              //                 ),
              //                 TextButton(
              //                   child: const Text('Delete'),
              //                   onPressed: () {
              //                     // Close the dialog, then call the delete account method
              //                     Navigator.of(context).pop();
              //                     _deleteAccount(context);
              //                   },
              //                 ),
              //               ],
              //             );
              //           },
              //         );
              //       },
              //     ),
              //     SettingsTile(
              //         title: "Logout",
              //         // imagePath: "icons/settings/logout.svg",
              //         onPressed: () {
              //           FirebaseAuth.instance.signOut().then((value) {
              //             Navigator.pushReplacement(
              //                 context,
              //                 MaterialPageRoute(
              //                     builder: (context) =>
              //                         const IntroductionScreen()));
              //           });
              //         }),
              //   ]),
              // ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
