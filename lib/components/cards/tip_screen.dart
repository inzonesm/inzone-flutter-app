import 'dart:io';

import 'package:colorful_safe_area/colorful_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:toasty_box/toast_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class TipScreen extends StatefulWidget {
  final Map<String, dynamic> recipient;

  const TipScreen({
    super.key,
    required this.recipient,
  });

  @override
  State<TipScreen> createState() => _TipScreenState();
}

class _TipScreenState extends State<TipScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;
  String _userBalance = '0';

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBalance() async {
    try {
      final response = await _monetizationService.getBalance();

      if (response['success'] == true) {
        final balance = response['data']['balance'];

        if (mounted) {
          setState(() {
            _userBalance = balance.toString();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('TipScreen: Error loading balance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void presentPaywall() async {
    final paywallResult = await RevenueCatUI.presentPaywall();

    print('Paywall result: $paywallResult ${paywallResult.name}');
    if (paywallResult == PaywallResult.purchased ||
        paywallResult == PaywallResult.restored) {
      // Retrieve the latest customer information
      final customerInfo = await Purchases.getCustomerInfo();
      final transactions =
          List<StoreTransaction>.from(customerInfo.nonSubscriptionTransactions);
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

          // P
          // rocess the purchase with our backend
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
        } catch (e) {
          print('Error processing purchase: $e');
        }
      }
    } else if (paywallResult == PaywallResult.cancelled) {
      print("User closed the paywall without making a purchase.");
    } else if (paywallResult == PaywallResult.error) {
      print("An error occurred while presenting the paywall.");
    }
  }

  void _navigateToPaymentScreen() {
    try {
      presentPaywall();
    } catch (e) {
      ToastService.showToast(
        context,
        backgroundColor: Theme.of(context).canvasColor,
        shadowColor: Colors.transparent,
        leading: const Icon(
          FeatherIcons.xCircle,
          color: Colors.redAccent,
        ),
        message: 'Error navigating to subscription: $e',
      );
    }
  }

  void _sendTip() async {
    // Validate input
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showErrorToast('Please enter an amount');
      return;
    }

    int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showErrorToast('Please enter a valid amount');
      return;
    }

    if (amount > int.parse(_userBalance)) {
      _showErrorToast('Insufficient coins');

      // Show dialog asking to navigate to payment page
      final shouldNavigate = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Insufficient Coins'),
              content: const Text(
                  'You don\'t have enough coins. Would you like to purchase more?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Purchase'),
                ),
              ],
            ),
          ) ??
          false;

      if (shouldNavigate) {
        _navigateToPaymentScreen();
      }

      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Tip'),
            content: Text(
                'Are you sure you want to send $amount coins to ${widget.recipient['name']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Send'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String recipientUsername = widget.recipient['username'] ?? '';

      if (recipientUsername.isEmpty) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorToast('Recipient username not found.');
        return;
      }

      String recipientHandle = recipientUsername;
      if (!recipientHandle.startsWith('@')) {
        recipientHandle = '@$recipientHandle';
      }

      // For debugging
      print('Sending tip to: $recipientHandle');

      // Send the tip
      final response = await _monetizationService.sendTip(
        recipientHandle,
        amount,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      if (response['success']) {
        // Show success message with updated balance
        final newBalance = response['data']['newBalance'];
        _showSuccessToast(
            '${amount.toString()} coins sent successfully! Your remaining balance: ${newBalance.toString()} coins');

        setState(() {
          _userBalance = newBalance.toString();
          _amountController.clear();
        });

        // Close the screen after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        _showErrorToast('Failed to send coins: ${response['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      _showErrorToast('Failed to send coins: ${e.toString()}');
    }
  }

  void _showErrorToast(String message) {
    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).canvasColor,
      shadowColor: Colors.transparent,
      leading: const Icon(
        FeatherIcons.xCircle,
        color: Colors.redAccent,
      ),
      message: message,
    );
  }

  void _showSuccessToast(String message) {
    ToastService.showToast(
      context,
      backgroundColor: Theme.of(context).canvasColor,
      shadowColor: Colors.transparent,
      leading: const Icon(
        FeatherIcons.checkCircle,
        color: Colors.greenAccent,
      ),
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColorfulSafeArea(
      color: Theme.of(context).canvasColor,
      bottomColor: Theme.of(context).canvasColor,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: Scaffold(
          backgroundColor: Theme.of(context).canvasColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).canvasColor,
            elevation: 0,
            title: const Text('Send Tip'),
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).cardColor,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 18,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              // Display coin balance
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Theme.of(context).cardColor,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.local_police,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _userBalance,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Recipient profile
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                backgroundImage:
                                    widget.recipient['profilePicture'] !=
                                                null &&
                                            widget.recipient['profilePicture']
                                                .isNotEmpty
                                        ? NetworkImage(
                                            widget.recipient['profilePicture'])
                                        : null,
                                child: widget.recipient['profilePicture'] ==
                                            null ||
                                        widget
                                            .recipient['profilePicture'].isEmpty
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.recipient['name'] ?? 'Unknown',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              '@${widget.recipient['username'] ?? 'unknown'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 48),

                        // Coin amount input
                        Column(
                          children: [
                            Text(
                              'Enter amount to tip',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 250,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 20),
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    child: const Icon(
                                      Icons.local_police,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 150,
                                    child: TextField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        fillColor: Colors.transparent,
                                        filled: true,
                                        hintText: '0',
                                        border: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 16,
                                        ),
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Predefined amount options in pill shapes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildAmountPill(2500),
                            const SizedBox(width: 12),
                            _buildAmountPill(5000),
                            const SizedBox(width: 12),
                            _buildAmountPill(10000),
                          ],
                        ),

                        const SizedBox(height: 48),

                        SizedBox(
                          width: 200,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _sendTip,
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                (states) =>
                                    Theme.of(context).colorScheme.primary,
                              ),
                              foregroundColor:
                                  WidgetStateProperty.all(Colors.white),
                              elevation: WidgetStateProperty.all(4),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              overlayColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              'Send',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Balance info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Your balance: $_userBalance coins',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _navigateToPaymentScreen,
                          child: Text(
                            'Need more coins?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAmountPill(int amount) {
    final bool isSelected = _amountController.text == amount.toString();
    final String formattedAmount = amount >= 1000
        ? '${amount ~/ 1000}${amount % 1000 == 0 ? 'K' : '.${(amount % 1000) ~/ 100}K'}'
        : amount.toString();

    return GestureDetector(
      onTap: () {
        setState(() {
          _amountController.text = amount.toString();
        });
        // Add haptic feedback for better user experience
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_police,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              formattedAmount,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
