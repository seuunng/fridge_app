import 'package:flutter/material.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontProvider {
  static const String _fontsKey = 'availableFonts';

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

  Future<void> loadFonts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedFonts = prefs.getStringList(_fontsKey);
    if (savedFonts != null && savedFonts.isNotEmpty) {
      _fonts = savedFonts;
    }
  }

  Future<void> saveFonts(List<String> fonts) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_fontsKey, fonts);
  }

  List<String> get fonts => _fonts;

  Future<void> addFont(String font) async {
    _fonts.add(font);
    await saveFonts(_fonts);
  }
}
