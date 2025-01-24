import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';
import 'package:food_for_later_new/screens/foods/add_item_to_category.dart';
import 'package:food_for_later_new/screens/foods/add_preferred_category.dart';
import 'package:food_for_later_new/screens/fridge/fridge_item_details.dart';
import 'package:food_for_later_new/services/preferred_foods_service.dart';
import 'package:intl/intl.dart';
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
  String? selected_fridgeId = '';

  bool isDeleteMode = false; // 삭제 모드 여부
  List<String> deletedItems = [];

  TextEditingController expirationDaysController = TextEditingController();

  Map<String, List<FoodsModel>> itemsByCategory = {};
  Map<String, List<PreferredFoodModel>> itemsByPreferredCategory = {};
  List<FoodsModel> items = [];
  Set<String> deletedItemNames = {};
  bool isSearchActive = false; // 검색 상태를 관리하는 변수

  double mobileGridMaxExtent = 70; // 모바일에서 최대 크기
  double webGridMaxExtent = 200; // 웹에서 최대 크기
  double gridSpacing = 8.0;
  String userRole = '';
  List<String> predefinedCategoryFridge = [
    '채소',
    '과일',
    '육류',
    '수산물',
    '유제품',
    '가공식품',
    '곡류',
    '견과류',
    '양념',
    '음료/주류',
    '즉석식품',
    '디저트/빵류',
  ];
  @override
  void initState() {
    super.initState();
    _loadSelectedFridge();
    if (widget.sourcePage == 'preferred_foods_category') {
      _loadPreferredFoodsCategoriesFromFirestore();
    } else {
      _loadCategoriesFromFirestore();
    }
    _loadDeletedItems();
    _loadUserRole();
  }

  void _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
    });

    if (selectedFridge != null) {
      selected_fridgeId = await fetchFridgeId(selectedFridge!);
    }
  }

  Future<List<FoodsModel>> _fetchFoods() async {
    List<FoodsModel> userFoods = [];
    List<FoodsModel> defaultFoods = [];
    Set<String> userFoodNames = {};

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      // 🔹 사용자가 수정한 식품 불러오기
      for (var doc in userSnapshot.docs) {
        final food = FoodsModel.fromFirestore(doc);
        userFoods.add(food);
        userFoodNames.add(food.foodsName); // 사용자 식품 이름 저장
      }

      final defaultSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      // 🔹 기본 식품 목록 불러오기 (사용자가 수정하지 않은 것만 추가)
      for (var doc in defaultSnapshot.docs) {
        final food = FoodsModel.fromFirestore(doc);
        if (!userFoodNames.contains(food.foodsName)) {
          defaultFoods.add(food);
        }
      }

      return [...userFoods, ...defaultFoods]; // 사용자 데이터 + 기본 데이터 결합
    } catch (e) {
      print("Error fetching foods: $e");
      return [];
    }
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

  void _loadCategoriesFromFirestore() async {
    try {
      final foods = await _fetchFoods(); // 사용자 및 기본 식품 불러오기

      setState(() {
        itemsByCategory = {};

        for (var food in foods) {
          if (widget.sourcePage != 'update_foods_category') {
            if (deletedItemNames.contains(food.foodsName)) {
              continue;
            }
          }

          if (itemsByCategory.containsKey(food.defaultCategory)) {
            itemsByCategory[food.defaultCategory]!.add(food);
          } else {
            itemsByCategory[food.defaultCategory] = [food];
          }
        }
        final sortedKeys = itemsByCategory.keys.toList()
          ..sort((a, b) {
            final indexA = predefinedCategoryFridge.indexOf(a);
            final indexB = predefinedCategoryFridge.indexOf(b);
            return (indexA == -1 ? predefinedCategoryFridge.length : indexA)
                .compareTo(indexB == -1 ? predefinedCategoryFridge.length : indexB);
          });

        itemsByCategory = Map.fromEntries(
          sortedKeys.map((key) => MapEntry(key, itemsByCategory[key]!)),
        );
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
        await _addDefaultPreferredCategories();
      } else {
        final Map<String, List<PreferredFoodModel>> loadedData = {};

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final model = PreferredFoodModel.fromFirestore(data);

          model.category.forEach((key, value) {
            if (loadedData.containsKey(key)) {
              loadedData[key]!.addAll(value.map((item) => PreferredFoodModel(
                    category: {
                      key: [item]
                    },
                    userId: model.userId,
                  )));
            } else {
              loadedData[key] = value
                  .map((item) => PreferredFoodModel(
                        category: {
                          key: [item]
                        },
                        userId: model.userId,
                      ))
                  .toList();
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
    await PreferredFoodsService.addDefaultPreferredCategories(
      context,
      _loadPreferredFoodsCategoriesFromFirestore,
    );
  }

  Future<void> _addItemsToFridge() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후에 냉장고에 추가할 수 있습니다.')),
      );
      return; // 🚫 게스트 사용자는 추가 불가
    }

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final fridgeId = selected_fridgeId;

    try {
      for (String itemName in selectedItems) {
        final matchingFood = itemsByCategory.values.expand((x) => x).firstWhere(
              (food) => food.foodsName == itemName, // itemName과 일치하는지 확인
              orElse: () => FoodsModel(
                id: 'unknown',
                foodsName: itemName,
                defaultCategory: '기타',
                defaultFridgeCategory: '냉장',
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
            'fridgeCategoryId': fridgeCategoryId ?? '냉장',
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후에 장바구니에 추가할 수 있습니다.')),
      );
      return; // 🚫 게스트 사용자는 추가 불가
    }

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
          print("이미 장바구니에 존재하는 아이템: $itemName");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$itemName은 이미 장바구니에 존재합니다.')),
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
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context); // AddItem 화면을 종료
      }
    });
  }

  Future<String?> fetchFridgeId(String fridgeName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          .where('FridgeName', isEqualTo: fridgeName)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id; // fridgeId 반환
      } else {
        print("No fridge found for the given name: $fridgeName");
        return null; // 일치하는 냉장고가 없으면 null 반환
      }
    } catch (e) {
      print("Error fetching fridgeId: $e");
      return null;
    }
  }

  void _navigateToAddItemPage() async {
    if (userRole != 'admin' && userRole != 'paid_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('프리미엄 서비스를 이용하면 나만의 식품 카테고리를 관리할 수 있어요!'),
            ],
          ),
          duration: Duration(seconds: 3), // 3초간 표시
        ),
      );
      return;
    }

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

  void _navigateAddPreferredCategory() {
    print('_navigateAddPreferredCategory() selectedCategory $selectedCategory');
    if (userRole != 'admin' && userRole != 'paid_user') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('프리미엄 서비스를 이용하면 나만의 선호식품 카테고리를 관리할 수 있어요!'),
              ],
            ),
            duration: Duration(seconds: 3), // 3초간 표시
          ),
        );
        return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPreferredCategory(
          categoryName: selectedCategory ?? '',
          sourcePage: 'add_category',
        ),
      ),
    ).then((_) {
      _loadPreferredFoodsCategoriesFromFirestore();
    });
  }

  void _searchItems(String keyword) {
    List<FoodsModel> tempFilteredItems = [];
    setState(() {
      searchKeyword = keyword.trim().toLowerCase();
      isSearchActive = true; // 검색 버튼을 누르면 검색 활성화
      if (searchKeyword.isNotEmpty) {
        _saveSearchKeyword(searchKeyword);
      }

      if (widget.sourcePage == 'preferred_foods_category') {
        itemsByPreferredCategory.forEach((category, categoryModels) {
          for (var categoryModel in categoryModels) {
            categoryModel.category.forEach((key, values) {
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
      filteredItems = tempFilteredItems;
    });
  }

  void _saveSearchKeyword(String keyword) async {
    final searchRef = FirebaseFirestore.instance.collection('search_keywords');

    try {
      final snapshot = await searchRef.doc(keyword).get();
      if (snapshot.exists) {
        // 기존 데이터가 있으면 검색 횟수를 증가
        await searchRef.doc(keyword).update({
          'count': FieldValue.increment(1),
        });
      } else {
        // 새로운 검색어를 추가
        await searchRef.doc(keyword).set({
          'keyword': keyword,
          'count': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('검색어 저장 중 오류 발생: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      style:
                          TextStyle(color: theme.chipTheme.labelStyle!.color),
                      onChanged: (value) {
                        _searchItems(value); // 검색어 입력 시 아이템 필터링
                      },
                    ),
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
      bottomNavigationBar:
          (selectedItems.isNotEmpty &&
                  (widget.sourcePage == 'shoppingList' ||
                      widget.sourcePage == 'fridge')) ?
              Column(
                mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
                mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
                children: [
                  Container(
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
                    ),
                  if (userRole != 'admin' && userRole != 'paid_user')
                  BannerAdWidget(),
                ],
              ):
          (userRole != 'admin' && userRole != 'paid_user')?
            BannerAdWidget():null
    );
  }

  Widget _buildFilteredCategoryGrid() {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
      double maxCrossAxisExtent =
          isWeb ? webGridMaxExtent : mobileGridMaxExtent; // 최대 크기 설정
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
                    style: TextStyle(color: selectedItems.contains(searchKeyword)
                        ? theme.chipTheme.secondaryLabelStyle!.color
                        : Colors.white),
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
    });
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
      double maxCrossAxisExtent =
          isWeb ? webGridMaxExtent : mobileGridMaxExtent;
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
    });
  }

  Widget _buildPreferredCategoryGrid() {
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
      double maxCrossAxisExtent =
          isWeb ? webGridMaxExtent : mobileGridMaxExtent;
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
              onTap: _navigateAddPreferredCategory,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.chipTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Icon(Icons.add,
                      size: 32, color: theme.chipTheme.labelStyle!.color),
                ),
              ),
            );
          } else {
            String categoryName =
                itemsByPreferredCategory.keys.elementAt(index);

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
    });
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

    final itemCount =
        isPreferredCategory ? preferredItems.length : regularItems.length;

    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
      double maxCrossAxisExtent =
          isWeb ? webGridMaxExtent : mobileGridMaxExtent;
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
              onTap: isPreferredCategory? _navigateAddPreferredCategory: _navigateToAddItemPage,
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
                        .category[selectedCategory!]
                        ?.join(", ") ??
                    ''
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
                  // 🔹 Firestore에서 `foods` 컬렉션에서 먼저 검색
                  final foodsSnapshot = await FirebaseFirestore.instance
                      .collection('foods')
                      .where('foodsName', isEqualTo: itemName)
                      .get();

                  Map<String, dynamic>? foodData;

                  if (foodsSnapshot.docs.isNotEmpty) {
                    // 🔹 사용자가 수정한 foods 데이터 우선 사용
                    foodData = foodsSnapshot.docs.first.data();
                  } else {
                    // 🔹 foods에 데이터가 없으면 default_foods에서 검색
                    final defaultFoodsSnapshot = await FirebaseFirestore
                        .instance
                        .collection('default_foods')
                        .where('foodsName', isEqualTo: itemName)
                        .get();

                    if (defaultFoodsSnapshot.docs.isNotEmpty) {
                      foodData = defaultFoodsSnapshot.docs.first.data();
                    }
                  }

                  if (foodData != null) {
                    // 🔹 데이터가 존재하는 경우 상세보기 페이지로 이동
                    String defaultCategory =
                        foodData['defaultCategory'] ?? '기타';
                    String defaultFridgeCategory =
                        foodData['defaultFridgeCategory'] ?? '기타';
                    String shoppingListCategory =
                        foodData['shoppingListCategory'] ?? '기타';
                    int shelfLife = foodData['shelfLife'] ?? 0;

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
                          deletedItemNames.remove(itemName); // 삭제 목록에서 제거
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${itemName} 아이템이 복원되었습니다.')),
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
    });
  }
}
