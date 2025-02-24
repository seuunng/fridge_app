import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/notice.dart' as ModelNotice;
import 'package:food_for_later_new/screens/settings/notice_data/all_notices.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 최신순으로 정렬된 리스트
    final sortedNotices = List<ModelNotice.Notice>.from(notices)
      ..sort((a, b) => b.date.compareTo(a.date)); // 날짜 기준 내림차순 정렬
    return Scaffold(
      appBar: AppBar(
        title: Text("공지사항"),
      ),
      body: ListView.builder(
        itemCount: notices.length,
        itemBuilder: (context, index) {
          final notice = sortedNotices[index];
          return ListTile(
            title: Text(
              "${notice.date.year}-${notice.date.month.toString().padLeft(
                  2, '0')}-${notice.date.day.toString().padLeft(2, '0')}",
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),
            ),
            subtitle: Text(notice.title,
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),
            ),
            onTap: () {
              // 공지사항 상세보기 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoticeDetailPage(notice: notice),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildActionButtons(context),
    );
  }
}

class NoticeDetailPage extends StatelessWidget {
  final ModelNotice.Notice notice;

  NoticeDetailPage({required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    print(MediaQuery.of(context).size);

    return Scaffold(
      appBar: AppBar(
        title: Text("공지사항"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            Text(
              notice.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            // 작성일
            Text(
              "작성일: ${notice.date.year}-${notice.date.month.toString().padLeft(2, '0')}-${notice.date.day.toString().padLeft(2, '0')}",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            // 내용 부분을 스크롤 가능하도록 설정
            Flexible(
              child: Markdown(
                data: notice.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                // 'https://seuunng.github.io/food_for_later_policy/marketing_01.png?v=2',
                'https://seuunng.github.io/food_for_later_policy/marketing_02.png?v=2', // 이미지 URL
                'https://play.google.com/store/apps/details?id=com.seuunng.foodforlater', // 웹 URL
              );
            },
            // icon: Icon(Icons.thumb_up),
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
