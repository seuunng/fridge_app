import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class UserDetailsPage extends StatefulWidget {
  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _selectedGender;
  int? _birthYear; // 기본값 설정
  String userRole = '';
  bool _isPremiumUser = false;
  String _avatar = 'assets/avatar/avatar-01.png';
  bool _agreedToPrivacyPolicy = false; // 개인정보 제공 동의 체크박스 상태
  TextEditingController _nicknameController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadUserRole();
    // _setRandomNickname();
  }
  void _loadUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? 'user'; // 기본값은 'user'
          // 🔹 paid_user 또는 admin이면 유료 사용자로 설정
          _isPremiumUser = (userRole == 'paid_user' || userRole == 'admin');
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }
// 사용자 정보를 Firestore에서 불러옴
  void _loadUserDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        var existingNickname = data['nickname'] ?? ''; // 기존 별명 불러오기
        var existingAvatar = data['avatar'] ?? _getRandomAvatar();  // 저장된 아바타 불러오기
        final existingAgreement = data['privacyAgreed'] ?? false; // 동의 여부 불러오기
        var existingBirthYear = (data['birthYear'] is int)
            ? data['birthYear']
            : int.tryParse(data['birthYear']?.toString() ?? '1999') ?? 1999; // 기본값 1999
        var existingGender = data['gender'] ?? '';

        if (data['avatar'] == null) {
          existingAvatar = _getRandomAvatar();
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'avatar': existingAvatar
          }, SetOptions(merge: true));
        }
        if (existingNickname.isEmpty || existingNickname == "닉네임 없음") {
          existingNickname = _generateRandomNickname();
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'nickname': existingNickname
          }, SetOptions(merge: true));
        }
        if (data['birthYear'] == null || existingBirthYear == 0) {
          existingBirthYear = 1999;
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'birthYear': 1999
          }, SetOptions(merge: true));
        }
        if (data['gender'] == null || existingGender == "알 수 없음") {
          existingGender = 'F';
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'gender': 'F'
          }, SetOptions(merge: true));
        }
        setState(() {
            _nicknameController.text = existingNickname; // 기존 별명 사용
            _avatar = existingAvatar;
            _agreedToPrivacyPolicy = existingAgreement;
            _selectedGender = _genderFromFirestore(existingGender);
            _birthYear = existingBirthYear;
        });

      } else {
        // 사용자 정보가 없으면 랜덤 별명 추천
        setState(() {
          _nicknameController.text = _generateRandomNickname();
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
    }
  }
  String _getRandomAvatar() {
    final random = Random();
    int avatarNumber = random.nextInt(25) + 1; // 1~25 범위
    return 'assets/avatar/avatar-${avatarNumber.toString().padLeft(2, '0')}.png';
  }
  String? _genderFromFirestore(String? genderCode) {
    if (genderCode == 'M') return '남성';
    if (genderCode == 'F') return '여성';
    return '선택하지 않음';
  }
  // 두그룹 합쳐서 별명 만들기
  String _generateRandomNickname() {
    final random = Random();
    final randomAdjective = adjectives[random.nextInt(adjectives.length)];
    final randomNoun = nouns[random.nextInt(nouns.length)];
    return '$randomAdjective$randomNoun';
  }

  //랜덤으로 하나골라서 추천하기
  // void _setRandomNickname() {
  //   final randomNickname = _generateRandomNickname();
  //   setState(() {
  //     _nicknameController.text = randomNickname;
  //   });
  // }

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
      final gender = _selectedGender == '여성'
          ? 'F'
          : _selectedGender == '남성'
              ? 'M'
              : 'S';
      if (_selectedGender != null) {
        try {
          // Firestore에 사용자 정보 저장
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'nickname': _nicknameController.text.trim(),
            'gender': gender,
            'birthYear': _birthYear ?? '0',
            'avatar': _avatar,
            'privacyAgreed': _agreedToPrivacyPolicy,
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
                    : DateTime.now().year - (index); // 선택하지 않음 처리
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
        body: SingleChildScrollView(
          child: Padding(
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
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _showAvatarChangeDialog(); // 아바타 변경 다이얼로그 호출
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: _avatar.startsWith('http')
                            ? NetworkImage(_avatar)
                            : AssetImage(_avatar) as ImageProvider,
                        onBackgroundImageError: (_, __) {
                          // URL이 잘못된 경우 기본 아바타 표시
                          setState(() {
                            _avatar = 'assets/avatar/avatar-01.png'; // 기본 아바타로 설정
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    decoration: InputDecoration(
                      hintText: '닉네임을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                    ),
                  ),
                ),
                  ],
                ),
                SizedBox(height: 16),
                Text('성별 선택',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      flex: 1,
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true, // 타일 크기 최소화
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                        title: Text('남성',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                          ),),
                        value: '남성',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true, // 타일 크기 최소화
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                        title: Text('여성',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                          ),),
                        value: '여성',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        dense: true, // 타일 크기 최소화
                        visualDensity: VisualDensity(horizontal: -4, vertical: -4),
                        title: Text('선택하지 않음',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                          ),),
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
                SizedBox(
                  height: 10,
                ),
                GestureDetector(
                  onTap: () => _showYearPicker(context),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: theme.colorScheme.primary, width: 1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _birthYear == null ? '선택하지 않음' : '$_birthYear',
                          style: TextStyle(
                              color: theme.colorScheme.onSurface
                          ),
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
              if (userRole != 'admin' && userRole != 'paid_user')
                SafeArea(
                  bottom: false, // 하단 여백 제거
                  child: BannerAdWidget(),
                ),
            ]));
  }
  Future<void> _showAvatarChangeDialog() async {
    final theme = Theme.of(context);
    List<String> avatarList = List.generate(
      25,
          (index) =>
      'assets/avatar/avatar-${(index + 1).toString().padLeft(2, '0')}.png',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('아바타 선택',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Container(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 한 줄에 5개의 아바타 표시
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: avatarList.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () async {
                    String selectedAvatar = avatarList[index];
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .set({'avatar': selectedAvatar},
                        SetOptions(merge: true));
                    setState(() {
                      _avatar = selectedAvatar;
                    });
                    Navigator.pop(context); // 다이얼로그 닫기
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage(avatarList[index]),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: Text('닫기'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }
}

final List<String> adjectives = [
  "행복한 ",
  "푸른 ",
  "밝은 ",
  "용감한 ",
  "멋진 ",
  "부드러운 ",
  "깨끗한 ",
  "귀여운 ",
  "따뜻한 ",
  "재미있는 ",
  "상냥한 ",
  "활기찬 ",
  "빛나는 ",
  "다정한 ",
  "깜찍한 ",
  "든든한 ",
  "우아한 ",
  "고요한 ",
  "아름다운 ",
  "목마른 ",
  "졸린 ",
  "신나는 ",
  "궁금한 ",
  "날고싶은 ",
  "쉬고싶은 ",
  "숨고싶은 ",
  "부끄러운 ",
  "똑똑한 ",
  "느긋한 ",
  "엉뚱한 ",
  "쫄깃쫄깃한 ",
  "느끼한 ",
  "화끈한 ",
  "반짝이는 ",
];

final List<String> nouns = [
  "마카롱",
  "바게트",
  "햄버거",
  "소다캔",
  "주전자",
  "바나나",
  "당근",
  "초코칩",
  "치즈볼",
  "구름빵",
  "솜사탕",
  "치타",
  "다람쥐",
  "오리너구리",
  "젤리곰",
  "피카츄",
  "루돌프",
  "까마귀",
  "코뿔소",
  "아이스크림",
  "붕어빵",
  "삐약이",
  "알약",
  "팝콘",
  "만두왕",
  "감자칩",
  "마요네즈",
  "호빵맨",
  "콩나물",
  "초코우유",
  "라면왕",
  "찜닭",
  "꿀떡",
  "비빔밥",
  "고구마",
  "떡볶이",
  "버블티",
  "감자튀김",
  "쥬스박스",
  "피자조각",
];
