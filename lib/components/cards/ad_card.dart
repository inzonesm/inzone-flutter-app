import 'package:flutter/foundation.dart';
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

  String get _adUnitId {
    if (kReleaseMode) {
      // Production Ad Unit IDs
      return Platform.isAndroid
          ? 'ca-app-pub-4474122990542651/2820762502' //android
          : 'ca-app-pub-4474122990542651/6760007515'; // iOS
    } else {
      // Development Ad Unit IDs
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110' // Android Test
          : 'ca-app-pub-3940256099942544/3986624511'; // iOS Test
    }
  }

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
            height: Platform.isAndroid ? 150 : 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: Platform.isAndroid ? 16.0 : 0),
              child: AdWidget(ad: _nativeAd!),
            ),
          )
        : Container(
            height: Platform.isAndroid ? 150 : 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text("Advertisement"),
            ),
          );
  }
}
