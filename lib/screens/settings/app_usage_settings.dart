import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/fridge_category_model.dart';
import 'package:food_for_later_new/providers/font_provider.dart';
import 'package:food_for_later_new/providers/theme_provider.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/components/custom_dropdown.dart';
import 'package:food_for_later_new/services/default_fridge_service.dart';
import 'package:food_for_later_new/themes/custom_theme_mode.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUsageSettings extends StatefulWidget {
  @override
  _AppUsageSettingsState createState() => _AppUsageSettingsState();
}

class _AppUsageSettingsState extends State<AppUsageSettings> {
  // String _selectedCategory_fridge = '기본 냉장고'; // 기본 선택값
  List<String> _categories_fridge = []; // 카테고리 리스트
  String _fridge_category = '';
  String _selectedCategory_foods = '입고일 기준'; // 기본 선택값
  final List<String> _categories_foods = ['소비기한 기준', '입고일 기준']; // 카테고리 리스트
  String _selectedCategory_records = '달력형'; // 기본 선택값
  final List<String> _categories_records = ['앨범형', '달력형', '목록형']; // 카테고리 리스트
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String userRole = '';
  // 드롭다운 선택을 위한 변수
  CustomThemeMode _tempTheme = CustomThemeMode.light; // 임시 테마 값
  // final List<String> _categories_them = ['Light', 'Dark']; // 카테고리 리스트
  String _selectedCategory_font = 'NanumGothic'; // 기본 선택값
  List<String> _categories_font = [];
  List<FridgeCategory> fridgeCategories = []; // 섹션 리스트
  FridgeCategory? selectedFridgeCategory; // 선택된 섹션
  bool hasCustomSection = false;
  List<FridgeCategory> recentlyDeletedSections = [];
  List<FridgeCategory> defaultFridgeCategories = [];
  List<FridgeCategory> userCategories = [];
  List<Map<String, dynamic>> recentlyDeletedFoods = [];
  bool isEditing = false;


