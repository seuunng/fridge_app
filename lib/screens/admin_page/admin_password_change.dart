import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class AdminPasswordChange extends StatefulWidget {
  @override
  _AdminPasswordChangeState createState() => _AdminPasswordChangeState();
}

class _AdminPasswordChangeState extends State<AdminPasswordChange> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // 비밀번호 확인 함수
  void _handleSubmit() {
    String currentPassword = _currentPasswordController.text;
    String newPassword = _newPasswordController.text;
    String confirmPassword = _confirmPasswordController.text;

    if (newPassword == currentPassword) {
      _showErrorDialog("새로운 비밀번호는 현재 비밀번호와 달라야 합니다.");
    } else if (newPassword != confirmPassword) {
      _showErrorDialog("새로운 비밀번호와 확인용 비밀번호가 일치하지 않습니다.");
    } else {
      _showSuccessDialog("비밀번호가 성공적으로 변경되었습니다.");
    }
  }
// 경고 메시지 다이얼로그 함수
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("오류"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("확인"),
          ),
        ],
      ),
    );
  }

  // 성공 메시지 다이얼로그 함수
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("성공"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearFields(); // 성공 후 필드 초기화
            },
            child: Text("확인"),
          ),
        ],
      ),
    );
  }

  // 입력 필드 초기화 함수
  void _clearFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('관리자 비밀번호 변경'),
      ),
      body: Center(
        // 수직과 수평 모두 중앙 정렬
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0), // 양쪽에 여백 추가
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 수직 중앙 배치
            children: [
              TextField(
                controller: _currentPasswordController,
                obscureText: true, // 비밀번호 입력시 텍스트를 숨김 처리
                decoration: InputDecoration(
                  hintText: '현재 비밀번호를 입력하세요',
                  border: OutlineInputBorder(), // 테두리 추가
                ),
                onSubmitted: (value) {
                  _handleSubmit(); // 엔터키를 누르면 호출되는 함수
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                obscureText: true, // 비밀번호 입력시 텍스트를 숨김 처리
                decoration: InputDecoration(
                  hintText: '새로운 비밀번호를 입력하세요',
                  border: OutlineInputBorder(), // 테두리 추가
                ),
                onSubmitted: (value) {
                  _handleSubmit(); // 엔터키를 누르면 호출되는 함수
                },
              ),
              SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true, // 비밀번호 입력시 텍스트를 숨김 처리
                decoration: InputDecoration(
                  hintText: '확인용 비밀번호를 입력하세요',
                  border: OutlineInputBorder(), // 테두리 추가
                ),
                onSubmitted: (value) {
                  _handleSubmit(); // 엔터키를 누르면 호출되는 함수
                },
              ),
              SizedBox(height: 15),// 버튼 위에 30픽셀 간격 추가
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: NavbarButton(
            buttonTitle: '비밀번호 변경',
            onPressed: () {
            },
          ),
        ),
      ),
    );
  }
}
