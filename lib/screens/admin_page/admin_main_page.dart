import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/admin_app_settings_management.dart';
import 'package:food_for_later_new/screens/admin_page/admin_dashboard%20_usage_metrics.dart';
import 'package:food_for_later_new/screens/admin_page/admin_dashboard_trends.dart';
import 'package:food_for_later_new/screens/admin_page/admin_dashboard_user_status.dart';
import 'package:food_for_later_new/screens/admin_page/admin_feedback_management.dart';
import 'package:food_for_later_new/screens/admin_page/admin_password_change.dart';
import 'package:food_for_later_new/screens/fridge/fridge_main_page.dart';
import 'package:food_for_later_new/screens/home_screen.dart';

class AdminMainPage extends StatefulWidget {
  @override
  _AdminMainPageState createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;

  // 각 페이지를 리스트로 관리
  final List<Widget> _pages = [
    AdminDashboardUserStatus(),
    AdminDashboardUsageMetrics(),
    AdminDashboardTrends(),
    AdminAppSettingsManagement(),
    AdminFeedbackManagement(),
    AdminPasswordChange()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // 사이드바 닫기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('관리자 메인 페이지'),
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.grey,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '관리자 페이지',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('어플로 돌아가기'),
              onTap: () {
                Navigator.pop(context); // 사이드바 닫기
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => HomeScreen()), // HomeScreen으로 이동
                      (Route<dynamic> route) => false, // 현재의 모든 라우트를 제거
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('사용자 현황'),
              onTap: () {
                _onItemTapped(0);
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_chart_outlined),
              title: Text('실적'),
              onTap: () {
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: Icon(Icons.tag),
              title: Text('트렌드'),
              onTap: () {
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('어플 설정'),
              onTap: () {
                _onItemTapped(3);
              },
            ),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('의견 및 신고'),
              onTap: () {
                _onItemTapped(4);
              },
            ),
            ListTile(
              leading: Icon(Icons.key),
              title: Text('관리자 비밀번호 수정'),
              onTap: () {
                _onItemTapped(5);
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
