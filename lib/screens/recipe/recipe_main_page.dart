import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/constants.dart';
import 'package:food_for_later_new/models/items_in_fridge.dart';
import 'package:food_for_later_new/models/recipe_method_model.dart';
import 'package:food_for_later_new/models/recipe_thema_model.dart';
import 'package:food_for_later_new/screens/recipe/add_recipe.dart';
import 'package:food_for_later_new/screens/recipe/recipe_grid.dart';
import 'package:food_for_later_new/screens/recipe/recipe_grid_theme.dart';
import 'package:food_for_later_new/screens/recipe/view_research_list.dart';
import 'package:food_for_later_new/screens/recipe/view_scrap_recipe_list.dart';

class RecipeMainPage extends StatefulWidget {
  final List<String> category;
  RecipeMainPage({
    required this.category,
  });
  @override
  _RecipeMainPageState createState() => _RecipeMainPageState();
}

class _RecipeMainPageState extends State<RecipeMainPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  String searchKeyword = '';
  Map<String, List<String>> itemsByCategory = {};
  List<RecipeThemaModel> themaCategories = [];
  List<String> categories = []; // 카테고리를 저장할 필드 추가
  Map<String, List<String>> methodCategories = {};
  List<String> filteredItems = [];
  List<String> fridgeIngredients = [];
  String userRole = '';
  final user = FirebaseAuth.instance.currentUser;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final List<Tab> myTabs = <Tab>[
    Tab(text: '재료별'),
    Tab(text: '테마별'),
    Tab(text: '조리방법별'),
  ];




  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: myTabs.length, vsync: this);
    _loadCategoriesFromFirestore(); // Firestore로부터 카테고리 데이터 로드
    _loadThemaFromFirestore(); // Firestore로부터 카테고리 데이터 로드
    _loadMethodFromFirestore();
    _loadItemsInFridgeFromFirestore();
    _loadUserRole();
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

  Future<Map<String, List<String>>> _fetchFoods() async {
    Map<String, List<String>> categoryMap = {};
    Set<String> userFoodIds = {}; // 사용자가 수정한 default_foods의 ID 목록
    Set<String> userFoodNames = {}; // 사용자가 수정한 식품명을 저장

    try {
      // ✅ 1. 사용자가 수정한 foods 데이터 가져오기
      final userSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in userSnapshot.docs) {
        final data = doc.data();
        final category = data['defaultCategory'] as String?;
        final foodName = data['foodsName'] as String?;
        final defaultFoodsDocId = data['defaultFoodsDocId'] as String?;

        if (category != null && foodName != null) {
          userFoodNames.add(foodName); // 사용자 식품 저장
          if (defaultFoodsDocId != null) {
            userFoodIds.add(defaultFoodsDocId); // 수정된 기본 식품 ID 저장
          }

          if (categoryMap.containsKey(category)) {
            categoryMap[category]!.add(foodName);
          } else {
            categoryMap[category] = [foodName];
          }
        }
      }

      // ✅ 2. 기본 데이터(default_foods) 가져오기
      final defaultSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      for (var doc in defaultSnapshot.docs) {
        final data = doc.data();
        final category = data['defaultCategory'] as String?;
        final foodName = data['foodsName'] as String?;
        final foodId = doc.id; // default_foods의 문서 ID

        if (category != null && foodName != null) {
          // ✅ 사용자가 수정한 데이터에 없는 경우만 추가
          if (!userFoodIds.contains(foodId) && !userFoodNames.contains(foodName)) {
            if (categoryMap.containsKey(category)) {
              categoryMap[category]!.add(foodName);
            } else {
              categoryMap[category] = [foodName];
            }
          }
        }
      }

      return categoryMap;
    } catch (e) {
      print("Error fetching foods: $e");
      return {};
    }
  }

  void _loadCategoriesFromFirestore() async {
    try {
      final categoryMap = await _fetchFoods(); // ✅ 사용자 + 기본 데이터 포함된 목록 가져오기
      // ✅ 카테고리를 predefinedCategoryFridge 순서로 정렬
      final sortedCategories = categoryMap.keys.toList()
        ..sort((a, b) {
          final indexA = predefinedCategoryFridge.indexOf(a);
          final indexB = predefinedCategoryFridge.indexOf(b);
          return (indexA == -1 ? predefinedCategoryFridge.length : indexA)
              .compareTo(
                  indexB == -1 ? predefinedCategoryFridge.length : indexB);
        });

      final sortedItemsByCategory = Map.fromEntries(
        sortedCategories
            .map((category) => MapEntry(category, categoryMap[category]!)),
      );

      setState(() {
        this.categories = sortedItemsByCategory.keys.toList();
        this.itemsByCategory = sortedItemsByCategory;
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),),
      );
    }
  }

  void _loadThemaFromFirestore() async {
    try {
      final snapshot = await _db
          .collection('recipe_thema_categories')
          .orderBy('priority', descending: false)
          .get();
      final themaCategories = snapshot.docs.map((doc) {
        return RecipeThemaModel.fromFirestore(doc);
      }).toList();

      setState(() {
        this.themaCategories = themaCategories;
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),),
      );
    }
  }

  void _loadMethodFromFirestore() async {
    try {
      final snapshot = await _db.collection('recipe_method_categories').get();
      final categories = snapshot.docs.map((doc) {
        return RecipeMethodModel.fromFirestore(doc);
      }).toList();

      setState(() {
        methodCategories = {
          for (var category in categories) category.categories: category.method,
        };
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),),
      );
    }
  }

  void _loadItemsInFridgeFromFirestore() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await _db
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .get();
      final itemsInFridge = snapshot.docs.map((doc) {
        return ItemsInFridge.fromFirestore(doc);
      }).toList();

      setState(() {
        this.fridgeIngredients = itemsInFridge.expand((item) {
          return item.items
              .map((itemMap) => itemMap['itemName'] ?? 'Unknown Item');
        }).toList();
      });
    } catch (e) {
      print('냉장고 재료를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 재료를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),),
      );
    }
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

  List<String> _getTopIngredientsByCategoryPriority(
      Map<String, List<String>> itemsByCategory,
      List<String> fridgeIngredients) {
    // fridgeIngredients를 우선순위에 따라 정렬
    List<MapEntry<String, String>> prioritizedIngredients = [];

    fridgeIngredients.forEach((ingredient) {
      itemsByCategory.forEach((category, foods) {
        if (foods.contains(ingredient)) {
          int priority = categoryPriority[category] ?? 0; // 카테고리 우선순위를 적용
          prioritizedIngredients.add(MapEntry(ingredient, category));
        }
      });
    });

    // 우선순위에 따라 정렬
    prioritizedIngredients.sort((a, b) {
      int priorityA = categoryPriority[a.value] ?? 0;
      int priorityB = categoryPriority[b.value] ?? 0;
      return priorityB.compareTo(priorityA);
    });

    // 상위 10개의 재료를 추려냄
    return prioritizedIngredients.map((entry) => entry.key).take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // appBar: AppBar(
      //   title:
      // ),
      body:
      Column(
        children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('레시피',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                    fontSize: 20, // 글자 크기 (기본보다 크게 조정)
                    fontWeight: FontWeight.bold, // 글자 굵게 설정

                  ),),
              ),
              Spacer(),
              Transform.translate(
                offset: Offset(0, 0),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent, // 터치 영역을 확장
                  onTap: () {
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('로그인 하고 레시피를 스크랩해서 관리하세요!'),
                          duration: Duration(seconds: 2), // 3초간 표시
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewScrapRecipeList(),
                      ),
                    ).then((_) {
                      _searchController.clear(); // 텍스트 필드 초기화
                    });
                  },
                  child: Container(
                    height: 50, // 터치 가능한 높이를 넉넉히 설정
                    width: 50, // 터치 가능한 너비를 넉넉히 설정
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0), // 둥근 모서리 유지
                    ),
                    child: Center(
                      child: Icon(
                        Icons.bookmark,
                        size: 30,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '검색어 입력',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                    ),
                    style: TextStyle(color: theme.chipTheme.labelStyle!.color),
                    // onChanged: (value) {
                    //   _searchItems(value); // 검색어 입력 시 아이템 필터링
                    // },
                    onSubmitted: (value) {
                      // 사용자가 입력한 값을 searchKeyword로 업데이트
                      setState(() {
                        searchKeyword = value.trim();
                      });
                      _saveSearchKeyword(searchKeyword);
                      _searchController.clear();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewResearchList(
                              category: [searchKeyword], // 필터링된 결과 전달
                              useFridgeIngredients: false,
                              initialKeywords: [searchKeyword]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: myTabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RecipeGrid(
                  categories: itemsByCategory.keys.toList(),
                  itemsByCategory: itemsByCategory,
                  // physics: NeverScrollableScrollPhysics(),
                ),
                RecipeGridTheme(
                  categories:
                      themaCategories.map((thema) => thema.categories).toList(),
                  // physics: NeverScrollableScrollPhysics(),
                ),
                RecipeGrid(
                  categories: [],
                  itemsByCategory: methodCategories,
                  // physics: NeverScrollableScrollPhysics(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
          mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: NavbarButton(
                      buttonTitle: '냉장고 재료 레시피 추천',
                      onPressed: () async {
                        List<String> topIngredients =
                            _getTopIngredientsByCategoryPriority(
                                itemsByCategory, fridgeIngredients);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewResearchList(
                              // category: topIngredients,
                              useFridgeIngredients: true,
                            ),
                          ),
                        ).then((_) {
                          // 🔹 Navigator.pop 이후 텍스트 필드 초기화
                          _searchController.clear();
                        });
                      },
                    ),
                  ),
                  SizedBox(width: 20),
                  // 물건 추가 버튼
                  FloatingAddButton(
                    heroTag: 'recipe_add_button',
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;

                      if (user == null ||
                          user.email == 'guest@foodforlater.com') {
                        // 🔹 방문자(게스트) 계정이면 접근 차단 및 안내 메시지 표시
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('로그인 후 레시피를 작성할 수 있습니다.')),
                        );
                        return; // 🚫 여기서 함수 종료 (페이지 이동 X)
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddRecipe(),
                          fullscreenDialog: true, // 모달 다이얼로그처럼 보이게 설정
                        ),
                      ).then((_) {
                        // 🔹 Navigator.pop 이후 텍스트 필드 초기화
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            if (userRole != 'admin' && userRole != 'paid_user')
              SafeArea(
                bottom: false, // 하단 여백 제거
                child: BannerAdWidget(),
              ),
          ],
        ),
      ),
    );
  }
}
