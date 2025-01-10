import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';
import 'package:food_for_later_new/models/recipe_method_model.dart';
import 'package:food_for_later_new/services/preferred_foods_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecipeSearchSettings extends StatefulWidget {
  @override
  _RecipeSearchSettingsState createState() => _RecipeSearchSettingsState();
}

class _RecipeSearchSettingsState extends State<RecipeSearchSettings> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // List<String> selectedSources = [];
  List<String> selectedCookingMethods = [];
  List<String> selectedPreferredFoodCategories = [];

  TextEditingController excludeKeywordController = TextEditingController();

  // List<String> sources = ['인터넷', '책', '"이따 뭐 먹지" 레시피', '기타'];
  Map<String, List<String>> cookingMethods = {};

  List<String>? excludeKeywords = [];
  Map<String, List<PreferredFoodModel>> itemsByPreferredCategory = {};

  Set<String> renderedCategories = {};
  @override
  void initState() {
    super.initState();
    _loadMethodFromFirestore();
    _loadSearchSettingsFromLocal();
    _loadPreferredFoodsCategoriesFromFirestore();
  }

  void _loadMethodFromFirestore() async {
    try {
      final snapshot = await _db.collection('recipe_method_categories').get();
      final categories = snapshot.docs.map((doc) {
        return RecipeMethodModel.fromFirestore(doc);
      }).toList();

      // itemsByCategory에 데이터를 추가
      setState(() {
        cookingMethods = {
          for (var category in categories) category.categories: category.method,
        };
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.')),
      );
    }
  }

  Future<void> _loadPreferredFoodsCategoriesFromFirestore() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        // 데이터가 없는 경우 기본 데이터 추가
        await _addDefaultPreferredCategories();
      } else {
        final categories = snapshot.docs.map((doc) {
          return PreferredFoodModel.fromFirestore(doc.data());
        }).toList();

        setState(() {
          itemsByPreferredCategory = {};

          for (var categoryModel in categories) {
            categoryModel.category.forEach((categoryName, itemList) {
              if (itemsByPreferredCategory.containsKey(categoryName)) {
                itemsByPreferredCategory[categoryName]!.add(categoryModel);
              } else {
                itemsByPreferredCategory[categoryName] = [categoryModel];
              }
            });
          }
        });
      }
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.')),
      );
    }
  }

  Future<void> _addDefaultPreferredCategories() async {
    await PreferredFoodsService.addDefaultPreferredCategories(
      context,
      _loadPreferredFoodsCategoriesFromFirestore,
    );
  }

  Future<void> _loadSearchSettingsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCookingMethods =
          prefs.getStringList('selectedCookingMethods') ?? [];
      selectedPreferredFoodCategories =
          prefs.getStringList('selectedPreferredFoodCategories') ?? [];
      excludeKeywords = prefs.getStringList('excludeKeywords') ?? [];
    });
  }

  // 제외 검색어 추가 함수
  void _addExcludeKeyword() {
    final keyword = excludeKeywordController.text.trim();
    if (keyword.isNotEmpty && !(excludeKeywords?.contains(keyword) ?? true)) {
      setState(() {
        excludeKeywords?.add(keyword);
      });
      excludeKeywordController.clear();
    }
  }

  Future<void> _saveSearchSettingsToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'selectedCookingMethods', selectedCookingMethods ?? ['']);
    await prefs.setStringList('selectedPreferredFoodCategories',
        selectedPreferredFoodCategories ?? ['']);
    await prefs.setStringList('excludeKeywords', excludeKeywords ?? ['']);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('레시피 검색 상세설정'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '조리 방법 선택',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            for (var entry in cookingMethods.entries) // Map의 각 entry를 순회하며 빌드
              _buildMethodCategory(entry.key, entry.value),
            SizedBox(height: 16),

            // 제외 검색어 선택
            Text(
              '검색에서 제외하고 싶은 식재료를 선택',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            TextField(
              controller: excludeKeywordController,
              decoration: InputDecoration(hintText: '제외할 재료를 입력하세요'),
              onSubmitted: (value) {
                _addExcludeKeyword();
              },
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: excludeKeywords?.map((keyword) {
                    return GestureDetector(
                      onDoubleTap: () {
                        setState(() {
                          excludeKeywords?.remove(keyword);
                        });
                      },
                      child: Chip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_circle, // '-' 아이콘
                              color: theme.chipTheme.labelStyle?.color ??
                                  Colors.red, // 아이콘 색상
                              size: 16, // 아이콘 크기
                            ),
                            SizedBox(width: 6),
                            Text(
                              keyword,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.chipTheme.selectedColor,
                                fontWeight: FontWeight.bold, // 강조를 위해 굵게 설정
                              ),
                            ),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(
                            color: theme.chipTheme.labelStyle?.color ??
                                Colors.red, // 테두리 색상 빨간색으로 변경
                            width: 1, // 테두리 두께 조절
                          ),
                        ),
                      ),
                    );
                  }).toList() ??
                  [],
            ),
            SizedBox(height: 16),
            // 레시피 출처 선택
            Text(
              '선호 식품 및 조리방법 선택',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),

            // for (var entry
            // in itemsByPreferredCategory.entries) // Map의 각 entry를 순회하며 빌드
            _buildPreferredCategory(),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50, // 버튼 높이 설정
          child: NavbarButton(
            buttonTitle: '저장',
            onPressed: () async {
              await _saveSearchSettingsToLocal(); // 설정을 로컬에 저장
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  // 조리 방법 카테고리 빌드 함수
  Widget _buildMethodCategory(String category, List<String> methods) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: methods.map((method) {
            final isSelected =
                selectedCookingMethods?.contains(method) ?? false;
            return ChoiceChip(
              label: Text(
                method,
                style: isSelected
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.chipTheme.secondaryLabelStyle?.color,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: theme.chipTheme.labelStyle?.color,
                      ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedCookingMethods.add(method);
                  } else {
                    selectedCookingMethods.remove(method);
                  }
                });
              },
              // selectedColor: Colors.deepPurple[100],
              // backgroundColor: Colors.grey[200],
            );
          }).toList(),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPreferredCategory() {
    final theme = Theme.of(context);

    final uniqueCategories = itemsByPreferredCategory.values
        .expand((models) => models.expand((model) => model.category.keys))
        .toSet()
        .toList();

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.start, // 왼쪽 정렬
      children: uniqueCategories.map((categoryName) {
        final isSelected =
            selectedPreferredFoodCategories?.contains(categoryName) ?? false;

        return ChoiceChip(
          label: Text(
            categoryName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? theme.chipTheme.secondaryLabelStyle?.color
                  : theme.chipTheme.labelStyle?.color,
            ),
          ), // category를 라벨로 설정
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected &&
                  !selectedPreferredFoodCategories.contains(categoryName)) {
                selectedPreferredFoodCategories.add(categoryName);
              } else {
                selectedPreferredFoodCategories.remove(categoryName);
              }
            });
          },
          // selectedColor: Colors.deepPurple[100],
          // backgroundColor: Colors.grey[200],
        );
      }).toList(),
    );
  }
}
