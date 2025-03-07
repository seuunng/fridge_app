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

Future<void> signInWithKakao(BuildContext context) async {
  try {
    // ✅ 카카오 세션 초기화 (오류 방지)
    await kakao.TokenManagerProvider.instance.manager.clear();
    // 카카오톡 설치 여부 확인 및 로그인
    bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
    kakao.OAuthToken token = isKakaoTalkInstalled
        ? await kakao.UserApi.instance.loginWithKakaoTalk()
        : await kakao.UserApi.instance.loginWithKakaoAccount();
    // 추가 동의 요청
    List<String> scopes = ['birthyear', 'gender', 'profile_image'];
    kakao.OAuthToken scopestoken = await kakao.UserApi.instance.loginWithNewScopes(scopes);
    // 사용자 정보 가져오기
    final account = await kakao.UserApi.instance.me();

    final String? kakaoEmail = account.kakaoAccount?.email;
    final String? kakaoNickname = account.kakaoAccount?.profile?.nickname ?? '닉네임 없음';
    final String? kakaoGender = account.kakaoAccount?.gender?.toString();
    final String? kakaoBirthYear = account.kakaoAccount?.birthyear;
    final String? kakaoAvatarUrl = account.kakaoAccount?.profile?.thumbnailImageUrl;
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

      // ✅ Firestore 저장 후 페이지 이동
      if (context.mounted) {
        navigateToHome(context);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/home');
        });
      } else {
        print("⚠️ context.mounted == false, 네비게이션 실행 불가");
      }

    } else {
      throw Exception('Firebase Custom Token 생성 실패: ${response.body}');
    }
  } catch (e) {
    print('🚨 카카오 로그인 오류: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인에 실패했습니다.: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
void navigateToHome(BuildContext context) async {
  int retryCount = 0;
  while (!context.mounted && retryCount < 10) {
    print("⏳ context.mounted == false, 100ms 후 재시도... ($retryCount)");
    await Future.delayed(Duration(milliseconds: 100));
    retryCount++;
  }

  if (context.mounted) {
    print("✅ context.mounted == true, 네비게이션 실행");
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    print("🚨 여전히 context.mounted == false, 네비게이션 실행 불가");
  }
}

