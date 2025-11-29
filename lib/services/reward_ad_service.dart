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
    dynamic context, {
    Function()? onRewardEarned,
    Function(String)? onError,
  }) async {
    onError?.call('Reward ads are not available on web.');
  }
}
