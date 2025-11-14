import 'package:flutter/foundation.dart';

class RewardAdService {
  static final RewardAdService _instance = RewardAdService._internal();
  factory RewardAdService() => _instance;
  RewardAdService._internal();

  // Static fields for UI references
  static const int maxDailyRewardAds = 5;
  static const int rewardAmountPerAd = 10;

  // No-op methods for web
  Future<void> initialize() async {}
  void dispose() {}
  bool get isRewardAdReady => false;

  String get _rewardAdUnitId => '';

  Future<bool> canWatchRewardAd() async => false;
  Future<int> getRemainingRewardAds() async => 0;

  Future<void> showRewardAd(
    dynamic context, {
    Function()? onRewardEarned,
    Function(String)? onError,
  }) async {
    onError?.call('Reward ads are not available on web.');
  }
}
