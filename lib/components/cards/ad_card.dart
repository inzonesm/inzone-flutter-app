import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';

class AdCard extends StatefulWidget {
  const AdCard({super.key});

  @override
  _AdCardState createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2247696110' // Test ID
      : 'ca-app-pub-3940256099942544/3986624511'; // Test ID

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      factoryId: 'groupTileSmall',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          debugPrint('Native ad failed to load: $error');
        },
      ),
    );
    _nativeAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    return _nativeAdIsLoaded
        ? Container(
            height: 128,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: AdWidget(ad: _nativeAd!),
          )
        : Container(
            height: 128,
            margin: const EdgeInsets.symmetric(vertical: 4),
            // Optionally, show a placeholder while the ad is loading
            child: const Center(
              child: Text("Advertisement"),
            ),
          );
  }
}
