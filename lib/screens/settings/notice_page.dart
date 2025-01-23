import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/notice.dart' as ModelNotice;
import 'package:food_for_later_new/screens/settings/notice_data/all_notices.dart';
import 'package:food_for_later_new/screens/settings/notice_page.dart' as PageNotice;
import 'package:food_for_later_new/screens/settings/notice_data/data_first.dart';

class NoticePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            title: Text(notice.title),
            subtitle: Text(
              "${notice.date.year}-${notice.date.month.toString().padLeft(
                  2, '0')}-${notice.date.day.toString().padLeft(2, '0')}",
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
            onPressed: () {
              // 어플 추천하기 로직
              _showSnackbar(context, "어플을 추천했습니다!");
            },
            // icon: Icon(Icons.thumb_up),
            buttonTitle: '어플 추천하기',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: NavbarButton(
            onPressed: () {
              // 어플 응원하기 로직
              _showSnackbar(context, "어플에 응원을 보냈습니다!");
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
