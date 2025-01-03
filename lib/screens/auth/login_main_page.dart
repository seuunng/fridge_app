import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:food_for_later_new/services/firebase_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/login_elevated_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'kakao_mobile_login.dart' if (dart.library.html) 'kakao_web_login.dart';
import 'kakao_mobile_login.dart' as mobile;
import 'kakao_web_login.dart' as web;
import 'dart:math'; // 여기 추가

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';

  final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _validateInputs() {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        errorMessage = '이메일과 비밀번호를 모두 입력해주세요.';
      });
      return false;
    }
    return true;
  }

  Future<void> addUserToFirestore(firebase_auth.User user,
      {String? nickname,
      String? email,
      String? gender,
      String? birthYear}) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'nickname': nickname ?? user.displayName ?? '닉네임 없음',
        'email': email ?? user.email ?? '이메일 없음',
        'signupdate': formattedDate,
        'gender': gender ?? '알 수 없음',
        'birthYear': birthYear ?? '알 수 없음',
        'role': 'user',
      });
    }
  }

  Future<void> signInWithEmailAndPassword() async {
    if (!_validateInputs()) return;
    try {
      firebase_auth.UserCredential result =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (result.user != null) {
        await addUserToFirestore(result.user!);
        await FirebaseService.recordSessionStart();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = '로그인 실패: 사용자 정보를 가져올 수 없습니다.';
          });
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = '로그인 실패: ${e.code} - ${e.message}';
        });
      }
      print('로그인 실패: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        errorMessage = '로그인 실패: 알 수 없는 오류 - ${e.toString()}';
      });
      print('로그인 실패: 알 수 없는 오류 - ${e.toString()}');
    }
  }

  Future<void> registerWithEmailAndPassword() async {
    if (!_validateInputs()) return;
    try {
      firebase_auth.UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (result.user != null) {
        await addUserToFirestore(result.user!); // Firestore에 사용자 추가
        assignRandomAvatarToUser(result.user!.uid);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      // FirebaseAuthException 별 오류 처리
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '잘못된 이메일 형식입니다.';
          break;
        case 'weak-password':
          errorMessage = '비밀번호는 6자리 이상이어야 합니다.';
          break;
        default:
          errorMessage = '회원가입 실패: ${e.message}';
      }
      setState(() {});
      print('회원가입 실패: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        errorMessage = '회원가입 실패: ${e.toString()}';
      });
      print('회원가입 실패: ${e.toString()}');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      await fetchGoogleUserInfo(googleAuth.accessToken!);

      final firebase_auth.OAuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 사용자 인증
      firebase_auth.UserCredential result =
          await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await addUserToFirestore(result.user!); // Firestore에 사용자 추가
        await FirebaseService.recordSessionStart();
        assignRandomAvatarToUser(result.user!.uid);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Google 로그인 실패: ${e.toString()}';
        });
      }
      print('Google 로그인 실패: $e');
    }
  }

  Future<void> signInWithGoogleWeb() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    try {
      final googleProvider = firebase_auth.GoogleAuthProvider();
      final userCredential = await auth.signInWithPopup(googleProvider);
      // print('Google 로그인 성공: ${userCredential.user}');
    } catch (e) {
      print('Google 로그인 실패: $e');
    }
  }

  Future<void> fetchGoogleUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse(
          'https://people.googleapis.com/v1/people/me?personFields=genders,birthdays'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final String? gender = data['genders']?[0]['value']; // 성별
      final String? birthYear =
          data['birthdays']?[0]['date']['year'].toString(); // 출생연도
    } else {
      print('Google 사용자 정보 가져오기 실패: ${response.body}');
    }
  }
  // Future<void> signInWithKakao() async {
  //   try {
  //     bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
  //     kakao.OAuthToken token = isKakaoTalkInstalled
  //         ? await kakao.UserApi.instance.loginWithKakaoTalk()
  //         : await kakao.UserApi.instance.loginWithKakaoAccount();
  //
  //     final account = await kakao.UserApi.instance.me();
  //
  //     final kakaoEmail = account.kakaoAccount?.email;
  //     if (kakaoEmail == null) {
  //       throw Exception('카카오 계정에서 이메일 정보를 가져올 수 없습니다.');
  //     }
  //
  //     final kakaoNickname = account.kakaoAccount?.profile?.nickname ?? '닉네임 없음';
  //
  //     final kakaoAccessToken = token.accessToken;
  //     final response = await http.post(
  //       Uri.parse(
  //           'https://us-central1-food-for-later.cloudfunctions.net/createFirebaseToken'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'kakaoAccessToken': kakaoAccessToken}),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final firebaseCustomToken = data['firebaseCustomToken'];
  //
  //       final userCredential = await firebase_auth.FirebaseAuth.instance
  //           .signInWithCustomToken(firebaseCustomToken);
  //
  //       if (userCredential.user != null) {
  //         await addUserToFirestore(userCredential.user!,
  //             nickname: kakaoNickname, email: kakaoEmail);
  //       }
  //
  //       if (mounted) {
  //         Navigator.pushReplacementNamed(
  //             context, '/home'); // '/home'은 실제 홈 화면의 라우트 이름으로 변경
  //       }
  //     } else {
  //       print('Firebase Custom Token 생성 실패: ${response.body}');
  //     }
  //   } catch (e) {
  //     print('카카오 로그인 오류: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('카카오 로그인에 실패했습니다.')),
  //     );
  //   }
  // }

  Future<void> signInWithNaver() async {
    try {
      final NaverLoginResult res = await FlutterNaverLogin.logIn();
      if (res.status == NaverLoginStatus.loggedIn) {
        NaverAccessToken token = await FlutterNaverLogin.currentAccessToken;

        // 사용자 정보 가져오기
        final NaverAccountResult account = res.account;

        final response = await createNaverFirebaseToken(token.accessToken);
        if (response != null) {
          final firebaseUser = await _auth.signInWithCustomToken(response);

          if (firebaseUser.user != null) {
            await addUserToFirestore(
              firebaseUser.user!,
              nickname: res.account.nickname,
              email: res.account.email,
              gender: res.account.gender ?? '알 수 없음',
              birthYear: res.account.birthyear ?? '알 수 없음',
            );
            assignRandomAvatarToUser(firebaseUser.user!.uid);
            await FirebaseService.recordSessionStart();
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        print("네이버 로그인 실패: ${res.status}");
        if (res.errorMessage != null) {
          print("네이버 로그인 실패 Error Message: ${res.errorMessage}");
        }
      }
    } catch (e) {
      print("네이버 로그인 중 오류 발생: $e");
    }
  }

  void signInWithNaverWeb() {
    final clientId = dotenv.env['NAVER_CLIENT_ID'];
    final redirectUri =
        Uri.encodeComponent('https://food_for_later.com/auth/callback');
    final state = 'random_string';

    final url = 'https://nid.naver.com/oauth2.0/authorize'
        '?response_type=code'
        '&client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&state=$state';

    // html.window.location.href = url;
  }

  Future<String?> createNaverFirebaseToken(String accessToken) async {
    final uri = Uri.parse(
        'https://us-central1-food-for-later.cloudfunctions.net/createNaverFirebaseToken');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'accessToken': accessToken}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['firebaseCustomToken'];
    } else {
      print('Firebase Function Error: ${response.body}');
      return null;
    }
  }

  Future<String> createFirebaseToken(String kakaoAccessToken) async {
    final uri = Uri.parse(
        'https://us-central1-food-for-later.cloudfunctions.net/createFirebaseToken'); // 백엔드 서버의 엔드포인트
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'kakaoAccessToken': kakaoAccessToken}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['firebaseCustomToken'];
    } else {
      print('Firebase Function Error: ${response.body}');
      throw Exception('Failed to generate Firebase Custom Token');
    }
  }

  void assignRandomAvatarToUser(String userId) async {
    // 랜덤으로 아바타 선택
    int randomAvatarIndex = Random().nextInt(25) + 1; // 1~25 사이 랜덤 숫자
    String avatarPath =
        'assets/avatar/avatar-${randomAvatarIndex.toString().padLeft(2, '0')}.png';

    // Firestore에 저장
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set({'avatar': avatarPath}, SetOptions(merge: true));
  }
  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse(
        'https://seuunng.github.io/food_for_later_privacy_policy/privacy-policy.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
  Future<void> _launchTermsOfService() async {
    final Uri url = Uri.parse(
        'https://seuunng.github.io/food_for_later_privacy_policy/terms-of-service.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('로그인')),
      body:  SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  TextField(
                    controller: _emailController,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    decoration: InputDecoration(labelText: '이메일'),
                  ),
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    decoration: InputDecoration(labelText: '비밀번호'),
                    obscureText: true,
                  ),
                  SizedBox(height: 12),
                  BasicElevatedButton(
                    onPressed: signInWithEmailAndPassword,
                    iconTitle: Icons.login,
                    buttonTitle: '로그인',
                  ),
                  TextButton(
                    onPressed: registerWithEmailAndPassword,
                    child: Text('회원가입'),
                  ),
                  Divider(),
                  SizedBox(height: 20),
                  LoginElevatedButton(
                    buttonTitle: 'Google로 로그인',
                    image: 'assets/images/google_logo.png',
                    onPressed: () {
                      if (kIsWeb) {
                        signInWithGoogleWeb(); // 웹용 네이버 로그인
                      } else {
                        signInWithGoogle(); // 모바일용 네이버 로그인
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  LoginElevatedButton(
                    buttonTitle: 'Kakao Talk으로 로그인',
                    image: 'assets/images/kakao_talk_logo.png',
                    onPressed: () {
                      if (kIsWeb) {
                        web.signInWithKakao(); // 웹용 카카오 로그인
                      } else {
                        mobile.signInWithKakao(context); // 모바일용 카카오 로그인
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  LoginElevatedButton(
                    buttonTitle: 'Naver로 로그인',
                    image: 'assets/images/naver_logo.png',
                    onPressed: () {
                      if (kIsWeb) {
                        signInWithNaverWeb(); // 웹용 네이버 로그인
                      } else {
                        signInWithNaver(); // 모바일용 네이버 로그인
                      }
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _launchPrivacyPolicy,
                    child: Text('개인정보방침'),
                  ),
                  SizedBox(width: 8), // 버튼과 구분자 사이 여백 추가
                  Text(
                    '|',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: _launchTermsOfService,
                    child: Text('서비스약관'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
