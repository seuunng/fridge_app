import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class AppInfoPage extends StatelessWidget {
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
                      "버전: 1.0.0",
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
    return Column(
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
      ],
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
}
