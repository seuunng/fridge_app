import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class BannerAdWidget extends StatefulWidget {
  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  late BannerAd _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // 웹 플랫폼에서는 광고를 로드하지 않음
    if (!kIsWeb) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // adUnitId: 'ca-app-pub-3940256099942544/6300978111', // 🔹 테스트광고
      adUnitId: 'ca-app-pub-4461306523468443/8556219854', // 🔹 본인의 배너 광고 단위 ID 입력
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('배너 광고 로드 실패: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox.shrink(); // 웹에서는 빈 공간 반환
    }

    return _isAdLoaded
        ? Container(
      alignment: Alignment.center,
      width: _bannerAd.size.width.toDouble(),
      height: _bannerAd.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd),
    )
        : SizedBox.shrink();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _bannerAd.dispose();
    }
    super.dispose();
  }
}
