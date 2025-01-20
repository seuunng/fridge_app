import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class UserDetailsPage extends StatefulWidget {
  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  String? _selectedGender;
  int? _birthYear; // 기본값 설정
  bool _agreedToPrivacyPolicy = false; // 개인정보 제공 동의 체크박스 상태
  TextEditingController _nicknameController = TextEditingController();

  void _saveUserDetails() async {
    if (!_agreedToPrivacyPolicy &&
        !((_selectedGender == '선택하지 않음' || _selectedGender == null) &&
            _birthYear == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('개인정보 제공에 동의해야 저장할 수 있습니다.')),
      );
      return;
    }
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid;
      final gender=_selectedGender=='여성'? 'F': _selectedGender=='남성'? 'M':'S';
      if (_selectedGender != null) {
        try {
          // Firestore에 사용자 정보 저장
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'nickname': _nicknameController.text.trim(),
            'gender': gender,
            'birthYear': _birthYear ?? '선택하지 않음',
          }, SetOptions(merge: true));

          // 다른 페이지로 이동 (예: 홈 화면)
          Navigator.pushReplacementNamed(context, '/home');
        } catch (e) {
          print('Error saving user details: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 중 오류가 발생했습니다. 다시 시도해주세요.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('모든 필드를 입력해주세요.')),
        );
      }
    }
  }
  void _showYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(
              initialItem: _birthYear != null
                  ? DateTime.now().year - _birthYear!
                  : 0, // null일 경우 첫 번째 항목("선택하지 않음")으로 설정
            ),
            itemExtent: 40.0, // 각 항목의 높이
            onSelectedItemChanged: (int index) {
              setState(() {
                _birthYear = index == 0
                    ? null
                    : DateTime.now().year - (index - 1); // 선택하지 않음 처리
              });
            },
            children: List<Widget>.generate(
              121, // 1900년부터 현재 연도까지
                  (int index) {
                return Center(
                  child: Text(
                    '${DateTime.now().year - index}',
                    style: TextStyle(fontSize: 20),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('회원 정보 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('닉네임 입력',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            SizedBox(height: 10),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                hintText: '닉네임을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text('성별 선택',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('남성'),
                    value: '남성',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('여성'),
                    value: '여성',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text('선택하지 않음'),
                    value: '선택하지 않음',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text('출생연도',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            SizedBox(height: 10,),
            GestureDetector(
              onTap: () => _showYearPicker(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary, width: 1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _birthYear == null ? '선택하지 않음' : '$_birthYear',
                      style: TextStyle(fontSize: 18),
                    ),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _agreedToPrivacyPolicy,
                  onChanged: (bool? value) {
                    setState(() {
                      _agreedToPrivacyPolicy = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: Text(
                    '개인정보 제공에 동의합니다.(성별/출생연도)',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
        bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
    mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
    children: [
    Container(
    color: Colors.transparent,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: SizedBox(
    width: double.infinity,
      child: NavbarButton(
    onPressed: _saveUserDetails,
    buttonTitle: '저장하기',
    ),
    ),
        ),
      ]
        )
    );
  }
}
