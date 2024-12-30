import 'package:flutter/material.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider {
  static const String _fontsKey = 'availableFonts';

  // 초기 기본 폰트 리스트
  List<String> _fonts = [
    '나눔바른펜',
    '나눔손글씨',
    '나눔스퀘어',
    '이서윤',
    '배찌',
    '칠판지우개',
    '오이샐러드',
    '동동',
    '그림일기',
    '고운바탕',
    '수박양',
    '말랑말랑',
    '마루부리',
    '고운밤',
    '빛나는별',
    '심플해',
    '쑥쑥',
    '숑숑',
    '타닥타닥',
    '김콩해',
  ];

  // 저장된 폰트 목록 불러오기
  Future<void> loadFonts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedFonts = prefs.getStringList(_fontsKey);
    if (savedFonts != null && savedFonts.isNotEmpty) {
      _fonts = savedFonts;
    }
  }

  // 폰트 목록 저장하기
  Future<void> saveFonts(List<String> fonts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_fontsKey, fonts);
  }

  // 현재 폰트 목록 가져오기
  List<String> get fonts => _fonts;

  // 폰트 추가하기
  Future<void> addFont(String font) async {
    _fonts.add(font);
    await saveFonts(_fonts);
  }
}
// CustomThemeMode _themeMode = CustomThemeMode.light; // 기본 테마
// String _fontType;
// ThemeData _themeData = ThemeData.light();
//
// CustomThemeMode get themeMode => _themeMode;
// String get fontType => _fontType;
// ThemeData get themeData => _themeData;
//
// ThemeProvider(this._fontType) {
//   _loadThemeMode();
//   _updateTheme();
// }


// void _loadThemeMode() async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   String themeModeString = prefs.getString('themeMode') ?? 'light';
//   _themeMode = CustomThemeMode.values.firstWhere(
//     (e) => e.toString().split('.').last == themeModeString,
//     orElse: () => CustomThemeMode.light,
//   );
//   _fontType = prefs.getString('fontType') ?? 'NanumGothic';
//   notifyListeners();
// }

// void setFontType(String font) async{
//   _fontType = font;
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   await prefs.setString('fontType', font);
//   _updateTheme();
//   notifyListeners();
// }
//
// void _updateTheme() {
//   _themeData = currentTheme.copyWith(
//     textTheme: currentTheme.textTheme.apply(
//       fontFamily: _fontType, // 선택한 폰트 적용
//     ),
//     appBarTheme: currentTheme.appBarTheme.copyWith(
//       titleTextStyle: TextStyle(
//         fontFamily: _fontType,
//         fontSize: 25, // 필요 시 폰트 크기 조정
//         color: currentTheme.appBarTheme.titleTextStyle?.color,
//       ),
//     ),
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         textStyle: TextStyle(
//           fontFamily: _fontType,
//           fontSize: 16, // 필요 시 폰트 크기 조정
//         ),
//       ),
//     ),
//   );
//   notifyListeners();
// }

