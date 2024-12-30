import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewResearchList extends StatefulWidget {
  final List<String>? category;
  final bool useFridgeIngredients;
  final List<String>? initialKeywords;

  ViewResearchList({
    this.category,
    required this.useFridgeIngredients,
    this.initialKeywords,
  });

  @override
  _ViewResearchListState createState() => _ViewResearchListState();
}

class _ViewResearchListState extends State<ViewResearchList> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String? selectedCategory;
  List<String> keywords = [];
  List<RecipeModel> matchingRecipes = [];
  List<String> filteredItems = [];
  List<String> fridgeIngredients = [];
  List<String>? selectedCookingMethods = [];
  List<String>? selectedPreferredFoodCategory = [];
  List<String>? selectedPreferredFoodCategories = [];
  List<String>? selectedPreferredFoods = [];
  Map<String, List<String>> itemsByCategory = {};
  List<String>? excludeKeywords = [];
  late List<String> topIngredients = [];

  String searchKeyword = '';
  double rating = 0.0;
  bool isScraped = false;

  Map<String, int> categoryPriority = {
    "육류": 10,
    "수산물": 9,
    "채소": 8,
    "과일": 7,
    "유제품": 6
  };

  TextEditingController _searchController = TextEditingController();
  bool useFridgeIngredientsState = false;
  // String? category = widget.category.isNotEmpty ? widget.category[0] : null;

  @override
  void initState() {
    super.initState();
    useFridgeIngredientsState = widget.useFridgeIngredients;
    keywords = widget.initialKeywords ?? [];
    keywords = widget.category ?? [];
    _loadPreferredFoodsByCategory().then((_) {
      _initializeSearch();
    });
    _initializeTopIngredients();
    _loadSearchSettingsFromLocal();
    _loadFridgeItemsFromFirestore();
  }

  // 검색 상세설정 값 불러오기
  Future<void> _loadSearchSettingsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedCookingMethods =
          prefs.getStringList('selectedCookingMethods') ?? [];
      selectedPreferredFoodCategory =
          prefs.getStringList('selectedPreferredFoodCategories') ?? [];
      excludeKeywords = prefs.getStringList('excludeKeywords') ?? [];
      selectedCookingMethods!.forEach((method) {
        if (!keywords.contains(method)) {
          keywords.add(method);
        }
      });
    });
  }

  // 냉장고 재료 불러오기
  Future<void> _loadFridgeItemsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        fridgeIngredients =
            snapshot.docs.map((doc) => doc['items'] as String).toList();
      });
    } catch (e) {
      print('Error loading fridge items: $e');
    }
  }

  // 냉장고 재료 우선순위에 따라 10개 추리기
  Future<List<String>> _applyCategoryPriority(
      List<String> fridgeIngredients) async {
    Map<String, String> ingredientToCategory =
        await _loadIngredientCategoriesFromFirestore();

    List<MapEntry<String, int>> prioritizedIngredients =
        fridgeIngredients.map((ingredient) {
      String category = ingredientToCategory[ingredient] ?? "";
      int priority = categoryPriority[category] ?? 0;
      return MapEntry(ingredient, priority);
    }).toList();

    prioritizedIngredients.sort((a, b) => b.value.compareTo(a.value));
    List<String> topIngredients =
        prioritizedIngredients.map((entry) => entry.key).take(10).toList();
    return topIngredients;
  }

  Future<void> _initializeTopIngredients() async {
    if (widget.useFridgeIngredients) {
      try {
        await _loadFridgeItemsFromFirestore();
        topIngredients = await _applyCategoryPriority(fridgeIngredients);
      } catch (error) {
        print('Error initializing fridge ingredients: $error');
      }
    }
  }

  // 선호카테고리 불러오기
  Future<void> _loadPreferredFoodsByCategory() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        print('No data found in preferred_foods_categories.');
        return;
      }

      final Map<String, List<String>> categoryData = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic>? categories =
            data['category'] as Map<String, dynamic>?;

        if (categories != null) {
          categories.forEach((categoryName, items) {
            if (items is List<dynamic>) {
              categoryData[categoryName] =
                  items.map((item) => item.toString()).toList();
            }
          });
        }
      }
      // selectedPreferredFoodCategory와 일치하는 카테고리만 필터링
      final Map<String, List<String>> filteredCategoryData = {};
      selectedPreferredFoodCategory?.forEach((category) {
        if (categoryData.containsKey(category)) {
          filteredCategoryData[category] = categoryData[category]!;
        }
      });
      setState(() {
        itemsByCategory = filteredCategoryData;
      });
      print('itemsByCategory ${itemsByCategory} ');
    } catch (e) {
      print('Error loading preferred foods by category: $e');
    }
  }

  Future<void> loadRecipesByPreferredFoodsCategory() async {
    try {
      List<String> allPreferredItems = itemsByCategory.values
          .expand((list) => list)
          .toList();

      print('allPreferredItems ${allPreferredItems} ');

      setState(() {
        excludeKeywords = [...?excludeKeywords, ...allPreferredItems];
      });

      print('excludeKeywords ${excludeKeywords} ');

      await fetchRecipes(
          keywords: keywords,
          topIngredients: topIngredients,
          cookingMethods: this.selectedCookingMethods
      );
    } catch (e) {
      print('Error loading recipes by preferred foods category: $e');
    }
  }

  Future<void> _initializeSearch() async {
    await _loadSearchSettingsFromLocal();

    if (widget.useFridgeIngredients) {
      await _initializeTopIngredients();
    }

    if (selectedPreferredFoodCategory != null &&
        selectedPreferredFoodCategory!.isNotEmpty) {
      await loadRecipesByPreferredFoodsCategory();
    }

    await fetchRecipes(
        keywords: keywords,
        topIngredients: topIngredients,
        cookingMethods: this.selectedCookingMethods
    );
  }

  Future<void> fetchRecipes({
    List<String>? keywords,
    List<String>? topIngredients,
    List<String>? cookingMethods,
    bool filterExcluded = true,

  }) async {
    try {
      keywords = keywords?.where((keyword) => keyword.trim().isNotEmpty).toList() ?? [];
      if ((keywords.isEmpty) &&
          (topIngredients == null || topIngredients.isEmpty) &&
          (excludeKeywords == null || excludeKeywords!.isEmpty) &&
          searchKeyword.isEmpty) {
        final querySnapshot = await _db.collection('recipe').get();
        setState(() {
          matchingRecipes = querySnapshot.docs
              .map((doc) => RecipeModel.fromFirestore(doc.data() as Map<String, dynamic>))
              .toList();
        });
        return;
      }

      final cleanedKeywords =
          keywords?.where((keyword) => keyword.trim().isNotEmpty).toList() ?? [];
      final cleanedTopIngredients =
          topIngredients?.where((ingredient) => ingredient.trim().isNotEmpty).toList() ?? [];

      List<DocumentSnapshot> keywordResults = [];
      List<DocumentSnapshot> topIngredientResults = [];
      List<DocumentSnapshot> titleResults = [];

      // Firestore 쿼리 실행
      if (cleanedKeywords.isNotEmpty) {
        final querySnapshots = await Future.wait([
          _db.collection('recipe').where('foods', arrayContainsAny: cleanedKeywords).get(),
          _db.collection('recipe').where('methods', arrayContainsAny: cleanedKeywords).get(),
          _db.collection('recipe').where('themes', arrayContainsAny: cleanedKeywords).get(),
        ]);
        for (var snapshot in querySnapshots) {
          keywordResults.addAll(snapshot.docs);
        }
        // 레시피 제목 검색
        final allRecipes = await _db.collection('recipe').get();
        titleResults = allRecipes.docs.where((doc) {
          final recipeName = doc['recipeName'] as String? ?? '';
          return cleanedKeywords.any((keyword) => recipeName.contains(keyword));
        }).toList();
      }

      if (cleanedTopIngredients.isNotEmpty) {
        final querySnapshots = await Future.wait([
          _db.collection('recipe').where('foods', arrayContainsAny: cleanedTopIngredients).get(),
          _db.collection('recipe').where('methods', arrayContainsAny: cleanedTopIngredients).get(),
          _db.collection('recipe').where('themes', arrayContainsAny: cleanedTopIngredients).get(),
        ]);
        for (var snapshot in querySnapshots) {
          topIngredientResults.addAll(snapshot.docs);
        }
      }

      // 결과 병합
      final Set<String> processedIds = {}; // 중복 제거용
      List<DocumentSnapshot> combinedResults = [];

      // 키워드 결과 (모두 포함)
      for (var doc in [...keywordResults, ...titleResults]) {
        List<String> foods = List<String>.from(doc['foods'] ?? []);
        List<String> methods = List<String>.from(doc['methods'] ?? []);
        List<String> themes = List<String>.from(doc['themes'] ?? []);
        final recipeName = doc['recipeName'] as String? ?? '';

        for (var doc in [...keywordResults, ...titleResults]) {
          if (!processedIds.contains(doc.id)) {
            processedIds.add(doc.id);
            combinedResults.add(doc);
          }
        }

        // topIngredients 결과 추가
        for (var doc in topIngredientResults) {
          if (!processedIds.contains(doc.id)) {
            processedIds.add(doc.id);
            combinedResults.add(doc);
          }
        }

        // 제외 키워드 필터링
        if (filterExcluded && excludeKeywords != null &&
            excludeKeywords!.isNotEmpty) {
          combinedResults = _filterExcludedItems(
            docs: combinedResults,
            excludeKeywords: excludeKeywords!,
          );
        }

        // 상태 업데이트
        setState(() {
          matchingRecipes = combinedResults
              .map((doc) =>
              RecipeModel.fromFirestore(doc.data() as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching recipes: $e');
    }
  }

  List<DocumentSnapshot> _filterExcludedItems({
    required List<DocumentSnapshot> docs,
    required List<String> excludeKeywords,
  }) {
    return docs.where((doc) {
      List<String> foods = List<String>.from(doc['foods'] ?? []);
      List<String> methods = List<String>.from(doc['methods'] ?? []);
      List<String> themes = List<String>.from(doc['themes'] ?? []);

      return !excludeKeywords.any((exclude) =>
          foods.contains(exclude) ||
          methods.contains(exclude) ||
          themes.contains(exclude));
    }).toList();
  }

  Future<Map<String, String>> _loadIngredientCategoriesFromFirestore() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('foods').get();
      Map<String, String> ingredientToCategory = {};
      for (var doc in snapshot.docs) {
        String foodsName = doc['foodsName'];
        String defaultCategory = doc['defaultCategory'];
        ingredientToCategory[foodsName] = defaultCategory;
      }
      return ingredientToCategory; // 재료-카테고리 맵 반환
    } catch (e) {
      print("Error loading ingredient categories: $e");
      return {};
    }
  }

  // Future<List<RecipeModel>> fetchRecipesByKeyword(String searchKeyword) async {
  //   try {
  //     if (searchKeyword.isNotEmpty) {
  //       List<RecipeModel> filteredRecipes = matchingRecipes.where((recipe) {
  //         bool containsInFoods = recipe.foods.any((food) =>
  //             food.toLowerCase().contains(searchKeyword.toLowerCase()));
  //         bool containsInMethods = recipe.methods.any((method) =>
  //             method.toLowerCase().contains(searchKeyword.toLowerCase()));
  //         bool containsInThemes = recipe.themes.any((theme) =>
  //             theme.toLowerCase().contains(searchKeyword.toLowerCase()));
  //         return containsInFoods || containsInMethods || containsInThemes;
  //       }).toList();
  //       return filteredRecipes;
  //     } else {
  //       return matchingRecipes;
  //     }
  //   } catch (e) {
  //     print('Error filtering recipes: $e');
  //     return [];
  //   }
  // }

  Future<bool> loadScrapedData(recipeId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('scraped_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('userId', isEqualTo: userId)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['isScraped'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print("Error fetching recipe data: $e");
      return false;
    }
  }

  void _toggleScraped(String recipeId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      QuerySnapshot<Map<String, dynamic>> existingScrapedRecipes =
          await FirebaseFirestore.instance
              .collection('scraped_recipes')
              .where('recipeId', isEqualTo: recipeId)
              .where('userId', isEqualTo: userId)
              .get();

      if (existingScrapedRecipes.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('scraped_recipes').add({
          'userId': userId,
          'recipeId': recipeId,
          'isScraped': true,
          'scrapedGroupName': '기본함',
          'scrapedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          isScraped = true;
        });
      } else {
        DocumentSnapshot<Map<String, dynamic>> doc =
            existingScrapedRecipes.docs.first;

        await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .doc(doc.id)
            .delete();
        setState(() {
          isScraped = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isScraped ? '스크랩이 추가되었습니다.' : '스크랩이 해제되었습니다.'),
        ));
      }
    } catch (e) {
      print('Error scraping recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('레시피 스크랩 중 오류가 발생했습니다.'),
      ));
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

  void _refreshRecipeData() {
    fetchRecipes(
        keywords: keywords,
        topIngredients: topIngredients,
        cookingMethods: this.selectedCookingMethods); // 레시피 목록을 다시 불러오는 메서드
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('레시피 검색'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: _searchController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: '검색어 입력',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 10.0),
                          ),
                          onSubmitted: (value) {
                            final trimmedValue = value.trim();
                            if (trimmedValue.isNotEmpty) {
                              setState(() {
                                if (!keywords.contains(trimmedValue)) {
                                  keywords.add(trimmedValue); // 새로운 키워드 추가
                                }
                              });
                              _saveSearchKeyword(trimmedValue); // 검색어 저장
                              fetchRecipes(
                                  keywords: keywords,
                                  topIngredients: topIngredients,
                                  cookingMethods: selectedCookingMethods
                              ); // 검색 실행
                              _searchController.clear();
                            }
                          }),
                    ),
                    SizedBox(width: 10),
                  ]),
            ),
            Padding(
              padding: const EdgeInsets.all(1.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  _buildFridgeIngredientsChip(), // 냉장고 재료 칩
                  ..._buildChips(), // 일반 키워드 칩
                ],
              ), // 키워드 목록 위젯
            ),
            Padding(
              padding: const EdgeInsets.all(3.0),
              child: _buildCategoryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChips() {
    final theme = Theme.of(context);
    List<String> keywordsChips = [];
    keywordsChips.addAll(keywords
        .where((ingredient) => !keywordsChips.contains(ingredient)));
    keywordsChips.removeWhere((ingredient) {
      if (topIngredients.contains(ingredient)) {
        return true;
      } else {
        return false;
      }
    });

    return keywordsChips
        .where((keyword) => keyword.trim().isNotEmpty) // 빈 문자열 필터링
        .map((keyword) {
      return Chip(
        label: Text(
          keyword,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12.0, // 기본 스타일에서 크기 조정
            color: theme.chipTheme.labelStyle?.color,
          ),
        ),
        deleteIcon: Icon(Icons.close, size: 16.0),
        onDeleted: () async {
          setState(() {// 키워드 삭제
            keywords.remove(keyword); // 키워드 삭제
          });
          await fetchRecipes(
                  keywords: keywords,
                  // cookingMethods: selectedCookingMethods,
                  // topIngredients: topIngredients
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            width: 0.5, // 테두리 두께 조정
          ),
        ),
      );
    }).toList(); // List<Widget> 반환
  }

  Widget _buildFridgeIngredientsChip() {
    final theme = Theme.of(context);
    if (useFridgeIngredientsState) {
      return Chip(
        label: Text(
          "냉장고 재료",
          style: TextStyle(
            fontSize: 12.0,
            color: theme.chipTheme.labelStyle!.color,
          ),
        ),
        deleteIcon: Icon(Icons.close, size: 16.0),
        onDeleted: () {
          print('keywords $keywords');
          setState(() {
            useFridgeIngredientsState = false;
            keywords.remove(fridgeIngredients);
            fetchRecipes(
                keywords: keywords,
                topIngredients: null,
                cookingMethods: this.selectedCookingMethods
            ); // 레시피 다시 불러오기
          });
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
          side: BorderSide(
            // color: Colors.grey, // 테두리 색상
            width: 0.5, // 테두리 두께 조정
          ),
        ),
      );
    } else {
      return SizedBox.shrink(); // 빈 공간 렌더링
    }
  }

  Widget _buildCategoryGrid() {
    if (matchingRecipes.isEmpty) {
      return Center(
        child: Text(
          '조건에 맞는 레시피가 없습니다.',
          style: TextStyle(
            fontSize: 14,
          ),
        ),
      );
    }

    return LayoutBuilder(
        builder: (context, constraints) {
          // 화면 너비에 따라 레이아웃 조정
          bool isWeb = constraints.maxWidth > 600;
          // int crossAxisCount = isWeb ? 2 : 1; // 웹에서는 두 열, 모바일에서는 한 열
          double aspectRatio = isWeb ? 1.2 : 3.0; // 웹에서는 더 넓은 비율
          double imageSize = isWeb ? 120.0 : 60.0; // 웹에서는 더 큰 이미지 크기

          return GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(8.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1, // 열 개수
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: isWeb ? 1.2 : (aspectRatio ?? 3.0), // 앱에서만 비율 적용
              mainAxisExtent: isWeb ? 200 : null, // 웹에서 세로 고정
            ),
            itemCount: matchingRecipes.length,
            itemBuilder: (context, index) {
              RecipeModel recipe = matchingRecipes[index];

              String recipeName = recipe.recipeName;
              double recipeRating = recipe.rating;
              bool hasMainImage = recipe.mainImages.isNotEmpty; // 이미지가 있는지 확인

              List<String> keywordList = [
                ...recipe.foods, // 이 레시피의 food 키워드들
                ...recipe.methods, // 이 레시피의 method 키워드들
                ...recipe.themes // 이 레시피의 theme 키워드들
              ];

              return FutureBuilder<bool>(
                future: loadScrapedData(recipe.id), // 각 레시피별로 스크랩 상태를 확인
                builder: (context, snapshot) {
                  bool isScraped = snapshot.data ?? false;

                  // 카테고리 그리드 렌더링
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReadRecipe(
                                recipeId: recipe.id, searchKeywords: keywords)),
                      ).then((result) {
                        if (result == true) {
                          _refreshRecipeData();
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        // border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(8.0),
                      ), // 카테고리 버튼 크기 설정

                      child: Row(
                        children: [
                          // 왼쪽에 정사각형 그림
                          Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              color: Colors.grey, // Placeholder color for image
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: hasMainImage
                                ? Image.network(
                                    recipe.mainImages[0],
                                    width: imageSize,
                                    height: imageSize,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.error);
                                    },
                                  )
                                : Icon(
                                    Icons.image, // 이미지가 없을 경우 대체할 아이콘
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                          ),
                          SizedBox(width: 10), // 간격 추가
                          // 요리 이름과 키워드를 포함하는 Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width:
                                          MediaQuery.of(context).size.width * 0.3,
                                      child: Text(
                                        recipeName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Spacer(),
                                    _buildRatingStars(recipeRating),
                                    IconButton(
                                      icon: Icon(
                                        isScraped
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        size: 20,
                                        color: Colors.black,
                                      ), // 스크랩 아이콘 크기 조정
                                      onPressed: () => _toggleScraped(recipe.id),
                                    ),
                                  ],
                                ),
                                // 키워드
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6.0,
                                          runSpacing: 4.0,
                                          children: keywordList.map((ingredient) {
                                            bool inFridge = fridgeIngredients.contains(ingredient);
                                            bool isKeyword = keywords.contains(ingredient) ||
                                                (useFridgeIngredientsState && topIngredients.contains(ingredient));;
                                            bool isFromPreferredFoods =
                                                itemsByCategory.values.any((list) => list.contains(ingredient));
                                            return Container(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 2.0, horizontal: 4.0),
                                              decoration: BoxDecoration(
                                                color: isKeyword ||
                                                        isFromPreferredFoods
                                                    ? Colors.lightGreen
                                                    : inFridge
                                                        ? Colors.grey
                                                        : Colors.transparent,
                                                border: Border.all(
                                                  color: Colors.grey,
                                                  width: 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: Text(
                                                ingredient,
                                                style: TextStyle(
                                                  fontSize: 12.0,
                                                  color: isKeyword ||
                                                          isFromPreferredFoods
                                                      ? Colors.white
                                                      : inFridge
                                                          ? Colors.white
                                                          : Colors.black,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            });
      }
    );
  }

  Widget _buildRatingStars(double rating) {
    int fullStars = rating.floor(); // 정수 부분의 별
    bool hasHalfStar = (rating - fullStars) >= 0.5; // 반 별이 필요한지 확인

    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(
            Icons.star,
            color: Colors.amber,
            size: 14,
          );
        } else if (index == fullStars && hasHalfStar) {
          return Icon(
            Icons.star_half,
            color: Colors.amber,
            size: 14,
          );
        } else {
          return Icon(
            Icons.star_border,
            color: Colors.amber,
            size: 14,
          );
        }
      }),
    );
  }
}
