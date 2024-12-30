import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/default_food_model.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';
import 'package:food_for_later_new/screens/foods/add_item_to_category.dart';
import 'package:food_for_later_new/screens/foods/add_preferred_category.dart';
import 'package:food_for_later_new/screens/fridge/fridge_item_details.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddItem extends StatefulWidget {
  final String pageTitle;
  final String addButton;
  final String sourcePage;
  final Function onItemAdded;

  AddItem({
    required this.pageTitle,
    required this.addButton,
    required this.sourcePage,
    required this.onItemAdded,
  });

  @override
  _AddItemState createState() => _AddItemState();
}

class _AddItemState extends State<AddItem> {
  DateTime currentDate = DateTime.now();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const List<String> storageSections = [];

  List<List<Map<String, int>>> itemLists = [[], [], []];
  List<String> fridgeItems = [];
  List<String> selectedItems = [];
  List<FoodsModel> filteredItems = [];

  String? selectedCategory;
  String? selectedSection;
  String searchKeyword = '';
  String? selectedItem;
  String? selectedFridge = '';

  // int expirationDays = 7;
  bool isDeleteMode = false; // 삭제 모드 여부
  List<String> deletedItems = [];

  // 유통기한을 위한 컨트롤러 및 함수 추가
  TextEditingController expirationDaysController = TextEditingController();

  Map<String, List<FoodsModel>> itemsByCategory = {};
  Map<String, List<PreferredFoodModel>> itemsByPreferredCategory = {};
  List<FoodsModel> items = [];
  Set<String> deletedItemNames = {};
  bool isSearchActive = false; // 검색 상태를 관리하는 변수

  double mobileGridMaxExtent = 70; // 모바일에서 최대 크기
  double webGridMaxExtent = 200; // 웹에서 최대 크기
  double gridSpacing = 8.0;
  // initState 또는 빌드 직전에 중복 제거
  @override
  void initState() {
    super.initState();
    // removeDuplicates(); // 중복 제거 함수 호출
    _loadSelectedFridge();
    if (widget.sourcePage == 'preferred_foods_category') {
      _loadPreferredFoodsCategoriesFromFirestore();
    } else {
      _loadCategoriesFromFirestore();
    }
    _loadDeletedItems();
  }

