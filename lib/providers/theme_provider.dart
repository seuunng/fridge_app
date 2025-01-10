import 'package:flutter/material.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  CustomThemeMode _themeMode;
  String _fontType;
  ThemeData _themeData = ThemeData.light();

  ThemeProvider(this._themeMode, this._fontType) {
    _updateTheme();
  }

  CustomThemeMode get themeMode => _themeMode;
  String get fontType => _fontType;
  ThemeData get themeData => _themeData;

  void _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String themeModeString = prefs.getString('themeMode') ?? 'light';
    _themeMode = CustomThemeMode.values.firstWhere(
      (e) => e.toString().split('.').last == themeModeString,
      orElse: () => CustomThemeMode.light,
    );
    _fontType = prefs.getString('fontType') ?? 'NanumGothic';
    _updateTheme(); // 데이터를 로드한 이후 테마를 업데이트
    notifyListeners();
  }

  Future<void> toggleTheme(CustomThemeMode mode) async {
    _themeMode = mode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'themeMode', mode.toString().split('.').last); // 일관성 있는 저장
    _updateTheme();
    notifyListeners();
  }

  void setThemeMode(CustomThemeMode themeMode) async {
    _themeMode = themeMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', themeMode.toString().split('.').last);
    _updateTheme();
    notifyListeners();
  }

  void setFontType(String font) async {
    _fontType = font;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontType', font);
    _updateTheme();
    notifyListeners();
  }

  void _updateTheme() {
    _themeData = currentTheme.copyWith(
      textTheme: ThemeData.light().textTheme.apply(fontFamily: _fontType),
      appBarTheme: currentTheme.appBarTheme.copyWith(
        titleTextStyle: TextStyle(
          fontFamily: _fontType,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: currentTheme.appBarTheme.titleTextStyle?.color,
          // color: Colors.black, // 적절한 색상 설정
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              currentTheme.elevatedButtonTheme.style?.backgroundColor,
          foregroundColor:
              currentTheme.elevatedButtonTheme.style?.foregroundColor,
          textStyle: MaterialStateProperty.all(
            TextStyle(
              fontFamily: _fontType,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
    notifyListeners();
  }

  final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light, //전체 앱의 테마 밝기 모드를 설정
    primaryColor: Colors.white, //앱의 기본 색상을 설정
    scaffoldBackgroundColor: Colors.white, //Scaffold 위젯의 배경색
    appBarTheme: AppBarTheme(
      //AppBar 위젯의 테마를 설정
      color: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.black),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.white,
      scrimColor: Colors.white, // Drawer 열릴 때 배경을 덮는 색상
    ),
    buttonTheme: ButtonThemeData(
      //버튼의 테마를 설정
      buttonColor: Colors.grey[850],
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, // 버튼의 배경색
        foregroundColor: Colors.black, // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Colors.white, // 기본 색상 설정
      foregroundColor: Colors.black, // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white, // 기본 배경색, 칩&그리드
      labelStyle: TextStyle(color: Colors.black), // 기본 텍스트
      selectedColor: Colors.black, // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Colors.white), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    // cardColor: Colors.grey[800], //Card 위젯의 배경색을 설정
    textTheme: TextTheme(
      //앱의 텍스트 테마
      bodyMedium: TextStyle(color: Colors.black), //캘린더제목/ 장바구니글씨
      titleLarge: TextStyle(color: Colors.black), //드로어 제목
    ),
    colorScheme: ColorScheme.light().copyWith(
        primary: Colors.black, // 하단바 아이콘, 탭버튼 제목
        onPrimary: Colors.white, // 주요 배경위 텍스트나 아이콘색
        primaryContainer: Colors.white, //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Colors.black,
        secondary: Colors.grey[300], // 캘린더 오늘,
        onSecondary: Colors.black, // 캘렌더 컬러박스 글씨
        surface: Colors.grey[300], //카드와 같은 표면 색상, 하단 네브바
        onSurface: Colors.black, //드롭박스, 사이드바
        brightness: Brightness.light),
  );

  final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark, //전체 앱의 테마 밝기 모드를 설정
    primaryColor: Colors.white, //앱의 기본 색상을 설정
    scaffoldBackgroundColor: Colors.grey[900], //Scaffold 위젯의 배경색
    appBarTheme: AppBarTheme(
      //AppBar 위젯의 테마를 설정
      color: Colors.grey[900],
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Colors.grey[850],
      scrimColor: Colors.black54, // Drawer 열릴 때 배경을 덮는 색상
    ),
    buttonTheme: ButtonThemeData(
      //버튼의 테마를 설정
      buttonColor: Colors.grey[850],
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[850], // 버튼의 배경색
        foregroundColor: Colors.white, // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Colors.grey[850], // 기본 색상 설정
      foregroundColor: Colors.white, // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey[850], // 기본 배경색
      labelStyle: TextStyle(color: Colors.white), // 기본 텍스트
      selectedColor: Colors.white, // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Colors.black), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    // cardColor: Colors.grey[800], //Card 위젯의 배경색을 설정
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
    primaryTextTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
    colorScheme: ColorScheme.dark().copyWith(
        primary: Colors.white, // 주요 배경색
        onPrimary: Colors.black, // datePicker 선택된 날짜 폰트
        primaryContainer: Colors.white, //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Colors.white,
        secondary: Colors.grey, // 캘린더 오늘날짜 배경
        onSecondary: Colors.black, // 캘렌더 컬러박스 글씨
        surface: Colors.black, //카드와 같은 표면 색상, 하단 네브바
        onSurface: Colors.white, //드롭박스, 사이드바
        brightness: Brightness.dark),
  );

  final ThemeData blueTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF3F668F),
    scaffoldBackgroundColor: Color(0xCF5E7891),
    appBarTheme: AppBarTheme(
      color: Color(0xFF05264E),
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(0xFF05264E),
      scrimColor: Color(0xCF5E7891), // Drawer 열릴 때 배경을 덮는 색상
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFC3D0D5), // 선택된 아이콘 색상
      unselectedItemColor: Color(0xFF05264E), // 선택되지 않은 아이콘 색상
      backgroundColor: Color(0xFF3F668F), // 네비게이션 바 배경색
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Color(0xFF3F668F),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF3F668F), // 버튼의 배경색
        foregroundColor: Color(0xFFC3D0D5), // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Color(0xFF3F668F), // 기본 색상 설정
      foregroundColor: Color(0xFFC3D0D5), // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFF3F668F), // 기본 배경색
      labelStyle: TextStyle(color: Colors.white), // 기본 텍스트
      selectedColor: Color(0xFF05264E), // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Colors.white), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    // cardColor: Colors.blue[100],
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFC3D0D5)),
      titleLarge: TextStyle(color: Color(0xFFC3D0D5)),
    ),
    colorScheme: ColorScheme.dark().copyWith(
        primary: Color(0xFFC3D0D5), // 주요 배경색
        onPrimary: Color(0xFF05264E), // 주요 배경위 텍스트나 아이콘색
        primaryContainer: Color(0xFF4A7ECA), //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Color(0xFFC3D0D5),
        secondary: Color(0x41C3D0D5), // 캘린더 오늘,
        onSecondary: Color(0xFF05264E), // 캘렌더 컬러박스 글씨
        surface: Color(0xFF3F668F), //카드와 같은 표면 색상, 하단 네브바
        onSurface: Color(0xFFC3D0D5), //드롭박스, 사이드바
        brightness: Brightness.light),
  );

  final ThemeData greenTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Color(0xFF19411C),
    scaffoldBackgroundColor: Color(0xFF28432B),
    appBarTheme: AppBarTheme(
      color: Color(0xFF0D2514),
      iconTheme: IconThemeData(color: Color(0xFFA7AFAB)),
      titleTextStyle: TextStyle(color: Color(0xFFA7AFAB), fontSize: 20),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(0xFF0D2514),
      scrimColor: Color(0x6F19411C), // Drawer 열릴 때 배경을 덮는 색상
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFFA7AFAB), // 선택된 아이콘 색상
      unselectedItemColor: Color(0xFF0D2514), // 선택되지 않은 아이콘 색상
      backgroundColor: Color(0xFF19411C), // 네비게이션 바 배경색
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: Color(0xFF19411C),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF19411C), // 버튼의 배경색
        foregroundColor: Color(0xFFA7AFAB), // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Color(0xFF19411C), // 기본 색상 설정
      foregroundColor: Color(0xFFA7AFAB), // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFF19411C), // 기본 배경색
      labelStyle: TextStyle(color: Color(0xFFA7AFAB)), // 기본 텍스트
      selectedColor: Color(0xFF0D2514), // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Color(0xFFA7AFAB)), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    // cardColor: Colors.blue[100],
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFA7AFAB)),
      titleLarge: TextStyle(color: Color(0xFFA7AFAB)),
    ),
    colorScheme: ColorScheme.dark().copyWith(
        primary: Color(0xFFA7AFAB), // 주요 배경색
        onPrimary: Color(0xFF0D2514), // 주요 배경위 텍스트나 아이콘색
        primaryContainer: Color(0xFF19411C), //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Color(0xFFA7AFAB),
        secondary: Color(0xFFA7AFAB), // 캘린더 오늘,
        onSecondary: Color(0xFF0D2514), // 캘렌더 컬러박스 글씨
        surface: Color(0xFF19411C), //카드와 같은 표면 색상, 하단 네브바
        onSurface: Color(0xFFA7AFAB), //드롭박스, 사이드바
        brightness: Brightness.light),
  );

  final ThemeData brownTheme = ThemeData(
    brightness: Brightness.light, //전체 앱의 테마 밝기 모드를 설정
    primaryColor: Colors.white, //앱의 기본 색상을 설정
    scaffoldBackgroundColor: Colors.white, //Scaffold 위젯의 배경색
    appBarTheme: AppBarTheme(
      //AppBar 위젯의 테마를 설정
      color: Color(0xFFB28659),
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(0xFFB28659),
      scrimColor: Color(0x6CB28659), // Drawer 열릴 때 배경을 덮는 색상
    ),
    buttonTheme: ButtonThemeData(
      //버튼의 테마를 설정
      buttonColor: Colors.grey[850],
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFB28659), // 버튼의 배경색
        foregroundColor: Colors.white, // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Color(0xFFB28659), // 기본 색상 설정
      foregroundColor: Colors.white, // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Color(0xFFE5D8C9), // 기본 배경색, 칩&그리드
      labelStyle: TextStyle(color: Color(0xFFB28659)), // 기본 텍스트
      selectedColor: Color(0xFFB28659), // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Colors.white), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    // cardColor: Colors.grey[800], //Card 위젯의 배경색을 설정
    textTheme: TextTheme(
      //앱의 텍스트 테마
      bodyMedium: TextStyle(color: Color(0xFF2C1803)), //캘린더제목/ 장바구니글씨
      titleLarge: TextStyle(color: Colors.white),
    ),
    colorScheme: ColorScheme.light().copyWith(
        primary: Color(0xFF836441), // 하단바 아이콘, 탭버튼 제목
        onPrimary: Color(0xFF2C1803), // 주요 배경위 텍스트나 아이콘색
        primaryContainer: Colors.white, //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Color(0xFFE5D8C9),
        secondary: Color(0xFFE5D8C9), // 캘린더 오늘,
        onSecondary: Colors.black, // 캘렌더 컬러박스 글씨
        surface: Color(0xFFE5D8C9), //카드와 같은 표면 색상, 하단 네브바
        onSurface: Color(0xFF2C1803), //드롭박스, 사이드바
        brightness: Brightness.light),
  );

  final ThemeData pinkTheme = ThemeData(
    brightness: Brightness.light, //전체 앱의 테마 밝기 모드를 설정
    primaryColor: Color(0xFFE2A69E), //앱의 기본 색상을 설정
    scaffoldBackgroundColor: Colors.white, //Scaffold 위젯의 배경색
    appBarTheme: AppBarTheme(
      //AppBar 위젯의 테마를 설정
      color: Color(0xFFE2A69E),
      iconTheme: IconThemeData(color: Color(0xFF453837)),
      titleTextStyle: TextStyle(color: Color(0xFF453837), fontSize: 20),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: Color(0xFFE2A69E),
      scrimColor: Colors.white, // Drawer 열릴 때 배경을 덮는 색상
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: Colors.white, // 선택된 아이콘 색상
      unselectedItemColor: Color(0xFF453837), // 선택되지 않은 아이콘 색상
      backgroundColor: Color(0xFFE2A69E), // 네비게이션 바 배경색
    ),
    buttonTheme: ButtonThemeData(
      //버튼의 테마를 설정
      buttonColor: Color(0xFFB0958F),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFFE2A69E), // 버튼의 배경색
        foregroundColor: Colors.white, // 버튼의 텍스트 색상
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      //플로팅버튼 스타일
      backgroundColor: Color(0xFFE2A69E), // 기본 색상 설정
      foregroundColor: Colors.white, // 아이콘 색상
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white, // 기본 배경색, 칩&그리드
      labelStyle: TextStyle(color: Color(0xFFB0958F)), // 기본 텍스트
      selectedColor: Color(0xFFE2A69E), // 선택된 칩의 배경색
      secondaryLabelStyle: TextStyle(color: Colors.white), // 선택된 칩 텍스트 색상
      disabledColor: Colors.grey[500],
    ),
    textTheme: TextTheme(
      //앱의 텍스트 테마
      bodyMedium: TextStyle(color: Colors.black), //캘린더제목/ 장바구니글씨
      titleLarge: TextStyle(color: Color(0xFF453837)), //드로어 제목
    ),
    colorScheme: ColorScheme.light().copyWith(
        primary: Color(0xFF453837), // 탭버튼 제목
        onPrimary: Colors.black, // 주요 배경위 텍스트나 아이콘색
        primaryContainer: Colors.white, //primary와 유사한 색상이지만, 더 연한 버전
        onPrimaryContainer: Colors.white,
        secondary: Color(0x83E2A69E), // 캘린더 오늘,
        onSecondary: Colors.black, // 캘렌더 컬러박스 글씨
        surface: Color(0xFFE2A69E), //카드와 같은 표면 색상
        onSurface: Color(0xFF5E4F4C), //드롭박스, 사이드바
        brightness: Brightness.light),
  );

  // 현재 선택된 테마를 반환하는 메서드
  ThemeData get currentTheme {
    switch (_themeMode) {
      case CustomThemeMode.light:
        return lightTheme;
      case CustomThemeMode.dark:
        return darkTheme;
      case CustomThemeMode.blue:
        return blueTheme;
      case CustomThemeMode.green:
        return greenTheme;
      case CustomThemeMode.brown:
        return brownTheme;
      case CustomThemeMode.pink:
        return pinkTheme;
      default:
        return lightTheme;
    }
  }
}

// ThemeData _themeData = ThemeData.light(); // 기본 테마 데이터
//
// ThemeData get themeData => _themeData;
