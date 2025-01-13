import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdService {
  InterstitialAd? _interstitialAd;

  void loadAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-4461306523468443/7243138184', // 🔹 본인의 전면 광고 단위 ID 입력
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

  void showAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null; // 광고가 끝나면 다시 로드해야 함
      loadAd();
    } else {
      print('전면 광고가 아직 로드되지 않음');
    }
  }
}