  void _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
    });
  }

  void _navigateToAddItemPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemToCategory(
          categoryName: selectedCategory ?? '기타',
        ),
        fullscreenDialog: true, // 모달 다이얼로그처럼 보이게 설정
      ),
    );

    if (result == true) {
      _loadCategoriesFromFirestore();
    }
  }

  void _loadCategoriesFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('foods').get();
      final categories = snapshot.docs.map((doc) {
        return FoodsModel.fromFirestore(doc);
      }).toList();

      setState(() {
        itemsByCategory = {};

        for (var category in categories) {
          if (widget.sourcePage != 'update_foods_category') {
            if (deletedItemNames.contains(category.foodsName)) {
              continue;
            }
          }

          // 기존 카테고리 리스트가 있으면 추가, 없으면 새 리스트 생성
          if (itemsByCategory.containsKey(category.defaultCategory)) {
            itemsByCategory[category.defaultCategory]!
                .add(category); // 이미 있는 리스트에 추가
          } else {
            itemsByCategory[category.defaultCategory] = [
              category
            ]; // 새로운 리스트 생성
          }
        }
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.')),
      );
    }
  }

  void _loadDeletedItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('deleted_foods')
          .where('isDeleted', isEqualTo: true)
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        deletedItemNames = snapshot.docs
            .map((doc) => doc.data()['itemName'] as String)
            .toSet();
      });
    } catch (e) {
      print('Failed to load deleted items: $e');
    }
  }

  void _loadPreferredFoodsCategoriesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        // 데이터가 없는 경우 기본 데이터 추가
        await _addDefaultPreferredCategories();
      } else {
        final Map<String, List<PreferredFoodModel>> loadedData = {};

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final model = PreferredFoodModel.fromFirestore(data);

          model.categoryName.forEach((key, value) {
            print('categoryName key: $key, value: $value'); // 디버깅

            if (loadedData.containsKey(key)) {
              loadedData[key]!.addAll(value.map((item) =>
                  PreferredFoodModel(
                    categoryName: {key: [item]},
                    userId: model.userId,
                  )));
            } else {
              loadedData[key] = value.map((item) =>
                  PreferredFoodModel(
                    categoryName: {key: [item]},
                    userId: model.userId,
                  )).toList();
            }
          });
        }

        setState(() {
          itemsByPreferredCategory = Map.from(loadedData);
        });
      }
    } catch (e) {
      print('Error loading preferred categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리를 불러오는 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _addDefaultPreferredCategories() async {
    try {
      final defaultCategories = {
        '알러지': ['우유', '계란', '땅콩',],
        '유제품': ['우유', '치즈', '요거트'],
        '비건': ['육류', '해산물', '유제품', '계란', '꿀'],
        '무오신채': ['마늘', '양파', '부추', '파', '달래'],
        '설밀나튀': ['설탕', '밀가루', '튀김'],
      };

      for (var entry in defaultCategories.entries) {
        final category = entry.key;
        final items = entry.value;

        // Firestore에 기본 데이터 추가
        await FirebaseFirestore.instance
            .collection('preferred_foods_categories')
            .add({
          'userId': userId,
          'category': {category: items},
        });
      }

      // 데이터 로드 다시 실행
      _loadPreferredFoodsCategoriesFromFirestore();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 선호 카테고리가 추가되었습니다.')),
      );
    } catch (e) {
      print('Error adding default preferred categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 선호 카테고리를 추가하는 중 오류가 발생했습니다.')),
      );
    }
  }

  // 물건 추가 다이얼로그
  Future<void> _addItemsToFridge() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final fridgeId = selectedFridge; // 여기에 실제 유저 ID를 추가하세요

    try {
      for (String itemName in selectedItems) {
        // FoodsModel에서 해당 itemName에 맞는 데이터를 찾기
        final matchingFood = itemsByCategory.values.expand((x) => x).firstWhere(
              (food) => food.foodsName == itemName, // itemName과 일치하는지 확인
              orElse: () => FoodsModel(
                id: 'unknown',
                foodsName: itemName,
                defaultCategory: '기타',
                defaultFridgeCategory: '기타',
                shoppingListCategory: '기타',
                shelfLife: 0,
              ),
            );

        final fridgeCategoryId = matchingFood.defaultFridgeCategory;

        final existingItemSnapshot = await FirebaseFirestore.instance
            .collection('fridge_items')
            .where('items', isEqualTo: itemName.trim().toLowerCase()) // 이름 일치
            .where('FridgeId', isEqualTo: fridgeId) // 냉장고 일치
            .get();

        if (existingItemSnapshot.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('fridge_items').add({
            'items': itemName,
            'FridgeId': fridgeId, // Firestore에 저장할 필드
            'fridgeCategoryId': fridgeCategoryId,
            'registrationDate': Timestamp.fromDate(DateTime.now()),
            'userId': userId,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$itemName 아이템이 이미 냉장고에 있습니다.')),
          );
        }
      }

      setState(() {
        selectedItems.clear();
      });

      widget.onItemAdded();

      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        Navigator.pop(context, true); // Navigator.pop의 중복 실행 방지
      }
    } catch (e) {
      print('아이템 추가 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 추가 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _addItemsToShoppingList() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      for (String itemName in selectedItems) {
        final existingItemSnapshot = await FirebaseFirestore.instance
            .collection('shopping_items')
            .where('items',
                isEqualTo: itemName.trim().toLowerCase()) // 공백 및 대소문자 제거
            .where('userId', isEqualTo: userId)
            .get();

        if (existingItemSnapshot.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('shopping_items').add({
            'items': itemName,
            'userId': userId,
            'isChecked': false, // 장바구니에 추가된 아이템은 기본적으로 체크되지 않음
          });
        } else {
          print("이미 냉장고에 존재하는 아이템: $itemName");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미 냉장고에 존재하는 아이템입니다.')),
          );
        }
      }

      setState(() {
        selectedItems.clear();
      });
    } catch (e) {
      print('아이템 추가 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 추가 중 오류가 발생했습니다.')),
      );
    }

    // 화면 닫기 (AddItem 끄기)
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context); // AddItem 화면을 종료
      }
    });
  }

  // 검색 로직
  void _searchItems(String keyword) {
    List<FoodsModel> tempFilteredItems = [];
    setState(() {
      searchKeyword = keyword.trim().toLowerCase();
      isSearchActive = true; // 검색 버튼을 누르면 검색 활성화

      if (widget.sourcePage == 'preferred_foods_category') {
        itemsByPreferredCategory.forEach((category, categoryModels) {
          for (var categoryModel in categoryModels) {
            categoryModel.categoryName.forEach((key, values) {
              for (var foodName in values) {
                if (foodName.toLowerCase().contains(searchKeyword)) {
                  tempFilteredItems.add(
                    FoodsModel(
                      id: 'unknown',
                      foodsName: foodName,
                      defaultCategory: category,
                      defaultFridgeCategory: '기타',
                      shoppingListCategory: '기타',
                      shelfLife: 0,
                    ),
                  );
                }
              }
            });
          }
        });
      } else {
        itemsByCategory.forEach((category, items) {
          tempFilteredItems.addAll(
            items.where(
                (item) => item.foodsName.toLowerCase().contains(searchKeyword)),
          );
        });
      }
      // 결과 저장
      filteredItems = tempFilteredItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '검색어 입력',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 10.0),
                      ),
                      onChanged: (value) {
                        _searchItems(value); // 검색어 입력 시 아이템 필터링
                      },
                    ),
                  ),
                  SizedBox(width: 10),
                  BasicElevatedButton(
                    onPressed: () {
                      _searchItems(searchKeyword); // 검색 버튼 클릭 시 검색어 필터링
                    },
                    iconTitle: Icons.search,
                    buttonTitle: '검색',
                  ),
                ],
              ),
            ),
            if (isSearchActive) ...[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildFilteredCategoryGrid(),
              ),
            ] else ...[
              if (widget.sourcePage == 'preferred_foods_category')
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildPreferredCategoryGrid(),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildCategoryGrid(),
                ),
              if (selectedCategory != null) ...[
                Divider(
                  thickness: 1,
                  color: Colors.grey, // 색상 설정
                  indent: 20, // 왼쪽 여백
                  endIndent: 20, // 오른쪽 여백),),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildItemsGrid(),
                ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: selectedItems.isNotEmpty &&
              (widget.sourcePage == 'shoppingList' ||
                  widget.sourcePage == 'fridge')
          ? Container(
              color: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: NavbarButton(
                  buttonTitle: widget.addButton,
                  onPressed: () {
                    if (widget.sourcePage == 'shoppingList') {
                      _addItemsToShoppingList(); // 장바구니에 아이템 추가
                    } else if (widget.sourcePage == 'fridge') {
                      _addItemsToFridge(); // 냉장고에 아이템 추가
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilteredCategoryGrid() {
    final theme = Theme.of(context);
    return LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
          double maxCrossAxisExtent = isWeb ? webGridMaxExtent : mobileGridMaxExtent; // 최대 크기 설정
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 1,
          ),
          itemCount: filteredItems.isEmpty ? 1 : filteredItems.length + 1,
          itemBuilder: (context, index) {
            if (index == filteredItems.length) {
              // 마지막 그리드 항목에 "검색어로 새 항목 추가" 항목 표시
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (!selectedItems.contains(searchKeyword)) {
                      selectedItems.add(searchKeyword); // 검색어로 새로운 항목 추가
                    } else {
                      selectedItems.remove(searchKeyword); // 선택 취소
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedItems.contains(searchKeyword)
                        ? theme.chipTheme.selectedColor
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      '$searchKeyword',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            } else {
              FoodsModel currentItem = filteredItems[index];
              String itemName = currentItem.foodsName; // 여기서 itemName 추출
              //키워드 검색 결과 그리드 렌더링
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (!selectedItems.contains(itemName)) {
                      selectedItems.add(itemName); // 아이템 선택
                    } else {
                      selectedItems.remove(itemName); // 선택 취소
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedItems.contains(itemName)
                        ? theme.chipTheme.selectedColor
                        : theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: AutoSizeText(
                      itemName,
                      style: TextStyle(
                        color: selectedItems.contains(itemName)
                            ? theme.chipTheme.secondaryLabelStyle!.color
                            : theme.chipTheme.labelStyle!.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6,
                      // 최소 글자 크기 설정
                      maxFontSize: 16, // 최대 글자 크기 설정
                    ),
                  ),
                ),
              );
            }
          },
        );
      }
    );
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    return LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
          double maxCrossAxisExtent = isWeb ? webGridMaxExtent : mobileGridMaxExtent;
        return GridView.builder(
            shrinkWrap: true,
            // GridView의 크기를 콘텐츠에 맞게 줄임
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxCrossAxisExtent, // 한 줄에 3칸
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 1,
            ),
            itemCount: itemsByCategory.keys.length,
            itemBuilder: (context, index) {
              String category = itemsByCategory.keys.elementAt(index);
              // 아이템 그리드 마지막에 +아이콘 그리드 렌더링
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selectedCategory == category) {
                      selectedCategory = null;
                    } else {
                      selectedCategory = category;
                      // filteredItems = widget.itemsByCategory[category] ?? []; // null 확인
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedCategory == category
                        ? theme.chipTheme.selectedColor
                        : theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ), // 카테고리 버튼 크기 설정
                  child: Center(
                    child: AutoSizeText(
                      category,
                      style: TextStyle(
                        color: selectedCategory == category
                            ? theme.chipTheme.secondaryLabelStyle!.color
                            : theme.chipTheme.labelStyle!.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6,
                      // 최소 글자 크기 설정
                      maxFontSize: 16, // 최대 글자 크기 설정
                    ),
                  ),
                ),
              );
            });
      }
    );
  }

  Widget _buildPreferredCategoryGrid() {
    final theme = Theme.of(context);

    return LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
          double maxCrossAxisExtent = isWeb ? webGridMaxExtent : mobileGridMaxExtent;
          return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: 1,
          ),
          itemCount: itemsByPreferredCategory.keys.length + 1,
          itemBuilder: (context, index) {
            if (index == itemsByPreferredCategory.keys.length) {
              // +아이콘 추가
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPreferredCategory(
                        categoryName: selectedCategory ?? '기타',
                        sourcePage: 'add_category',
                      ),
                    ),
                  ).then((_) {
                    _loadPreferredFoodsCategoriesFromFirestore();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Icon(Icons.add, size: 32, color: theme.chipTheme.labelStyle!.color),
                  ),
                ),
              );
            } else {
              String categoryName = itemsByPreferredCategory.keys.elementAt(index);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = categoryName;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedCategory == categoryName
                        ? theme.chipTheme.selectedColor
                        : theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: AutoSizeText(
                      categoryName,
                      style: TextStyle(
                        color: selectedCategory == categoryName
                            ? theme.chipTheme.secondaryLabelStyle!.color
                            : theme.chipTheme.labelStyle!.color,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              );
            }
          },
        );
      }
    );
  }

  // 카테고리별 아이템을 출력하는 그리드
  Widget _buildItemsGrid() {
    final theme = Theme.of(context);

    final isPreferredCategory = widget.sourcePage == 'preferred_foods_category';
    List preferredItems = [];
    List<FoodsModel> regularItems = [];

    if (isPreferredCategory) {
      if (selectedCategory != null &&
          itemsByPreferredCategory.containsKey(selectedCategory!)) {
        preferredItems = itemsByPreferredCategory[selectedCategory!]!;
      }
    } else {
      if (selectedCategory != null &&
          itemsByCategory.containsKey(selectedCategory!)) {
        regularItems = itemsByCategory[selectedCategory!]!;
      }
    }

    final itemCount = isPreferredCategory
        ? preferredItems.length
        : regularItems.length;

    return LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
          double maxCrossAxisExtent = isWeb ? webGridMaxExtent : mobileGridMaxExtent;
          return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxCrossAxisExtent, // 한 줄에 3칸
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: 1,
          ),
          itemCount: itemCount + 1,
          itemBuilder: (context, index) {
            if (index == itemCount) {
              return GestureDetector(
                onTap: () {
                  if (isPreferredCategory) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddPreferredCategory(
                          categoryName: selectedCategory ?? '기타',
                          sourcePage: 'add_items',
                        ),
                      ),
                    ).then((_) {
                      _loadPreferredFoodsCategoriesFromFirestore();
                    });
                  } else {
                    _navigateToAddItemPage();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedItems == items
                        ? theme.chipTheme.selectedColor
                        : theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Icon(Icons.add,
                        color: theme.chipTheme.labelStyle!.color, size: 32),
                  ),
                ),
              );
            } else {
              final item = isPreferredCategory
                  ? preferredItems[index] as PreferredFoodModel
                  : regularItems[index] as FoodsModel;

              final itemName = isPreferredCategory
                  ? (item as PreferredFoodModel)
                  .categoryName[selectedCategory!]
                  ?.join(", ") ?? ''
                  : (item as FoodsModel).foodsName;

              final isSelected = selectedItems.contains(itemName);
              var isDeleted = deletedItemNames.contains(itemName);

              return GestureDetector(
                onTap: widget.sourcePage != 'update_foods_category' &&
                    widget.sourcePage != 'preferred_foods_category'
                    ? () {
                        setState(() {
                          if (isSelected) {
                            selectedItems.remove(itemName);
                          } else {
                            selectedItems.add(itemName);
                          }
                        });
                      }
                    : null,
                onDoubleTap: () async {
                  try {
                    final foodsSnapshot = await FirebaseFirestore.instance
                        .collection('foods')
                        .where('foodsName',
                            isEqualTo: itemName) // 현재 아이템과 일치하는지 확인
                        .get();

                    if (foodsSnapshot.docs.isNotEmpty) {
                      final foodsData = foodsSnapshot.docs.first.data();

                      String defaultCategory = foodsData['defaultCategory'] ?? '기타';
                      String defaultFridgeCategory =
                          foodsData['defaultFridgeCategory'] ?? '기타';
                      String shoppingListCategory =
                          foodsData['shoppingListCategory'] ?? '기타';
                      int shelfLife = foodsData['shelfLife'] ?? 0;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FridgeItemDetails(
                            foodsName: itemName,
                            foodsCategory: defaultCategory,
                            fridgeCategory: defaultFridgeCategory,
                            shoppingListCategory: shoppingListCategory,
                            consumptionDays: shelfLife,
                            registrationDate:
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          ),
                        ),
                      );
                    } else {
                      print("Item not found in foods collection: $itemName");
                    }
                  } catch (e) {
                    print('Error fetching food details: $e');
                  }
                },
                onLongPress: widget.sourcePage == 'update_foods_category'
                    ? () async {
                        if (isDeleted) {
                          // 이미 삭제된 아이템이면 Firestore에서 삭제
                          await FirebaseFirestore.instance
                              .collection('deleted_foods')
                              .where('itemName', isEqualTo: itemName)
                              .where('userId', isEqualTo: userId)
                              .get()
                              .then((snapshot) {
                            for (var doc in snapshot.docs) {
                              doc.reference.delete(); // 문서 삭제
                            }
                          });

                          setState(() {
                            isDeleted = false; // 삭제 상태 해제
                            deletedItemNames
                                .remove(itemName); // 삭제 목록에서 제거
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('${itemName} 아이템이 복원되었습니다.')),
                          );
                        } else {
                          await FirebaseFirestore.instance
                              .collection('deleted_foods')
                              .add({
                            'isDeleted': true,
                            'itemName': itemName,
                            'userId': userId
                          });

                          setState(() {
                            isDeleted = true;
                            deletedItemNames.add(itemName);
                          });
                        }
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? theme.chipTheme.disabledColor // 삭제된 아이템은 회색
                        : isSelected
                            ? theme.chipTheme.selectedColor
                            : theme.chipTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: AutoSizeText(
                      itemName,
                      style: TextStyle(
                        color: isDeleted
                            ? Colors.grey[800]
                            : isSelected
                                ? theme.chipTheme.secondaryLabelStyle!.color
                                : theme.chipTheme.labelStyle!.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6,
                      // 최소 글자 크기 설정
                      maxFontSize: 16, // 최대 글자 크기 설정
                    ),
                  ),
                ),
              );
            }
          },
        );
      }
    );
  }
}
