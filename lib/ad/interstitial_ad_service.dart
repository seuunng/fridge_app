import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  InterstitialAd? _interstitialAd;
  static const String _adCounterKey = 'ad_counter';
  static const int _adThreshold = 7; // 세 번 중 한 번 광고 표시

  String getBannerAdUnitId() {
    if (!kIsWeb && Platform.isAndroid) {
      return 'ca-app-pub-4461306523468443/7243138184'; // 🔹 Android 광고 ID
      // } else if (Platform.isIOS) {
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-4461306523468443/1882734364'; // 🔹 iOS 광고 ID (실제 ID로 변경)
    }
    return ''; // 웹 또는 지원하지 않는 플랫폼
  }

  void loadInterstitialAd() {
    String adUnitId = getBannerAdUnitId();

    InterstitialAd.load(
      adUnitId:adUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('전면 광고 로드 실패: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> showInterstitialAd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_adCounterKey) ?? 0;

    if (currentCount >= _adThreshold) {
      if (_interstitialAd != null) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            print('Ad dismissed.');
            ad.dispose(); // 광고를 닫으면 메모리에서 해제
            loadInterstitialAd(); // 새 광고 로드
          },
          onAdFailedToShowFullScreenContent:
              (InterstitialAd ad, AdError error) {
            print('Ad failed to show: $error');
            ad.dispose();
          },
        );

        _interstitialAd!.show();
        _interstitialAd = null; // 광고가 표시되면 null로 설정하여 중복 방지
      } else {
        print('Interstitial Ad is not ready.');
      }
    } else {
      // 카운터 증가
      prefs.setInt(_adCounterKey, currentCount + 1);
      print("Ad counter incremented to ${currentCount + 1}");
    }
  }
}
