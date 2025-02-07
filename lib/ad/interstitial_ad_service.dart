import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterstitialAdService {
  InterstitialAd? _interstitialAd;
  static const String _adCounterKey = 'ad_counter';
  static const int _adThreshold = 7; // 세 번 중 한 번 광고 표시

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId:
          'ca-app-pub-4461306523468443/7243138184', // 🔹 본인의 전면 광고 단위 ID 입력
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
