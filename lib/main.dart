import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:food_for_later_new/providers/role_provider.dart';
import 'package:food_for_later_new/screens/auth/purchase_page.dart';
import 'package:food_for_later_new/services/firebase_options.dart';
import 'package:food_for_later_new/providers/theme_provider.dart';
import 'package:food_for_later_new/screens/auth/login_main_page.dart';
import 'package:food_for_later_new/screens/auth/splash_screen.dart';
import 'package:food_for_later_new/screens/fridge/fridge_main_page.dart';
import 'package:food_for_later_new/screens/home_screen.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:food_for_later_new/services/in_app_purchase_service.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

//Flutter 앱의 진입점
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    MobileAds.instance.initialize();
  } else {
    print("웹에서는 Google Ads가 지원되지 않습니다.");
  }

  try {
    await dotenv.load(fileName: "assets/env/.env");
  } catch (e) {
    print("Failed to load .env file: $e");
  }

  KakaoSdk.init(
    nativeAppKey: 'cae77ccb2159f26f7234f6ccf269605e',
    javaScriptAppKey: '2b8be514fc6d4ca0c50beb374b34b60c',
  );

  if (!kIsWeb) {
    FlutterNaverLogin.initSdk(
      clientId: dotenv.env['NAVER_CLIENT_ID'] ?? '',
      clientSecret: dotenv.env['NAVER_CLIENT_SECRET'] ?? '',
      clientName: dotenv.env['NAVER_CLIENT_NAME'] ?? 'food_for_later',
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print("Error during Firebase initialization: $e");
  }
  // await recordSessionStart();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String initialFont = prefs.getString('fontType') ?? 'NanumGothic';
  String themeModeStr = prefs.getString('themeMode') ?? 'light';
  CustomThemeMode initialThemeMode = CustomThemeMode.values.firstWhere(
    (mode) => mode.toString().split('.').last == themeModeStr,
    orElse: () => CustomThemeMode.light,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialThemeMode, initialFont),
        ),
        ChangeNotifierProvider(
          create: (_) => RoleProvider()..fetchUserRole(), // 🔹 RoleProvider 추가
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final InAppPurchaseService? _iapService;
  late Stream<List<PurchaseDetails>>? _purchaseUpdates;


  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _iapService = InAppPurchaseService();
      _purchaseUpdates = InAppPurchase.instance.purchaseStream;
      _iapService?.listenToPurchaseUpdates(_purchaseUpdates!);
    } else {
      _iapService = null;
      _purchaseUpdates = null;
      print("웹에서는 In-App Purchase가 지원되지 않습니다.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return MaterialApp(
        title: '이따뭐먹지',
        theme: themeProvider.themeData,
        home: SplashScreen(), // 스플래시 화면 시작
        onGenerateRoute: (settings) {
          final Uri uri = Uri.parse(settings.name ?? '');
          // final Uri uri = Uri.base;
          print('Navigated URI: ${uri.toString()}');

          if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'recipe') {
            final recipeId =
                uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
            return MaterialPageRoute(
              builder: (context) =>
                  ReadRecipe(recipeId: recipeId, searchKeywords: []),
            );
          }

          switch (settings.name) {
            case '/home':
              return MaterialPageRoute(builder: (context) => HomeScreen());
            case '/purchase': // 구매 페이지 추가
              return MaterialPageRoute(builder: (context) => PurchasePage());
            case '/login':
              return MaterialPageRoute(builder: (context) => LoginPage());
            default:
              return MaterialPageRoute(builder: (context) => LoginPage());
          }
        },
        navigatorObservers: [
          DeleteModeObserver(onPageChange: () {}),
          routeObserver, // 기존 routeObserver도 유지
        ],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en', ''), // English
          Locale('ko', ''), // Korean
        ],
      );
    });
  }
}

class AuthStateWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // URI를 가져와서 외부 링크로 접근했는지 확인
        final Uri uri = Uri.base;
        if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'recipe') {
          final recipeId =
              uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
          return ReadRecipe(
              recipeId: recipeId, searchKeywords: []); // 특정 레시피 페이지로 이동
        }

        // 인증 상태에 따라 기본 라우팅 처리
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          return HomeScreen(); // 로그인된 사용자를 위한 홈 페이지
        } else {
          return LoginPage(); // 로그인 페이지로 이동
        }
      },
    );
  }
}
