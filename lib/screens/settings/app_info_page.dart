import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppInfoPage extends StatefulWidget {
  @override
  _AppInfoPageState createState() => _AppInfoPageState();
}

class _AppInfoPageState extends State<AppInfoPage> {
  String version = 'Unknown';
  String buildNumber = 'Unknown';

  @override
  void initState() {
    super.initState();
    _getAppInfo();
  }

  Future<void> _getAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      version = packageInfo.version; // 앱 버전
      buildNumber = packageInfo.buildNumber; // 빌드 번호
    });
  }

  Future<void> _launchGooglePlayReview() async {
    final String packageName = 'com.seuunng.foodforlater'; // 패키지 이름
    final Uri googlePlayUri = Uri.parse("market://details?id=$packageName");
    final Uri fallbackUri = Uri.parse(
        "https://play.google.com/store/apps/details?id=$packageName");

    try {
      // Google Play 스토어 앱으로 열기
      if (!await launchUrl(googlePlayUri, mode: LaunchMode.externalApplication)) {
        // 실패 시 웹 브라우저로 열기
        if (!await launchUrl(fallbackUri, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $fallbackUri');
        }
      }
    } catch (e) {
      print("구글 플레이 스토어 열기 실패: $e");
    }
  }

  Future<void> shareToKakaoTalk(String title, String description, String imageUrl, String webUrl) async {
    bool isKakaoTalkSharingAvailable =
    await ShareClient.instance.isKakaoTalkSharingAvailable();

    if (isKakaoTalkSharingAvailable) {
      try {
        // 메시지 템플릿 작성
        Uri uri = await ShareClient.instance.shareDefault(
          template: FeedTemplate(
            content: Content(
              title: title, // 제목
              description: description, // 설명
              imageUrl: Uri.parse(imageUrl), // 이미지 URL
              link: Link(
                webUrl: Uri.parse(webUrl), // 웹 링크
                mobileWebUrl: Uri.parse(webUrl), // 모바일 링크
              ),
            ),
            buttons: [
              Button(
                title: '다운로드',
                link: Link(
                  webUrl: Uri.parse(webUrl), // 웹 링크
                  mobileWebUrl: Uri.parse(webUrl), // 모바일 링크
                ),
              ),
            ],
          ),
        );

        // 카카오톡 실행
        await ShareClient.instance.launchKakaoTalk(uri);
        print("카카오톡 공유 성공");
      } catch (error) {
        print("카카오톡 공유 실패: $error");
      }
    } else {
      print('카카오톡이 설치되어 있지 않습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("어플 소개"),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // 세로 정렬
                  crossAxisAlignment: CrossAxisAlignment.center, // 가로 정렬
                  children: [
                    SizedBox(height: 30,),
                    // 파비콘 이미지
                    Image.asset(
                      'assets/favicon.png', // 파비콘 경로
                      width: 100,
                      height: 100,
                    ),
                    SizedBox(height: 16),
                    // 제목
                    Text(
                      "이따 뭐먹지",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface
                      ),
                    ),
                    SizedBox(height: 8),
                    // 버전 정보
                    Text(
                      "v $version",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 30,),
                    // 회사 정보
                    _buildCompanyInfo(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(context),
    );
  }

  // 회사 정보 위젯
  Widget _buildCompanyInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "개발사/서비스제공사: 승희네",
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            "사업자등록번호: 687-49-00897",
            style: TextStyle(fontSize: 16,
                color: theme.colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            "통신판매업신고: 2025-경기양주-0165",
            style: TextStyle(fontSize: 16,
                color: theme.colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            "개발자: seuunng",
            style: TextStyle(fontSize: 16,
                color: theme.colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          Text(
            "email: mnb2856@gmail.com",
            style: TextStyle(fontSize: 16,
                color: theme.colorScheme.onSurface),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _launchPrivacyPolicy,
                    child: Text('개인정보방침'),
                  ),
                  SizedBox(width: 8), // 버튼과 구분자 사이 여백 추가
                  Text(
                    '|',
                    style: TextStyle(fontSize: 16,
                        color: theme.colorScheme.onSurface),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: _launchTermsOfService,
                    child: Text('서비스약관'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 추천/응원하기 버튼 위젯
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 어플 추천하기 버튼
          Expanded(
            child: NavbarButton(
              onPressed: () async{
                // 친구 선택 페이지로 이동
                shareToKakaoTalk( '이따 뭐먹지? 고민될 때', // 제목
                '이 앱으로 당신의 냉장고를 계획하세요!', // 설명
                // 'https://seuunng.github.io/food_for_later_policy/marketing_01.png',
                  'https://seuunng.github.io/food_for_later_policy/marketing_02.png', // 이미지 URL
                'https://play.google.com/store/apps/details?id=com.seuunng.foodforlater', // 웹 URL
                    );
              },
              buttonTitle: '어플 추천하기',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: NavbarButton(
              onPressed: () {
                _launchGooglePlayReview();
                // _showSnackbar(context, "어플에 응원을 보냈습니다!");
              },
              // icon: Icon(Icons.favorite),
              buttonTitle: "어플 응원하기",
              // style: ElevatedButton.styleFrom(
              //   backgroundColor: Colors.redAccent,
              // ),
            ),
          ),
        ],
      ),
    );
  }

  // 스낵바 표시
  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
Future<void> _launchPrivacyPolicy() async {
  final Uri url = Uri.parse(
      'https://seuunng.github.io/food_for_later_policy/privacy-policy.html');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}
Future<void> _launchTermsOfService() async {
  final Uri url = Uri.parse(
      'https://seuunng.github.io/food_for_later_policy/terms-of-service.html');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}