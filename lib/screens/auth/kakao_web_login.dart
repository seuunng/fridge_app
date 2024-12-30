// import 'dart:html' as html;

void signInWithKakao() {
  const kakaoAppKey = 'cae77ccb2159f26f7234f6ccf269605e'; // 카카오 앱 키
  const redirectUri = 'https://food-for-later.web.app/oauth'; // Redirect URI

  final url = Uri.https(
    'kauth.kakao.com',
    '/oauth/authorize',
    {
      'client_id': kakaoAppKey,
      'redirect_uri': redirectUri,
      'response_type': 'code',
    },
  );

  print('Redirecting to Kakao Login: $url');
}