import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:food_for_later_new/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:http/http.dart' as http;

final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

Future<bool> signInWithKakao(BuildContext context) async {
  // print('1. 카카오로그인 시도!');
  try {
    // ✅ 카카오 세션 초기화 (오류 방지)
    await kakao.TokenManagerProvider.instance.manager.clear();
    // 카카오톡 설치 여부 확인 및 로그인
    bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
    // kakao.OAuthToken token = isKakaoTalkInstalled
    //     ? await kakao.UserApi.instance.loginWithKakaoTalk()
    //     : await kakao.UserApi.instance.loginWithKakaoAccount();
    // 추가 동의 요청

    // List<String> scopes = ['birthyear', 'gender', 'profile_image'];
    kakao.OAuthToken token;
    if (isKakaoTalkInstalled) {
      token = await kakao.UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    // 사용자 정보 가져오기
    final account = await kakao.UserApi.instance.me();

    // 추가 동의가 필요한 항목 확인
    List<String> requiredScopes = [];
    if (account.kakaoAccount?.birthyearNeedsAgreement == true) {
      requiredScopes.add('birthyear');
    }
    if (account.kakaoAccount?.genderNeedsAgreement == true) {
      requiredScopes.add('gender');
    }
    if (account.kakaoAccount?.profileNeedsAgreement == true) {
      requiredScopes.add('profile_image');
    }

// 추가 동의 항목이 있을 경우 추가 동의 요청
    if (requiredScopes.isNotEmpty) {
      await kakao.UserApi.instance.loginWithNewScopes(requiredScopes);
    }

// 동의 후 최신 계정 정보 재조회
    final updatedAccount = await kakao.UserApi.instance.me();
// ✅ 사용자 정보 다시 가져오기
    final String? kakaoEmail = updatedAccount.kakaoAccount?.email;
    final String kakaoNickname =
        updatedAccount.kakaoAccount?.profile?.nickname ?? '닉네임 없음';
    final kakaoGender = updatedAccount.kakaoAccount?.gender;
    final kakaoBirthYear = updatedAccount.kakaoAccount?.birthyear;
    final kakaoAvatarUrl =
        updatedAccount.kakaoAccount?.profile?.thumbnailImageUrl;
// 성별 변환 로직 (Gender.female -> F, Gender.male -> M)
    String genderCode = (kakaoGender == 'Gender.female')
        ? 'F'
        : (kakaoGender == 'Gender.male' ? 'M' : 'U'); // 알 수 없음은 U로 처리

    // 출생연도를 숫자로 변환 (null일 경우 -1 저장)
    int birthYear = kakaoBirthYear != null ? int.tryParse(kakaoBirthYear) ?? -1 : -1;
    if (kakaoEmail == null) {
      throw Exception('카카오 계정에서 이메일 정보를 가져올 수 없습니다.');
    }

    // Firebase Custom Token 생성
    final response = await http.post(
      Uri.parse(
          'https://us-central1-food-for-later.cloudfunctions.net/createFirebaseToken'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'kakaoAccessToken': token.accessToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final firebaseCustomToken = data['firebaseCustomToken'];

      // Firebase 인증
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithCustomToken(firebaseCustomToken);

      if (userCredential.user != null) {
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid);

        final docSnapshot = await userDoc.get();
        if (!docSnapshot.exists) {
          // 랜덤 아바타 설정 (기본값)
          int randomAvatarIndex = Random().nextInt(25) + 1;
          String defaultAvatar =
              'assets/avatar/avatar-${randomAvatarIndex.toString().padLeft(2, '0')}.png';

          // Firestore에 사용자 데이터 저장
          await userDoc.set({
            'nickname': kakaoNickname,
            'email': kakaoEmail,
            'gender': genderCode ?? '알 수 없음', // 변환된 성별 코드
            'birthYear': birthYear ?? '알 수 없음',
            'signupdate': formattedDate,
            'avatar': kakaoAvatarUrl ?? defaultAvatar,
            'role': 'user',
          });
        }
      }

      // 세션 기록 시작
      await FirebaseService.recordSessionStart();

      // print('카카오로그인 성공?!');
      // ✅ Firestore 저장 후 페이지 이동
      // if (context.mounted) {
      //   print('네비게이터 실행');
      //   Navigator.pushReplacementNamed(context, '/home');
      // } else {
      //   print('mounted 없음');
      // }
      return true;

    } else {
      throw Exception('Firebase Custom Token 생성 실패: ${response.body}');
    }
  } catch (e) {
    if (e is kakao.KakaoAuthException && e.error == kakao.AuthErrorCause.accessDenied) {
      print('사용자가 카카오 로그인을 취소했습니다.');
      // 취소된 경우라면 추가 메시지 없이 조용히 처리하거나, 필요하면 SnackBar를 띄워주세요.
    } else {
      print('🚨 카카오 로그인 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인에 실패했습니다.: $e'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  return false;
}
// void navigateToHome(BuildContext context) async {
//   int retryCount = 0;
//   while (!context.mounted && retryCount < 10) {
//     print("⏳ context.mounted == false, 100ms 후 재시도... ($retryCount)");
//     await Future.delayed(Duration(milliseconds: 100));
//     retryCount++;
//   }
//
//   if (context.mounted) {
//     print("✅ context.mounted == true, 네비게이션 실행");
//     Navigator.pushReplacementNamed(context, '/home');
//   } else {
//     print("🚨 여전히 context.mounted == false, 네비게이션 실행 불가");
//   }
// }

