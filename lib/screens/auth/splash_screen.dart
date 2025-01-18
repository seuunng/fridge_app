import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/auth/login_main_page.dart';
import 'package:food_for_later_new/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
    _navigateToHome(); // 홈 화면으로 이동
  }

  Future<void> _checkAuthState() async {
    // Firebase 인증 상태 확인
    User? user = FirebaseAuth.instance.currentUser;

    // 2초 정도 스플래시 화면 유지 후 라우팅
    await Future.delayed(Duration(seconds: 2));

    if (user != null) {
      // 사용자가 로그인된 경우
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      // 사용자가 로그인되지 않은 경우
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }
  Future<void> _navigateToHome() async {
    await Future.delayed(Duration(seconds: 3)); // 3초 대기
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()), // 홈 화면으로 전환
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색
      body: Center(
        child: Image.asset('assets/splash_logo.png', width: 150), // 로고
      ),
    );
  }
}
