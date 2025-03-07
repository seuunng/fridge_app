// 이 파일은 네이버 로그인을 지원하지 않는 플랫폼에서 사용됩니다.

class FlutterNaverLogin {
  static Future<NaverLoginResult> logIn() async {
    throw UnsupportedError('네이버 로그인은 Android에서만 지원됩니다.');
  }

  static Future<void> logOut() async {
    throw UnsupportedError('네이버 로그아웃은 Android에서만 지원됩니다.');
  }

  static Future<void> initSdk({required String clientId, required String clientSecret, required String clientName}) async {
    throw UnsupportedError('네이버 로그인 SDK 초기화는 Android에서만 지원됩니다.');
  }

  // ✅ Future가 아니라 NaverAccessToken을 바로 반환하는 메서드를 추가
  static Future<NaverAccessToken> get currentAccessToken async {
    return NaverAccessToken(accessToken: 'dummy_token');
  }

// ✅ 원래 비동기 메서드도 유지
// static Future<NaverAccessToken> currentAccessToken() async {
//   return Future.value(currentAccessTokenSync);
// }
}

// 🔹 네이버 API의 리턴 타입을 가짜 클래스로 정의하여 컴파일 에러 방지
class NaverLoginResult {
  final NaverLoginStatus status;
  final NaverAccountResult account;
  final String errorMessage;

  NaverLoginResult({
    required this.status,
    required this.account,
    this.errorMessage = '',
  });
}

class NaverAccessToken {
  final String accessToken;

  NaverAccessToken({required this.accessToken});
}

class NaverAccountResult {
  final String nickname;
  final String email;
  final String? gender;
  final String? birthyear;
  final String? profileImage;

  NaverAccountResult({
    required this.nickname,
    required this.email,
    this.gender,
    this.birthyear,
    this.profileImage,
  });
}

// 🔹 네이버 로그인 상태 enum
enum NaverLoginStatus { loggedIn, loggedOut, error }