  @override
  void initState() {
    super.initState();
    _loadFridgeNameFromFirestore(); // 초기화 시 Firestore에서 데이터를 불러옴
    _loadSelectedFridge();
    _loadUserRole();
    _loadSelectedEnvironmentSettingValue();
    _loadFonts();
    _loadFridgeCategoriesFromFirestore();
  }
  void _loadUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? 'user'; // 기본값은 'user'
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }
  void _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      // _selectedCategory_fridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
      _selectedCategory_records =
          prefs.getString('selectedRecordListType') ?? '달력형';
      _selectedCategory_foods =
          prefs.getString('selectedFoodStatusManagement') ?? '소비기한 기준';
    });
  }

  // Firestore에서 냉장고 목록 불러오기
  void _loadFridgeNameFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          .get();
      List<String> fridgeList =
          snapshot.docs.map((doc) => doc['FridgeName'] as String).toList();

      if (fridgeList.isEmpty) {
        await DefaultFridgeService().createDefaultFridge(userId);

      }

      setState(() {
        _categories_fridge = fridgeList; // 불러온 냉장고 목록을 상태에 저장
        // _selectedCategory_fridge = _categories_fridge.isNotEmpty ? _categories_fridge.first : '기본 냉장고';
      });
    } catch (e) {
      print('Error loading fridge categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 목록을 불러오는 데 실패했습니다.')),
      );
    }
  }
  Future<void> _loadFridgeCategoriesFromFirestore() async {
    try {
      // 기본 섹션 불러오기
      final defaultSnapshot = await FirebaseFirestore.instance
          .collection('default_fridge_categories')
          .get();
      defaultFridgeCategories = defaultSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      // 사용자 맞춤 섹션 불러오기
      final userSnapshot = await FirebaseFirestore.instance
          .collection('fridge_categories')
          .where('userId', isEqualTo: userId)
          .get();
      userCategories = userSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      setState(() {
        hasCustomSection = userCategories.isNotEmpty;
        fridgeCategories = [...defaultFridgeCategories, ...userCategories]; // 합쳐서 저장
      });

      selectedFridgeCategory = fridgeCategories.isNotEmpty
          ? fridgeCategories.first
          : FridgeCategory(
        id: 'unknown',
        categoryName: '',
      );
    } catch (e) {
      print('Error loading fridge categories: $e');
    }
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
  Future<void> _addNewFridgeToFirestore(String newFridgeName) async {
    final fridgeRef = FirebaseFirestore.instance.collection('fridges');
    try {
      await fridgeRef.add({
        'FridgeName': newFridgeName,
        'userId': userId,
      });
    } catch (e) {
      print('냉장고 추가 중 오류가 발생했습니다: $e');
    }
  }

  // 새로운 카테고리 추가 함수
  void _addNewCategory(List<String> categories, String categoryType) {
    final theme = Theme.of(context);
    if (userRole != 'admin' && userRole != 'paid_user') {
      // 🔹 일반 사용자는 냉장고 추가 불가능
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프리미엄 서비스를 이용하면 냉장고를 여러 개 등록하고 스마트한 식재료 관리를 할 수 있어요!')),
      );
      return;
    }
    if (categories.length >= 3) {
      // 카테고리 개수가 3개 이상이면 추가 불가
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryType은(는) 최대 3개까지만 추가할 수 있습니다.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newCategory = '';
        return AlertDialog(
          title: Text('$categoryType 추가',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),
          ),
          content: TextField(
            onChanged: (value) {
              newCategory = value;
            },
            decoration: InputDecoration(hintText: '새로운 냉장고 이름 입력'),
            style:
            TextStyle(color: theme.chipTheme.labelStyle!.color),
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('추가'),
              onPressed: () async {
                if (newCategory.isNotEmpty) {
                  await _addNewFridgeToFirestore(newCategory);
                  setState(() {
                    categories.add(newCategory);
                    // 추가 후 선택된 카테고리 업데이트
                    // if (categoryType == '냉장고') {
                    //   _selectedCategory_fridge = newCategory;
                    // }
                  });
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _saveNewSectionToFirestore(String sectionName) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('fridge_categories').doc();
      await docRef.set({
        'id': docRef.id,
        'categoryName': sectionName,
        'userId': userId,
      });

      await _loadFridgeCategoriesFromFirestore();
      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving new fridge section: $e');
    }
  }

  Future<void> _deleteFridgeSection(String sectionId) async {
      try {
        // 섹션에 포함된 냉장고 아이템들을 가져옴
        QuerySnapshot itemSnapshot = await FirebaseFirestore.instance
            .collection('fridge_items')
            .where('userId', isEqualTo: userId)
            .where('fridgeCategoryId', isEqualTo: sectionId)
            .get();
        final sectionToDelete = userCategories.firstWhere((section) => section.id == sectionId);
        // 각 아이템 삭제
        for (var doc in itemSnapshot.docs) {
          await doc.reference.delete();
        }

        // 섹션 삭제
        await FirebaseFirestore.instance
            .collection('fridge_categories')
            .doc(sectionId)
            .delete();

        setState(() {
          recentlyDeletedSections.add(sectionToDelete);
          userCategories.removeWhere((category) => category.id == sectionId);
        });

        // 삭제 성공 후 UI 갱신
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('섹션과 포함된 아이템이 모두 삭제되었습니다.'),
            action: SnackBarAction(
              label: '복원',
              onPressed: _restoreDeletedSection, // 복원 함수 호출
            ),),
        );

        await _loadFridgeCategoriesFromFirestore(); // UI 업데이트
        Navigator.pop(context, true);
      } catch (e) {
        // 삭제 실패 시 오류 메시지 출력
        print('섹션 또는 아이템 삭제 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('섹션 또는 아이템 삭제에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  void _restoreDeletedSection() async {
    if (recentlyDeletedSections.isNotEmpty) {
      final sectionToRestore = recentlyDeletedSections.removeLast();

      try {
        // Firestore에 섹션 복원
        await FirebaseFirestore.instance
            .collection('fridge_categories')
            .doc(sectionToRestore.id)
            .set({
          'id': sectionToRestore.id,
          'categoryName': sectionToRestore.categoryName,
          'userId': userId,
        });

        setState(() {
          userCategories.add(sectionToRestore); // 로컬 상태에 섹션 복원
        });
        await _loadFridgeCategoriesFromFirestore();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sectionToRestore.categoryName} 섹션이 복원되었습니다.')),
        );
      } catch (e) {
        print('섹션 복원 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('섹션 복원에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }
  Future<void> _deleteUserFoods() async {
    try {
      QuerySnapshot userFoodsSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      recentlyDeletedFoods.clear(); // 삭제할 때마다 초기화

      for (var doc in userFoodsSnapshot.docs) {
        // 삭제 전 데이터를 저장
        recentlyDeletedFoods.add(doc.data() as Map<String, dynamic>);
        await doc.reference.delete(); // 각 문서 삭제
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모든 식품 세부정보가 초기화되었습니다.'),
          action: SnackBarAction(
            label: '복원',
            onPressed: _restoreDeletedFoods, // 복원 버튼 클릭 시 호출
          ),
        ),
      );
    } catch (e) {
      print('Error deleting user foods: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식품 초기화에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }
  Future<void> _restoreDeletedFoods() async {
    try {
      for (var foodData in recentlyDeletedFoods) {
        await FirebaseFirestore.instance.collection('foods').add(foodData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제된 식품 정보가 복원되었습니다.')),
      );

      // 복원 후 임시 저장 리스트 초기화
      recentlyDeletedFoods.clear();
    } catch (e) {
      print('Error restoring foods: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('식품 복원에 실패했습니다.')),
      );
    }
  }
  // 선택된 냉장고 삭제 함수
  // void _deleteCategory(
  //     String category, List<String> categories, String categoryType) {
  //   if (categories.length <= 1) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('최소 한 개의 냉장고는 필요합니다.')),
  //     );
  //     return;
  //   }
  //   final fridgeRef = FirebaseFirestore.instance.collection('fridges');
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('냉장고 삭제',
  //           style: TextStyle(
  //             color: Theme.of(context).brightness == Brightness.dark
  //                 ? Colors.white
  //                 : Colors.black,
  //           ),
  //         ),
  //         content: Text('$category를 삭제하시겠습니까?',
  //           style: TextStyle(
  //             color: Theme.of(context).brightness == Brightness.dark
  //                 ? Colors.white
  //                 : Colors.black,
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('취소'),
  //             onPressed: () {
  //               Navigator.pop(context);
  //             },
  //           ),
  //           TextButton(
  //               child: Text('삭제'),
  //               onPressed: () async {
  //                 try {
  //                   if (_categories_fridge.length <= 1) {
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(content: Text('최소 한 개의 냉장고는 필요합니다.')),
  //                     );
  //                     Navigator.pop(context);
  //                     return;
  //                   }
  //                   // 해당 냉장고 이름과 일치하는 문서를 찾음
  //                   final snapshot = await fridgeRef
  //                       .where('FridgeName', isEqualTo: category)
  //                       .where('userId', isEqualTo: userId)
  //                       .get();
  //
  //                   for (var doc in snapshot.docs) {
  //                     // Firestore에서 문서 삭제
  //                     await fridgeRef.doc(doc.id).delete();
  //                   }
  //
  //                   // UI 업데이트
  //                   setState(() {
  //                     _categories_fridge.remove(category);
  //                     if (_categories_fridge.isNotEmpty) {
  //                       // _selectedCategory_fridge = _categories_fridge.first;
  //                     } else {
  //                       DefaultFridgeService().createDefaultFridge(userId);
  //                     }
  //                   });
  //
  //                   Navigator.pop(context);
  //                 } catch (e) {
  //                   print('Error deleting fridge: $e');
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     SnackBar(content: Text('냉장고를 삭제하는 중 오류가 발생했습니다.')),
  //                   );
  //                   Navigator.pop(context);
  //                 }
  //                 ;
  //               }),
  //         ],
  //       );
  //     },
  //   );
  // }

  void _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user?.email == 'guest@foodforlater.com') {
      // 🔹 게스트 계정이면 설정 저장 불가 & 로그인 요청 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후 설정을 저장할 수 있습니다.')),
      );
      return; // 🚫 여기서 함수 종료 (저장 X)
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('selectedRecordListType', _selectedCategory_records);
    await prefs.setString(
        'selectedFoodStatusManagement', _selectedCategory_foods);
    await prefs.setString('themeMode', _tempTheme.toString().split('.').last);
    await prefs.setString('fontType', _selectedCategory_font); // 저장할 때만 테마를 변경
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setThemeMode(_tempTheme);
    themeProvider.setFontType(_selectedCategory_font);
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true); // true를 반환하여 변경 사항이 있음을 알림
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('어플 사용 설정'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row(
              //   children: [
              //     Text(
              //       '냉장고 선택',
              //       style: TextStyle(
              //           fontSize: 18,
              //           fontWeight: FontWeight.bold,
              //           color: theme.colorScheme.onSurface),
              //     ),
              // Spacer(),
              // CustomDropdown(
              //   title: '냉장고 선택',
              //   items: _categories_fridge,
              //   selectedItem:
              //       _categories_fridge.contains(_selectedCategory_fridge)
              //           ? _selectedCategory_fridge
              //           : '기본 냉장고', // 리스트에 없으면 기본값 설정
              //   onItemChanged: (value) {
              //     setState(() {
              //       _selectedCategory_fridge = value;
              //     });
              //   },
              //   onItemDeleted: (item) {
              //     _deleteCategory(item, _categories_fridge, '냉장고');
              //   },
              //   onAddNewItem: () {
              //     _addNewCategory(_categories_fridge, '냉장고');
              //   },
              // ),
              //   ],
              // ),
              // Text('가장 자주 보는 냉장고를 기본냉장고로 설정하세요',
              //     style: TextStyle(color: theme.colorScheme.onSurface)),
              // SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '냉장고 섹션 관리',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  BasicElevatedButton(
                    onPressed: _addNewFridgeSection,
                    iconTitle: Icons.edit,
                    buttonTitle: '수정',
                  ),
                ],
              ),
              Text('또 다른 섹션이 필요하다면 추가하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '식품 상태관리 선택',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory_foods,
                    // _categories_foods.contains(_selectedCategory_foods)
                    //     ? _selectedCategory_foods
                    //     : null,
                    items: _categories_foods.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedCategory_foods = value!;
                      });
                    },
                  ),
                ],
              ),
              Text('식품 관리 기준을 선택하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              Text('빨리 소진해야할 식품을 알려드려요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '제외 키워드 카테고리 수정',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  BasicElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddItem(
                            pageTitle: '제외 키워드 카테고리에 추가',
                            addButton: '카테고리에 추가',
                            sourcePage: 'preferred_foods_category',
                            onItemAdded: () {
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                    iconTitle: Icons.edit,
                    buttonTitle: '수정',
                  ),
                ],
              ),
              Text('자주 검색하는 식품을 그룹으로 관리해요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '대표 기록유형 선택',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory_records,
                    items: _categories_records.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (String? value) async {
                      if (value != null) {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString(
                            'selectedCategory_records', value); // 값 저장
                        setState(() {
                          _selectedCategory_records = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              Text('가장 자주 보는 기록유형을 대표 유형으로 설정하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
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
                          child: Text(
                              themeModeNames[mode] ?? mode.toString(),
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
              SizedBox(height: 20),
              Row(
                children: [
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
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '식품 정보 초기화',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(), // 텍스트와 드롭다운 사이 간격
                  BasicElevatedButton(
                    onPressed: _showResetConfirmationDialog,
                    iconTitle: Icons.refresh,
                    buttonTitle: '초기화',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
        children: [
          Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: NavbarButton(
                buttonTitle: '저장',
                onPressed: _saveSettings,
              ),
            ),
          ),
          if (userRole != 'admin' && userRole != 'paid_user')
            SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            ),
        ],
      ),
    );
  }
  void _addNewFridgeSection() {
    final theme = Theme.of(context);
    TextEditingController editingController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newSectionName = '';
        bool isEditing = false; // 로컬 변수로 편집 상태 관리
        return StatefulBuilder(
            builder: (context, setState) {
            return AlertDialog(
              title: Text('냉장고 섹션 관리',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: theme.colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '기본 섹션',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  Divider(color: Colors.grey.shade300, thickness: 1, height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(FontAwesomeIcons.carrot, color: Colors.grey, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '냉장',
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                                ),
                              ),
                              Icon(FontAwesomeIcons.wineBottle, color: Colors.grey, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '상온',
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                                ),
                              ),
                              Icon(FontAwesomeIcons.snowflake, color: Colors.grey, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '냉동',
                                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                  ),
                  SizedBox(height: 20),
                  // 커스텀 섹션 리스트 (수정/삭제 가능)
                  if (userCategories.isNotEmpty) ...[
                    Text(
                      '커스텀 섹션',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    Divider(color: Colors.grey.shade300, thickness: 1, height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(FontAwesomeIcons.user, color: Colors.blueAccent, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onDoubleTap: () {
                                setState(() {
                                  isEditing = true; // 더블클릭 시 편집 모드 활성화
                                  editingController.text = userCategories[0].categoryName; // 현재 카테고리 이름 설정
                                });
                              },
                              child: isEditing
                                  ? TextField(
                                controller: editingController,
                                decoration: InputDecoration(
                                  hintText: '섹션 이름 수정',
                                  border: OutlineInputBorder(),
                                ),
                                style:
                                TextStyle(color: theme.chipTheme.labelStyle!.color),
                                onSubmitted: (newValue) async {
                                  if (newValue.isNotEmpty && newValue != userCategories[0].categoryName) {
                                    await FirebaseFirestore.instance
                                        .collection('fridge_categories')
                                        .doc(userCategories[0].id)
                                        .update({'categoryName': newValue});
                                    final fridgeSnapshot = await FirebaseFirestore.instance
                                        .collection('fridge_items')
                                        .where('userId', isEqualTo: userId)
                                        .where('fridgeCategoryId', isEqualTo: userCategories[0].categoryName.trim())
                                        .get();
                                    for (var doc in fridgeSnapshot.docs) {
                                      await doc.reference.update({'fridgeCategoryId': newValue});
                                    }
                                    // 2. 로컬 데이터 즉시 업데이트
                                    setState(() {
                                      userCategories[0] = FridgeCategory(
                                        id: userCategories[0].id,
                                        categoryName: newValue,
                                      );
                                      isEditing = false; // 입력 후 편집 모드 해제
                                    });
                                  } else {
                                    setState(() {
                                      isEditing = false; // 입력 후 편집 모드 해제
                                    });
                                  }
                                  // 3. (선택 사항) Firestore에서 다시 로드하여 최신 데이터로 유지
                                  await _loadFridgeCategoriesFromFirestore();
                                },
                              )
                                  : Text(
                                userCategories[0].categoryName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: theme.chipTheme.labelStyle!.color),
                            onPressed: () async {
                              final fridgeSnapshot = await FirebaseFirestore.instance
                                  .collection('fridge_items')
                                  .where('userId', isEqualTo: userId)
                                  .where('fridgeCategoryId', isEqualTo: userCategories[0].categoryName.trim())
                                  .get();

                              // 아이템이 있는지 여부를 확인
                              final bool hasItems = fridgeSnapshot.docs.isNotEmpty;
                              print('hasItems $hasItems');
                              final String message = hasItems
                                  ? '정말로 섹션과 포함된 재료를\n모두 삭제하시겠습니까?'
                                  : '정말로 이 섹션을 삭제하시겠습니까?';

                              bool confirmDelete = await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    title: Text('섹션 삭제', style: TextStyle(color: theme.colorScheme.onSurface)),
                                    content: Text(message, style: TextStyle(color: theme.colorScheme.onSurface)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: Text('취소', style: TextStyle(color: theme.colorScheme.onSurface)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: Text('삭제', style: TextStyle(color: theme.colorScheme.onSurface)),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmDelete) {
                                // 아이템이 있으면 해당 아이템도 삭제
                                if (hasItems) {
                                  for (var doc in fridgeSnapshot.docs) {
                                    await doc.reference.delete(); // 각 아이템 삭제
                                  }
                                }

                                await _deleteFridgeSection(userCategories[0].id);
                                // 다이얼로그 내부 UI 갱신
                                setState(() {
                                  userCategories.removeAt(0); // 삭제된 섹션 제거
                                });
                                await _loadFridgeCategoriesFromFirestore();
                              }
                            },
                            tooltip: '삭제',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 새 섹션 추가 입력 필드
                  if (!hasCustomSection)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        onChanged: (value) => newSectionName = value,
                        decoration: InputDecoration(
                          hintText: '커스텀 섹션 이름 입력',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style:
                        TextStyle(color: theme.chipTheme.labelStyle!.color),
                      ),
                    ),
                ],
              ),
              actions: [
                // TextButton(
                //   onPressed: () {
                //     setState(() {
                //       isEditing = false; // 취소 시 편집 모드 해제
                //     });
                //     Navigator.pop(context);
                //   },
                //   child: Text('취소', style: TextStyle(color: theme.chipTheme.labelStyle!.color)),
                // ),
                if (!hasCustomSection)
                  TextButton(
                    onPressed: () async {
                      if (newSectionName.isNotEmpty) {
                        await _saveNewSectionToFirestore(newSectionName);
                        Navigator.pop(context);
                        await _loadFridgeCategoriesFromFirestore();
                      }
                    },
                    child: Text('추가', style: TextStyle(color: theme.chipTheme.labelStyle!.color)),
                  ),
              ],
            );
          }
        );
      },
    );
  }
  void _showResetConfirmationDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('식품 정보 초기화',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: Text(
            '수정한 식품 세부정보를 모두 삭제하시겠습니까?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기
              },
              child: Text('취소', style: TextStyle(color: theme.colorScheme.onSurface)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // 팝업 닫기 후 삭제 실행
                await _deleteUserFoods(); // 삭제 함수 호출
              },
              child: Text('확인', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

}
