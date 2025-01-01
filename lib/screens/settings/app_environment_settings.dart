import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/providers/font_provider.dart';
import 'package:food_for_later_new/providers/theme_provider.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppEnvironmentSettings extends StatefulWidget {
  @override
  _AppEnvironmentSettingsState createState() => _AppEnvironmentSettingsState();
}

class _AppEnvironmentSettingsState extends State<AppEnvironmentSettings> {
  // 드롭다운 선택을 위한 변수
  CustomThemeMode _tempTheme = CustomThemeMode.light; // 임시 테마 값
  // final List<String> _categories_them = ['Light', 'Dark']; // 카테고리 리스트
  String _selectedCategory_font = 'NanumGothic'; // 기본 선택값
  List<String> _categories_font = [];

  @override
  void initState() {
    super.initState();
    _loadSelectedEnvironmentSettingValue();
    _loadFonts();
  }

  void _loadFonts() async {
    final fontProvider = FontProvider();
    await fontProvider.loadFonts();
    setState(() {
      _categories_font = fontProvider.fonts.toSet().toList(); // 중복 제거
      // _selectedCategory_font가 _categories_font에 없는 경우 초기화
      if (!_categories_font.contains(_selectedCategory_font)) {
        _selectedCategory_font =
            _categories_font.isNotEmpty ? _categories_font.first : 'Arial';
      }
    });
  }

  void _loadSelectedEnvironmentSettingValue() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      _tempTheme = CustomThemeMode.values.firstWhere(
          (mode) =>
              mode.toString().split('.').last == prefs.getString('themeMode'),
          orElse: () => CustomThemeMode.light);
      _selectedCategory_font = prefs.getString('fontType') ?? 'NanumGothic';
    });
  }

  void _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _tempTheme.toString().split('.').last);
    await prefs.setString('fontType', _selectedCategory_font); // 저장할 때만 테마를 변경
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setThemeMode(_tempTheme);
    themeProvider.setFontType(_selectedCategory_font);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('어플 환경 설정'),
      ),
      body: ListView(
        children: [
          // 드롭다운 카테고리 선택
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '테마',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
              Expanded(
                child: DropdownButton<CustomThemeMode>(
                  value: _tempTheme,
                  isExpanded: true, // 드롭다운이 화면 너비에 맞게 확장되도록 설정
                  // value: Provider.of<ThemeProvider>(context, listen: false).themeMode == ThemeMode.light ? 'Light' : 'Dark',
                  items: CustomThemeMode.values.map((mode) {
                    return DropdownMenuItem<CustomThemeMode>(
                      value: mode,
                      child: Text(mode.toString().split('.').last,
                          style: TextStyle(color: theme.colorScheme.onSurface)),
                    );
                  }).toList(),
                  onChanged: (CustomThemeMode? newValue) {
                    setState(() {
                      _tempTheme = newValue!;
                    });
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '폰트',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCategory_font,
                  isExpanded: true, // 드롭다운이 화면 너비에 맞게 확장되도록 설정
                  items: _categories_font.map((String font) {
                    return DropdownMenuItem<String>(
                      value: font,
                      child: Text(font,
                          style: TextStyle(
                              fontFamily: font,
                              color: theme.colorScheme.onSurface)),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory_font = newValue!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: NavbarButton(
          buttonTitle: '저장',
          onPressed: _saveSettings,
        ),
      ),
    );
  }
}
