import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardAdService {
  static final RewardAdService _instance = RewardAdService._internal();
  factory RewardAdService() => _instance;
  RewardAdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  static const int maxDailyRewardAds = 5;
  static const int rewardAmountPerAd = 10;
  static const String dailyAdCountKey = 'daily_reward_ad_count';
  static const String lastRewardDateKey = 'last_reward_date';

  String get _rewardAdUnitId {
    if (kReleaseMode) {
      return Platform.isAndroid
          ? 'ca-app-pub-4474122990542651/6949210208'
          : 'ca-app-pub-4474122990542651/7222071742';
    } else {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
  }

  Future<bool> canWatchRewardAd() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastRewardDate = prefs.getString(lastRewardDateKey) ?? '';

    if (lastRewardDate != today) {
      await prefs.setInt(dailyAdCountKey, 0);
      await prefs.setString(lastRewardDateKey, today);
      return true;
    }

    final dailyCount = prefs.getInt(dailyAdCountKey) ?? 0;
    return dailyCount < maxDailyRewardAds;
  }

  Future<int> getRemainingRewardAds() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final lastRewardDate = prefs.getString(lastRewardDateKey) ?? '';

    if (lastRewardDate != today) {
      await prefs.setInt(dailyAdCountKey, 0);
      await prefs.setString(lastRewardDateKey, today);
      return maxDailyRewardAds;
    }

    final dailyCount = prefs.getInt(dailyAdCountKey) ?? 0;
    return maxDailyRewardAds - dailyCount;
  }

  Future<void> loadRewardAd() async {
    await RewardedAd.load(
      adUnitId: _rewardAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _setRewardAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isRewardedAdReady = false;
          debugPrint('Reward ad failed to load: $error');
        },
      ),
    );
  }

  void _setRewardAdCallbacks() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {},
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          loadRewardAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
        },
      );
    }
  }

  Future<void> showRewardAd(
    BuildContext context, {
    required Function() onRewardEarned,
    required Function(String) onError,
  }) async {
    if (!await canWatchRewardAd()) {
      onError(
          'Daily limit reached. You can watch $maxDailyRewardAds reward ads per day.');
      return;
    }

    if (!_isRewardedAdReady || _rewardedAd == null) {
      onError('Reward ad is not ready. Please try again in a few seconds.');
      await loadRewardAd();
      return;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem rewardItem) async {
          await _processRewardEarned(onRewardEarned, onError);
        },
      );
    } catch (e) {
      debugPrint('Error showing reward ad: $e');
      onError('Failed to show reward ad. Please try again.');
    }
  }

  Future<void> _processRewardEarned(
    Function() onRewardEarned,
    Function(String) onError,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dailyCount = prefs.getInt(dailyAdCountKey) ?? 0;
      await prefs.setInt(dailyAdCountKey, dailyCount + 1);

      await _addInCashToUser(rewardAmountPerAd);
      onRewardEarned();
    } catch (e) {
      debugPrint('Error processing reward: $e');
      onError('Failed to process reward. Please contact support.');
    }
  }

  Future<void> _addInCashToUser(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await FirebaseFirestore.instance
          .collection('humanUsers')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(amount),
      });
    } catch (e) {
      debugPrint('Error adding InCash to user: $e');
      throw Exception('Failed to add InCash to balance');
    }
  }

  Future<void> initialize() async {
    await loadRewardAd();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
  }

  bool get isRewardAdReady => _isRewardedAdReady;
}
