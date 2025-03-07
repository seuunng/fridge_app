import 'dart:convert';
import 'dart:math';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/screens/auth/user_details_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

//ios 수정
// import 'package:food_for_later_new/screens/auth/naver_login_stub.dart'
// if (dart.library.io) 'package:flutter_naver_login/flutter_naver_login.dart'
// if (dart.library.js) 'naver_login_stub.dart';
// import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/services/firebase_service.dart';
import 'package:food_for_later_new/screens/auth/login_main_page.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AccountInformation extends StatefulWidget {
  @override
  _AccountInformationState createState() => _AccountInformationState();
}

class _AccountInformationState extends State<AccountInformation> {
  String _nickname = '방문자'; // 닉네임 기본값
  String _email = 'guest@foodforlater.com'; // 이메일 기본값
  final TextEditingController _passwordController = TextEditingController();
  firebase_auth.User? user = firebase_auth.FirebaseAuth.instance.currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String _avatar = 'assets/avatar/avatar-01.png';
  String userRole = '';
  final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadUserRole();
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
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  void _loadUserInfo() async {
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get(); // Firestore에서 사용자 문서 가져오기

      if (userDoc.exists) {
        setState(() {
          _email = userDoc.data()?['email'] ?? '이메일';
          _nickname = userDoc.data()?['nickname'] ?? '닉네임';
          _avatar = userDoc.data()?['avatar'] ?? 'assets/avatar/avatar-01.png';
        });
      } else {
        // Firestore에 사용자 데이터가 없을 경우 기본값 설정
        setState(() {
          _email = userDoc.data()?['email'] ?? '이메일';
          _nickname = userDoc.data()?['email']?.split('@')[0] ?? '닉네임';
          _avatar = userDoc.data()?['avatar'] ?? 'assets/avatar/avatar-01.png';
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    try {
      // 재인증 수행
      await _reauthenticateUser();

      // Firestore에서 사용자 문서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .delete();

      // Firebase Authentication 계정 삭제
      await user?.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('계정이 삭제되었습니다.')),
      );
      Navigator.pop(context); // 다이얼로그 닫기
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      print('계정 삭제 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호를 확인해주세요.')),
      );
    }
  }
  Future<void> _reauthenticateUser() async {
    try {
      if (user!.providerData[0].providerId == 'google.com') {
        // Google 인증 흐름
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw Exception('Google 인증이 취소되었습니다.');
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user?.reauthenticateWithCredential(credential);
      } else if (user!.providerData[0].providerId == 'password') {
        // 이메일/비밀번호 인증 흐름
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: user!.email ?? '',
          password: _passwordController.text.trim(),
        );
        await user?.reauthenticateWithCredential(credential);
      } else {
        throw Exception('지원하지 않는 인증 제공자입니다.');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        // 🔹 비밀번호가 틀렸을 때 메시지 처리
        throw Exception('비밀번호가 틀렸습니다.');
      } else {
        throw Exception('재인증 실패: ${e.message}');
      }
    }
  }
  Future<void> googleLogout() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      print('Google 로그아웃 실패: $error');
    }
  }

  Future<void> kakaoLogout() async {
    try {
      await UserApi.instance.logout();
      print("✅ 카카오 로그아웃 완료");
      await TokenManagerProvider.instance.manager.clear();
      print("✅ 카카오 토큰 삭제 완료");
      // ✅ 3️⃣ 카카오 계정 연결 해제 (완전한 로그아웃 보장)
      if (await TokenManagerProvider.instance.manager.getToken() != null) {
        await UserApi.instance.unlink();
        print("✅ 카카오 계정 연결 해제 완료");
      } else {
        print("⚠️ 카카오 토큰이 이미 삭제됨, unlink 실행 불필요");
      }
      // ✅ 4️⃣ Firebase 로그아웃 수행
      await firebase_auth.FirebaseAuth.instance.signOut();
      print("✅ Firebase 로그아웃 완료");
      // ✅ 3️⃣ 세션 정리 후 1초 대기 (세션 충돌 방지)
      await Future.delayed(Duration(seconds: 1));
    } catch (error) {
      print('Kakao 로그아웃 실패: $error');
    }
  }
  Future<void> appleLogout() async {
    try {
      // 1️⃣ Firebase에서 로그아웃
      await firebase_auth.FirebaseAuth.instance.signOut();

    } catch (error) {
      print("🚨 Apple 로그아웃 실패: $error");
      if (error.toString().contains("error 1001")) {
        print("⚠️ Apple 로그아웃은 지원되지 않음. 대신 Firebase 로그아웃만 수행됨.");
      }
    }
  }

  Future<void> logout() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      await googleLogout();
      await kakaoLogout(); // 세션 종료 기록
      await appleLogout();
      // await FlutterNaverLogin.logOut(); // Firebase 로그아웃
      await FirebaseService.recordSessionEnd();
    } catch (error) {
      print('로그아웃 중 오류 발생: $error');
    }
  }

  // 새 비밀번호 이메일 전송 함수 예시 (실제 API나 SMTP 설정이 필요)
  Future<void> _sendEmailWithNewPassword(
      String email, String newPassword) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    // EmailJS API로 요청할 데이터 정의
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': dotenv.env['EMAILJS_SERVICE_ID'],
        'template_id': dotenv.env['PASSWORD_TEMPLATE_ID'],
        'user_id': dotenv.env['EMAILJS_USER_ID'],
        'template_params': {
          'to_email': email,
          'message': '임시 비밀번호: ${newPassword}',
        },
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('계정 정보'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 닉네임 정보
            Text(
              '닉네임 ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Row(
              children: [
                Spacer(),
                GestureDetector(
                  // onTap: () {
                  //   _showAvatarChangeDialog(); // 아바타 변경 다이얼로그 호출
                  // },
                  child: CircleAvatar(
                    radius: 20, // 아바타 크기
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
                Text(
                  _nickname,
                  style: TextStyle(
                      fontSize: 16, color: theme.colorScheme.onSurface),
                ),
                Spacer(),
                BasicElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserDetailsPage()),
                    );
                  },
                  iconTitle: Icons.edit,
                  buttonTitle: '수정',
                ),
              ],
            ),
            // 이메일 정보
            Text(
              '이메일 ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,

                    ),
                  ),
                ),
                SizedBox(height: 50,)
              ],
            ),
            Text(
              '비밀번호 ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            Row(
              children: [
                Spacer(),
                // 비밀번호 변경 버튼
                BasicElevatedButton(
                  onPressed: () {
                    _showPasswordSendDialog(); // 검색 버튼 클릭 시 검색어 필터링
                  },
                  iconTitle: Icons.edit,
                  buttonTitle: '수정',
                )
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              // 버튼 사이 간격을 균등하게 설정
              children: [
                if (user != null && user?.email != 'guest@foodforlater.com') ...[
                  // 계정이 있을 때 탈퇴하기 버튼
                  Expanded(
                    child: NavbarButton(
                      buttonTitle: '탈퇴하기',
                      onPressed: () {
                        _withdrawAlertDialog();
                      },
                    ),
                  ),
                  SizedBox(width: 10), // 두 버튼 사이 간격
                  // 로그아웃 버튼
                  Expanded(
                    child: NavbarButton(
                      buttonTitle: '로그아웃',
                      onPressed: () {
                        _logoutAlertDialog();
                      },
                    ),
                  ),
                ] else
                // 계정이 없을 때 로그인 버튼이 전체 크기를 차지
                  Expanded(
                    child: NavbarButton(
                      buttonTitle: '로그인',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),

                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (userRole != 'admin' && userRole != 'paid_user')
            SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            ),
        ],
      ),

    );
  }

  // 비밀번호 변경 다이얼로그
  Future<void> _showPasswordSendDialog() async {
    final theme = Theme.of(context);
    // 랜덤 6자리 비밀번호 생성 함수
    String _generateRandomPassword(int length) {
      const characters = 'abcdefghijklmnopqrstuvwxyz0123456789';
      Random random = Random();
      return String.fromCharCodes(Iterable.generate(length,
          (_) => characters.codeUnitAt(random.nextInt(characters.length))));
    }

    String newPassword = _generateRandomPassword(6); // 6자리 비밀번호 생성

    if (user != null && user?.email != null) {
      await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('임시 비밀번호 보내기',
                style: TextStyle(color: theme.colorScheme.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${user?.email}로 전송합니다.',
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(hintText: '현재 비밀번호를 입력하세요'),
                  obscureText: true,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('취소'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: Text('보내기'),
                onPressed: () async {
                  try {
                    firebase_auth.AuthCredential credential =
                        firebase_auth.EmailAuthProvider.credential(
                      email: user?.email ?? '',
                      password: _passwordController.text
                          .trim(), // 사용자가 입력한 현재 비밀번호로 설정
                    );
                    if (_passwordController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('현재 비밀번호를 입력해주세요.')),
                      );
                      return;
                    }
                    await user?.reauthenticateWithCredential(credential);
                    await user?.updatePassword(newPassword);
                    await _sendEmailWithNewPassword(
                        user?.email ?? '', newPassword);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('비밀번호가 이메일로 전송되었습니다.')),
                      );
                      Navigator.pop(context); // 다이얼로그 닫기
                    }
                  } on firebase_auth.FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      // 사용자에게 재로그인 요구
                      await firebase_auth.FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => LoginPage()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('비밀번호 업데이트 실패: ${e.message}')),
                      );
                    }
                  } catch (e) {
                    print('비밀번호 업데이트 오류: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('비밀번호 업데이트 실패: $e')),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 상태를 확인할 수 없습니다.')),
      );
    }
  }

  Future<void> _showNicknameChangeDialog() async {
    final theme = Theme.of(context);
    TextEditingController _nickNameController = TextEditingController();

    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('닉네임 변경',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: TextField(
              controller: _nickNameController,
              // obscureText: true,
              decoration: InputDecoration(hintText: '새 닉네임을 입력하세요'),
              style: TextStyle(color: theme.colorScheme.onSurface)),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('변경'),
              onPressed: () async {
                String newNickname = _nickNameController.text.trim();
                if (newNickname.isNotEmpty && user != null) {
                  // Firestore의 users 컬렉션에 닉네임 업데이트
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid) // 사용자 ID를 기준으로 문서 선택
                      .set({'nickname': newNickname}, SetOptions(merge: true));
                  // 로컬 상태 업데이트
                  setState(() {
                    _nickname = newNickname;
                  });
                  Navigator.pop(context); // 다이얼로그 닫기
                } else {
                  // 닉네임이 비어있으면 안내 메시지 추가 가능
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('닉네임을 입력해주세요')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 로그아웃 처리
  void _logoutAlertDialog() async {
    final theme = Theme.of(context);
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '로그아웃을 진행할까요?',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('로그아웃'),
              onPressed: () async {
                logout();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => LoginPage()),
                        (route) => false,// 로그인 페이지로 이동
                  );
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _withdrawAlertDialog() async {
    final theme = Theme.of(context);
    final TextEditingController _passwordController = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('😢정말로 탈퇴를 하실껀가요?',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passwordController,
                obscureText: true, // 비밀번호 감추기
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '비밀번호를 입력해주세요',
                ),
                style:
                TextStyle(color: theme.chipTheme.labelStyle!.color),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('정말로 탈퇴하기',
        style: TextStyle(
        color: Colors.red
        ),),
              onPressed: () async {
                if (_passwordController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('비밀번호를 입력해주세요.'),
                      behavior: SnackBarBehavior.floating,),
                  );
                  return;
                }
                try {
                  await _reauthenticateUser(); // 재인증 시도
                  await _deleteAccount(); // 계정 삭제
                  Navigator.pop(context); // 성공 시 다이어로그 닫기
                } catch (e) {
                  // 실패 메시지를 보여주고 다이어로그는 닫지 않음
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('비밀번호를 확인해주세요.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Future<void> _showAvatarChangeDialog() async {
  //   final theme = Theme.of(context);
  //   List<String> avatarList = List.generate(
  //     25,
  //     (index) =>
  //         'assets/avatar/avatar-${(index + 1).toString().padLeft(2, '0')}.png',
  //   );
  //
  //   await showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text('아바타 선택',
  //             style: TextStyle(color: theme.colorScheme.onSurface)),
  //         content: Container(
  //           width: double.maxFinite,
  //           child: GridView.builder(
  //             shrinkWrap: true,
  //             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //               crossAxisCount: 5, // 한 줄에 5개의 아바타 표시
  //               crossAxisSpacing: 5,
  //               mainAxisSpacing: 5,
  //             ),
  //             itemCount: avatarList.length,
  //             itemBuilder: (context, index) {
  //               return GestureDetector(
  //                 onTap: () async {
  //                   String selectedAvatar = avatarList[index];
  //                   await FirebaseFirestore.instance
  //                       .collection('users')
  //                       .doc(user?.uid)
  //                       .set({'avatar': selectedAvatar},
  //                           SetOptions(merge: true));
  //                   setState(() {
  //                     _avatar = selectedAvatar;
  //                   });
  //                   Navigator.pop(context); // 다이얼로그 닫기
  //                 },
  //                 child: CircleAvatar(
  //                   radius: 30,
  //                   backgroundImage: AssetImage(avatarList[index]),
  //                 ),
  //               );
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('닫기'),
  //             onPressed: () => Navigator.pop(context),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
}
