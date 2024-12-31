import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_for_later_new/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); // 홈 화면으로 이동
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