import 'dart:async';
import 'dart:convert';
import 'dart:math'; // 여기 추가
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/screens/auth/user_details_page.dart';
import 'package:food_for_later_new/screens/settings/app_usage_settings.dart';
import 'package:food_for_later_new/services/default_fridge_service.dart';
import 'package:food_for_later_new/services/firebase_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/login_elevated_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'kakao_mobile_login.dart' if (dart.library.html) 'kakao_web_login.dart';
import 'kakao_mobile_login.dart' as mobile;
import 'kakao_web_login.dart' as web;
//ios 수정
import 'naver_login_stub.dart'
if (dart.library.io) 'package:flutter_naver_login/flutter_naver_login.dart'
if (dart.library.js) 'naver_login_stub.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/user.birthday.read',
      'https://www.googleapis.com/auth/userinfo.profile',
      'https://www.googleapis.com/auth/user.gender.read',
    ],
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode(); // 이메일 입력 필드의 포커스 노드
  final FocusNode _passwordFocusNode = FocusNode(); // 비밀번호 입력 필드의 포커스
  String errorMessage = '';
  bool _isLoading = false; // 로딩 상태 관리
  String userRole = '';
  bool _isPremiumUser = false;
  String passwordErrorMessage = '';

  final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
  final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  @override
  void initState() {
    super.initState();
    _loadUserRole();

    // 리스너 추가
    _emailFocusNode.addListener(() {
      setState(() {}); // 포커스 변경 시 상태 업데이트
    });
    _passwordFocusNode.addListener(() {
      setState(() {}); // 포커스 변경 시 상태 업데이트
    });
  }

  @override
  void dispose() {
    // 컨트롤러 및 포커스 노드 해제
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
  Future<void> addUserToFirestore(firebase_auth.User user,
      {String? nickname,
      String? email,
      String? gender,
      int? birthYear,
       String? avatar,}) async {
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'nickname': nickname ?? user.displayName ?? '닉네임 없음',
        'email': email ?? user.email ?? '이메일 없음',
        'signupdate': formattedDate,
        'gender': gender ?? '알 수 없음',
        'birthYear': birthYear ?? '0',
        'role': 'user',
        'avatar': avatar,
      });
    }
  }

  Future<void> signInWithEmailAndPassword() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      // 이메일 또는 비밀번호가 비어 있을 때 안내 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일과 비밀번호를 모두 입력해주세요.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true; // 로딩 상태 시작
    });
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('이메일 혹은 비밀번호가 일치하지 않습니다.'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = '이메일 혹은 비밀번호가 일치하지 않습니다.';
          break;
        case 'wrong-password':
          errorMsg = '이메일 혹은 비밀번호가 일치하지 않습니다.';
          break;
        case 'invalid-credential':
          errorMsg = '이메일 혹은 비밀번호가 일치하지 않습니다.';
          break;
        case 'invalid-email':
          errorMsg = '잘못된 이메일 형식입니다.';
          break;
        case 'weak-password':
          errorMsg = '비밀번호는 6자리 이상이어야 합니다.';
          break;
        default:
          errorMsg = '로그인 실패: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('로그인 실패: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        errorMessage = '로그인 실패: 알 수 없는 오류 - ${e.toString()}';
      });
      print('로그인 실패: 알 수 없는 오류 - ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false; // 로딩 상태 종료
      });
    }
  }

  Future<void> registerWithEmailAndPassword() async {
    // if (!_validateInputs()) return;
    // 입력 필드가 비어있는지 확인
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      // SnackBar로 경고 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일과 비밀번호를 모두 입력해주세요.'),
          duration: Duration(seconds: 2), // 스낵바 표시 시간
          behavior: SnackBarBehavior.floating, // 화면에 떠있는 스낵바 스타일
        ),
      );
      return; // 입력이 유효하지 않으므로 함수 종료
    }
    try {
      firebase_auth.UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (result.user != null) {
        await addUserToFirestore(result.user!); // Firestore에 사용자 추가
        await DefaultFridgeService().createDefaultFridge(result.user!.uid);

        print(result.user!.uid);
        assignRandomAvatarToUser(result.user!.uid);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserDetailsPage()),
          );
        }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage = '회원가입 실패: ${e.toString()}';
      });
      print('회원가입 실패: ${e.toString()}');
    }
  }

  Future<void> signInWithGoogle() async {
    if (_isLoading) return; // 이미 로딩 중이면 함수 종료
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      // Google People API로 추가 정보 가져오기
      final googleUserInfo = await fetchGoogleUserInfo(googleAuth.accessToken!);
      final String gender = (googleUserInfo['gender'] == "female")
          ? 'F'
          : (googleUserInfo['gender'] == "male")
          ? 'M'
          : '알 수 없음'; // 기타 또는 null 처리
      final int birthYear = int.tryParse(googleUserInfo['birthYear'] ?? '0') ?? 0;
      final String photoUrl = googleUser.photoUrl ?? '';

      final firebase_auth.OAuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 사용자 인증
      firebase_auth.UserCredential result =
          await _auth.signInWithCredential(credential);
      if (result.user != null) {
        await addUserToFirestore(result.user!,
          gender: gender,
          birthYear: birthYear,
          avatar: photoUrl,
        ); // Firestore에 사용자 추가
        await FirebaseService.recordSessionStart();
        assignRandomAvatarToUser(result.user!.uid);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 로그인에 실패했습니다.: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> signInWithGoogleWeb() async {
    final firebase_auth.FirebaseAuth auth = firebase_auth.FirebaseAuth.instance;
    await auth.setLanguageCode('ko');
    try {
      final googleProvider = firebase_auth.GoogleAuthProvider();
      final userCredential = await auth.signInWithPopup(googleProvider);
      // print('Google 로그인 성공: ${userCredential.user}');
    } catch (e) {
      print('Google 로그인 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 로그인에 실패했습니다.: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<Map<String, String>> fetchGoogleUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse(
          'https://people.googleapis.com/v1/people/me?personFields=genders,birthdays'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Google API 응답 데이터: $data');  // 응답 전체 출력
      final String gender = data['genders'] != null && data['genders'].isNotEmpty
          ? data['genders'][0]['value']
          : '알 수 없음';

      final String birthYear = data['birthdays'] != null &&
          data['birthdays'].isNotEmpty &&
          data['birthdays'][0]['date']?['year'] != null
          ? data['birthdays'][0]['date']['year'].toString()
          : '0';

      return {'gender': gender, 'birthYear': birthYear};
    } else {
      print('Google API 호출 실패: ${response.statusCode} - ${response.body}');
      return {'gender': 'N/A', 'birthYear': 'N/A'};
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
    if (!Platform.isAndroid) {
      print('네이버 로그인은 Android에서만 지원됩니다.');
      return;
    }

    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    // print('signInWithNaver() 실행');
    try {

      // await Future.delayed(Duration(milliseconds: 100));
      final NaverLoginResult res = await FlutterNaverLogin.logIn();
      if (res.status == NaverLoginStatus.loggedIn) {
        NaverAccessToken token = await FlutterNaverLogin.currentAccessToken;

        // 사용자 정보 가져오기
        final NaverAccountResult account = res.account;
        // print('naver로그인: $account');
        final response = await createNaverFirebaseToken(token.accessToken);
        if (response != null) {
          await Future.delayed(Duration(milliseconds: 100));
          final firebaseUser = await _auth.signInWithCustomToken(response);
          // print('naver로그인');
          // print(res.account.profileImage);
          if (firebaseUser.user != null) {
            await addUserToFirestore(
              firebaseUser.user!,
              nickname: res.account.nickname,
              email: res.account.email,
              gender: res.account.gender ?? '알 수 없음',
              birthYear: int.tryParse(res.account.birthyear ?? '0') ?? 0,
              avatar: res.account.profileImage ?? '알 수 없음',
            );
            // assignRandomAvatarToUser(firebaseUser.user!.uid);
            await FirebaseService.recordSessionStart();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네이버 로그인에 실패했습니다.: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false; // 로딩 상태 해제
      });
    }
  }

  // Future<void> signInWithNaver() async {
  //   if (!Platform.isAndroid) {
  //     print('네이버 로그인은 Android에서만 지원됩니다.');
  //     return;
  //   }
  //
  //   if (_isLoading) return;
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     final NaverLoginResult res = await FlutterNaverLogin.logIn();
  //     if (res.status == NaverLoginStatus.loggedIn) {
  //       // NaverAccessToken token = await FlutterNaverLogin.currentAccessToken;
  //       NaverAccessToken token = await FlutterNaverLogin.currentAccessToken(); //ios 수정
  //       final NaverAccountResult account = res.account;
  //
  //       final response = await createNaverFirebaseToken(token.accessToken);
  //       if (response != null) {
  //         final firebaseUser = await _auth.signInWithCustomToken(response);
  //         if (firebaseUser.user != null) {
  //           await addUserToFirestore(
  //             firebaseUser.user!,
  //             nickname: account.nickname,
  //             email: account.email,
  //             gender: account.gender ?? '알 수 없음',
  //             birthYear: int.tryParse(account.birthyear ?? '0') ?? 0,
  //             avatar: account.profileImage ?? '알 수 없음',
  //           );
  //           await FirebaseService.recordSessionStart();
  //           if (mounted) {
  //             Navigator.pushReplacementNamed(context, '/home');
  //           }
  //         }
  //       }
  //     } else {
  //       print("네이버 로그인 실패: ${res.status}");
  //     }
  //   } catch (e) {
  //     print("네이버 로그인 중 오류 발생: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('네이버 로그인에 실패했습니다.: $e'),
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

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
  Future<void> signInWithApple() async {
    if (Platform.isIOS) {
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        print("Apple 로그인 성공: ${credential.email}");
        // Apple 로그인 후 Firebase 인증 처리 추가 가능
      } catch (e) {
        print("Apple 로그인 실패: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple 로그인에 실패했습니다.')),
        );
      }
    }
  }
  void assignRandomAvatarToUser(String userId) async {
    // 랜덤으로 아바타 선택
    int randomAvatarIndex = Random().nextInt(25) + 1; // 1~25 사이 랜덤 숫자
    // String avatarPath =
    //     'assets/avatar/avatar-${randomAvatarIndex.toString().padLeft(2, '0')}.png';

    // Firestore에 저장
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(userId)
    //     .set({'avatar': avatarPath}, SetOptions(merge: true));
  }
  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse(
        'https://food-for-later.web.app/privacy-policy.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
  Future<void> _launchTermsOfService() async {
    final Uri url = Uri.parse(
        'https://food-for-later.web.app/terms-of-service.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _launchHomePage() async {
    final Uri url = Uri.parse('https://food-for-later.web.app/home.html');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('로그인'),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: _launchHomePage,
            tooltip: '홈으로 이동',
          ),
        ],),
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
                      focusNode: _emailFocusNode, // 이메일 입력 필드와 포커스 노드 연결
                      maxLength: 64,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                      ),
                      decoration: InputDecoration(
                          labelText: '이메일',
                        counterText: '',),
                    ),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      maxLength: 32, // 이메일 최대 길이 제한
                      style: TextStyle(
                          color: theme.colorScheme.onSurface
                      ),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        counterText: '',
                        errorText: passwordErrorMessage.isNotEmpty ? passwordErrorMessage : null,),
                      obscureText: true,
                      onChanged: (value) {
                        setState(() {
                          passwordErrorMessage = value.length < 6 ? '비밀번호는 6자 이상으로 작성해주세요.' : '';
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    BasicElevatedButton(
                      onPressed: () {
                        if (!_isLoading) {
                          signInWithEmailAndPassword();
                        }
                      },
                      iconTitle: Icons.login,
                      buttonTitle: '로그인',
                    ),
                    TextButton(
                      onPressed: registerWithEmailAndPassword,
                      child: Text('회원가입'),
                    ),
                    if (_emailFocusNode.hasFocus)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _emailController.text.trim().isNotEmpty
                              ? '수신 가능한 이메일을 입력해주세요.'
                              : '',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    // if (_passwordFocusNode.hasFocus)
                    //   Padding(
                    //     padding: const EdgeInsets.all(8.0),
                    //     child: Text(
                    //       _passwordController.text.trim().isNotEmpty
                    //           ? '비밀번호는 6자 이상으로 작성해주세요.'
                    //           : '',
                    //       style: TextStyle(color: Colors.grey, fontSize: 14),
                    //     ),
                    //   ),
                    Divider(),
                    SizedBox(height: 20),
                    LoginElevatedButton(
                      buttonTitle: 'Google로 로그인',
                      image: 'assets/images/google_logo.png',
                      onPressed: () {
                        if (!_isLoading) {
                          if (kIsWeb) {
                            signInWithGoogleWeb(); // 웹용 네이버 로그인
                          } else {
                            signInWithGoogle(); // 모바일용 네이버 로그인
                          }
                        }
                      }
                    ),
                    SizedBox(height: 12),
                    LoginElevatedButton(
                      buttonTitle: 'Kakao Talk으로 로그인',
                      image: 'assets/images/kakao_talk_logo.png',
                      onPressed: () {
                        if (!_isLoading) {
                          if (kIsWeb) {
                            web.signInWithKakao(); // 웹용 카카오 로그인
                          } else {
                            mobile.signInWithKakao(context); // 모바일용 카카오 로그인
                          }
                        }
                      }
                    ),
                    SizedBox(height: 12),
                    if (!Platform.isIOS)
                    LoginElevatedButton(
                      buttonTitle: 'Naver로 로그인',
                      image: 'assets/images/naver_logo.png',
                      onPressed: () {
                        if (!_isLoading) {
                          if (kIsWeb) {
                            signInWithNaverWeb(); // 웹용 네이버 로그인
                          } else {
                            signInWithNaver(); // 모바일용 네이버 로그인
                          }
                        }
                      }
                    ),
                    if (Platform.isIOS)
                      LoginElevatedButton(
                        buttonTitle: 'Apple로 로그인',
                        image: 'assets/images/apple_logo.png',
                        onPressed: signInWithApple,
                      ),

                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
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
                  ),
                ),

              ],
            ),
          ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
        children: [
          if (userRole != 'admin' && userRole != 'paid_user')
            SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            ),
        ],
      ),
    );
  }
}
