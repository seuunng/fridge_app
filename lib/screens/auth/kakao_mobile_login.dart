import 'dart:convert';
import 'dart:math';
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

        await fetchKakaoUserInfo();

    final account = await kakao.UserApi.instance.me();

    final kakaoEmail = account.kakaoAccount?.email;
        final String? kakaoGender =  account.kakaoAccount?.gender?.toString();
        final String? kakaoBirthYear =  account.kakaoAccount?.birthyear;
        final String? kakaoAvatarUrl = account.kakaoAccount?.profile?.thumbnailImageUrl;

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
      int randomAvatarIndex = Random().nextInt(25) + 1; // 1~25 사이 랜덤 숫자

      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'nickname': kakaoNickname,
          'email': kakaoEmail,
          'gender': kakaoGender ?? '알 수 없음',
          'birthYear': kakaoBirthYear ?? '알 수 없음',
          'signupdate': DateTime.now().toIso8601String(),
          'avatar': kakaoAvatarUrl ?? 'assets/avatar/avatar-${randomAvatarIndex.toString().padLeft(2, '0')}.png', // 기본값 설정
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

Future<void> fetchKakaoUserInfo() async {
  try {
    final kakao.User kakaoUser = await kakao.UserApi.instance.me();
    final String? nickname = kakaoUser.kakaoAccount?.profile?.nickname;
    final String? email = kakaoUser.kakaoAccount?.email;
    final String? gender = kakaoUser.kakaoAccount?.gender?.toString();
    final String? birthYear = kakaoUser.kakaoAccount?.birthyear;
  } catch (e) {
    print('카카오 사용자 정보 가져오기 오류: $e');
  }
}