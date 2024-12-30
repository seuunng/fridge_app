import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:http/http.dart' as http;

final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    Future<void> signInWithKakao(BuildContext context) async {
      try {
        bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
        kakao.OAuthToken token = isKakaoTalkInstalled
        ? await kakao.UserApi.instance.loginWithKakaoTalk()
        : await kakao.UserApi.instance.loginWithKakaoAccount();

    final account = await kakao.UserApi.instance.me();

    final kakaoEmail = account.kakaoAccount?.email;
    if (kakaoEmail == null) {
      throw Exception('카카오 계정에서 이메일 정보를 가져올 수 없습니다.');
    }

    final kakaoNickname = account.kakaoAccount?.profile?.nickname ?? '닉네임 없음';
    final kakaoAccessToken = token.accessToken;

    final response = await http.post(
      Uri.parse(
          'https://us-central1-food-for-later.cloudfunctions.net/createFirebaseToken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'kakaoAccessToken': kakaoAccessToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final firebaseCustomToken = data['firebaseCustomToken'];

      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithCustomToken(firebaseCustomToken);

      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'nickname': kakaoNickname,
          'email': kakaoEmail,
          'signupdate': DateTime.now().toIso8601String(),
          'role': 'user',
        });
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      throw Exception('Firebase Custom Token 생성 실패: ${response.body}');
    }
  } catch (e) {
    print('카카오 로그인 오류: $e');
  }
}
// class KakaoMobileLoginPage extends StatefulWidget {
//   @override
//   _KakaoMobileLoginPageState createState() => _KakaoMobileLoginPageState();
// }
//
// class _KakaoMobileLoginPageState extends State<KakaoMobileLoginPage> {
//   final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//   Future<void> signInWithKakao() async {
//     try {
//       bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
//       kakao.OAuthToken token = isKakaoTalkInstalled
//           ? await kakao.UserApi.instance.loginWithKakaoTalk()
//           : await kakao.UserApi.instance.loginWithKakaoAccount();
//
//       final account = await kakao.UserApi.instance.me();
//
//       final kakaoEmail = account.kakaoAccount?.email;
//       if (kakaoEmail == null) {
//         throw Exception('카카오 계정에서 이메일 정보를 가져올 수 없습니다.');
//       }
//
//       final kakaoNickname =
//           account.kakaoAccount?.profile?.nickname ?? '닉네임 없음';
//
//       final kakaoAccessToken = token.accessToken;
//       final response = await http.post(
//         Uri.parse(
//             'https://us-central1-food-for-later.cloudfunctions.net/createFirebaseToken'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({'kakaoAccessToken': kakaoAccessToken}),
//       );
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final firebaseCustomToken = data['firebaseCustomToken'];
//
//         final userCredential = await firebase_auth.FirebaseAuth.instance
//             .signInWithCustomToken(firebaseCustomToken);
//
//         if (userCredential.user != null) {
//           await addUserToFirestore(userCredential.user!,
//               nickname: kakaoNickname, email: kakaoEmail);
//         }
//
//         if (mounted) {
//           Navigator.pushReplacementNamed(context, '/home'); // 홈 화면으로 이동
//         }
//       } else {
//         print('Firebase Custom Token 생성 실패: ${response.body}');
//       }
//     } catch (e) {
//       print('카카오 로그인 오류: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('카카오 로그인에 실패했습니다.')),
//         );
//       }
//     }
//   }
//
//   Future<void> addUserToFirestore(firebase_auth.User user,
//       {String? nickname, String? email}) async {
//     final userDoc =
//     FirebaseFirestore.instance.collection('users').doc(user.uid);
//
//     final docSnapshot = await userDoc.get();
//     if (!docSnapshot.exists) {
//       await userDoc.set({
//         'nickname': nickname ?? user.displayName ?? '닉네임 없음',
//         'email': email ?? user.email ?? '이메일 없음',
//         'signupdate': formattedDate,
//         'role': 'user',
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Kakao Login')),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: signInWithKakao,
//           child: Text('카카오 로그인'),
//         ),
//       ),
//     );
//   }
// }