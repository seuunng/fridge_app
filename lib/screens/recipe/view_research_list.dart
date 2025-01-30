import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:food_for_later_new/services/scraped_recipe_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse; // parse 메서드를 가져옵니다.
// import 'package:html/dom.dart'; // DOM 작업에 필요한 클래스 가져오기
import 'package:webview_flutter/webview_flutter.dart'; // HTTP 요청 처리

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
  final String apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
  final String cx = '36f9f7dce6df14fa0'; // Custom Search Engine ID
  bool useFridgeIngredientsState = false;
  // String? category = widget.category.isNotEmpty ? widget.category[0] : null;
  String userRole = '';
  TextEditingController _searchController = TextEditingController();
  WebViewController? _controller;
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
  String? selectedFridge = '';
  String? selected_fridgeId = '';
  String query = '';
  String mangaeQuery = '';
  List<Map<String, dynamic>> _mangaeresults = [];
  bool isLoading = false;
  int resultsPerPage = 10; // 한 번에 가져올 결과 개수
  int currentPage = 1;

  String searchKeyword = '';
  double rating = 0.0;
  bool isScraped = false;
  List<dynamic> _results = []; // 웹 검색 결과 저장

  Map<String, int> categoryPriority = {
    "육류": 10,
    "수산물": 9,
    "채소": 8,
    "과일": 7,
    "곡류": 6,
    "유제품": 5,
    "견과류": 5,
    "양념": 4,
    "가공식품": 3,
    "즉석식품": 2,
    "음료/주류": 1,
    "디저트/빵류": 1,
  };

  @override
  void initState() {
    super.initState();
    useFridgeIngredientsState = widget.useFridgeIngredients;
    keywords = widget.initialKeywords ?? [];
    keywords = widget.category ?? [];
    _loadPreferredFoodsByCategory().then((_) {
      _initializeSearch();
    });
    _loadSearchSettingsFromLocal();
    _loadFridgeItemsFromFirestore();
    _loadUserRole();
    _initializeFridgeData();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000)) // 투명 배경 설정
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('Page started loading: $url');
          },
          onPageFinished: (url) {
            print('Page finished loading: $url');
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('https://www.blockedsite.com')) {
              print('Blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://flutter.dev'));
    _updateQuery();
    _mangaeUpdateQuery();
  }

  void _updateQuery() {
    setState(() {
      final queryKeywords = [...keywords, ...topIngredients];
      if (!queryKeywords.contains("레시피")) queryKeywords.add("레시피");
      if (!queryKeywords.contains("요리")) queryKeywords.add("요리");
      if (!queryKeywords.contains("만드는법")) queryKeywords.add("만드는법");
      query = queryKeywords.join(" "); // 공백으로 연결
      // print('Updated query: $query');
    });
  }
  void _mangaeUpdateQuery() {
    setState(() {
      final queryKeywords = [...keywords, ...topIngredients];
      mangaeQuery = queryKeywords.join(" ");
      // print('Updated query: $query');
    });
  }

  //선택된 냉장고 불러오기
  Future<void> _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
    });

    if (selectedFridge != null) {
      selected_fridgeId = await fetchFridgeId(selectedFridge!);
    }
  }

  //선택된 냉장고의 Id불러오기
  Future<String?> fetchFridgeId(String fridgeName) async {
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

  //순차적으로 식품카테고리 불러오기
  Future<Map<String, String>> _loadIngredientCategoriesFromFirestore() async {
    try {
      return await _fetchIngredients();
    } catch (e) {
      print("Error loading ingredient categories: $e");
      return {};
    }
  }

  //사용자정의식품+기본식품 불러오기
  Future<Map<String, String>> _fetchIngredients() async {
    Set<String> userIngredients = {}; // 사용자가 추가한 재료
    Map<String, String> ingredientToCategory = {};

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // ✅ 1. 사용자 정의 foods 데이터 가져오기
      final userSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in userSnapshot.docs) {
        final foodName = doc['foodsName'] as String?;
        final category = doc['defaultCategory'] as String?;
        if (foodName != null) {
          userIngredients.add(foodName);
          if (category != null) {
            ingredientToCategory[foodName] = category;
          }
        }
      }

      // ✅ 2. 기본 식재료(default_foods) 가져오기
      final defaultSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      for (var doc in defaultSnapshot.docs) {
        final foodName = doc['foodsName'] as String?;
        final category = doc['defaultCategory'] as String?;
        if (foodName != null && !userIngredients.contains(foodName)) {
          ingredientToCategory[foodName] = category ?? "기타";
        }
      }

      return ingredientToCategory;
    } catch (e) {
      print("Error fetching ingredients: $e");
      return {};
    }
  }

  // 제외 키워드 카테고리 불러오기
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

  //순차적으로 냉장고속아이템 불러오기
  Future<void> _initializeFridgeData() async {
    await _loadSelectedFridge(); // selected_fridgeId를 먼저 로드
    if (selected_fridgeId != null) {
      await _loadFridgeItemsFromFirestore(); // selected_fridgeId를 사용해 데이터 로드
    } else {
      print('selected_fridgeId is null. Cannot load fridge items.');
    }
    if (useFridgeIngredientsState) {
      try {
        await _loadFridgeItemsFromFirestore();
        topIngredients = await _applyCategoryPriority(fridgeIngredients);
      } catch (error) {
        print('Error initializing fridge ingredients: $error');
      }
    }
  }

  // 냉장고 재료 불러오기
  Future<void> _loadFridgeItemsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .where('FridgeId', isEqualTo: selected_fridgeId)
          .get();

      List<String> validIngredients = [];

      for (var doc in snapshot.docs) {
        String itemName = doc['items'] as String;

        // 🔹 `foods`에서 먼저 조회
        final foodsSnapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where('foodsName', isEqualTo: itemName)
            .get();

        if (foodsSnapshot.docs.isNotEmpty) {
          validIngredients.add(itemName); // foods에 있으면 추가
          continue;
        }

        // 🔹 `default_foods`에서 조회
        final defaultFoodsSnapshot = await FirebaseFirestore.instance
            .collection('default_foods')
            .where('foodsName', isEqualTo: itemName)
            .get();

        if (defaultFoodsSnapshot.docs.isNotEmpty) {
          validIngredients.add(itemName); // default_foods에 있으면 추가
        }
      }

      setState(() {
        fridgeIngredients = validIngredients; // 유효한 아이템만 fridgeIngredients에 추가
      });
    } catch (e) {
      print('Error loading fridge items: $e');
    }
  }

  // 냉장고 재료 우선순위에 따라 10개 추리기
  Future<List<String>> _applyCategoryPriority(
      List<String> fridgeIngredients) async {
    // print('fridgeIngredients $fridgeIngredients');
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
    print('topIngredients $topIngredients');
    return topIngredients;
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

  //순차적으로 냉장고아이템중 10개 정하고 제외 키워드 식품카테고리 가져와서 레시피 검색하기
  Future<void> _initializeSearch() async {
    await _loadSearchSettingsFromLocal();

    if (selectedPreferredFoodCategory != null &&
        selectedPreferredFoodCategory!.isNotEmpty) {
      await loadRecipesByPreferredFoodsCategory();
    }
    await fetchRecipes(
        keywords: keywords,
        topIngredients: topIngredients,
        cookingMethods: this.selectedCookingMethods);
  }

  //제외 키워드 카테고리에 따른 레시피 불러오기
  Future<void> loadRecipesByPreferredFoodsCategory() async {
    try {
      List<String> allPreferredItems =
          itemsByCategory.values.expand((list) => list).toList();

      setState(() {
        excludeKeywords = [...?excludeKeywords, ...allPreferredItems];
      });

      await fetchRecipes(
          keywords: keywords,
          topIngredients: topIngredients,
          cookingMethods: this.selectedCookingMethods);
    } catch (e) {
      print('Error loading recipes by preferred foods category: $e');
    }
  }

  //제외검색어 검색하기
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

  //레시피검색하기
  Future<void> fetchRecipes({
    List<String>? keywords,
    List<String>? topIngredients,
    List<String>? cookingMethods,
    bool filterExcluded = true,
  }) async {
    try {
      keywords =
          keywords?.where((keyword) => keyword.trim().isNotEmpty).toList() ??
              [];
      // if ((keywords.isEmpty) &&
      //     (topIngredients == null || topIngredients.isEmpty) &&
      //     (excludeKeywords == null || excludeKeywords!.isEmpty) &&
      //     searchKeyword.isEmpty) {
      //   final querySnapshot = await _db.collection('recipe')
      //       .orderBy('date', descending: true)
      //       .get();
      //   setState(() {
      //     matchingRecipes = querySnapshot.docs
      //         .map((doc) =>
      //             RecipeModel.fromFirestore(doc.data() as Map<String, dynamic>))
      //         .toList();
      //   });
      //   return;
      // }
      final ingredientToCategory =
          await _loadIngredientCategoriesFromFirestore();

      final cleanedKeywords =
          keywords?.where((keyword) => keyword.trim().isNotEmpty).toList() ??
              [];
      final cleanedTopIngredients = topIngredients
              ?.where((ingredient) => ingredient.trim().isNotEmpty)
              .toList() ??
          [];

      List<DocumentSnapshot> keywordResults = [];
      List<DocumentSnapshot> topIngredientResults = [];
      List<DocumentSnapshot> titleResults = [];

      // Firestore 쿼리 실행
      if (cleanedKeywords.isNotEmpty) {
        final querySnapshots = await Future.wait([
          _db
              .collection('recipe')
              .where('foods', arrayContainsAny: cleanedKeywords)
              .get(),
          _db
              .collection('recipe')
              .where('methods', arrayContainsAny: cleanedKeywords)
              .get(),
          _db
              .collection('recipe')
              .where('themes', arrayContainsAny: cleanedKeywords)
              .get(),
        ]);
        for (var snapshot in querySnapshots) {
          keywordResults.addAll(snapshot.docs);
        }

        // ✅ foods + default_foods 에 포함된 레시피 검색
        final ingredientKeywords = cleanedKeywords
            .where((k) => ingredientToCategory.containsKey(k))
            .toList();

        if (ingredientKeywords.isNotEmpty) {
          final querySnapshot = await _db
              .collection('recipe')
              .where('foods', arrayContainsAny: ingredientKeywords)
              .get();
          keywordResults.addAll(querySnapshot.docs);
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
          _db
              .collection('recipe')
              .where('foods', arrayContainsAny: cleanedTopIngredients)
              .get(),
          _db
              .collection('recipe')
              .where('methods', arrayContainsAny: cleanedTopIngredients)
              .get(),
          _db
              .collection('recipe')
              .where('themes', arrayContainsAny: cleanedTopIngredients)
              .get(),
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
        if (!processedIds.contains(doc.id)) {
          processedIds.add(doc.id);
          combinedResults.add(doc);
        }
      }

      for (var doc in topIngredientResults) {
        if (!processedIds.contains(doc.id)) {
          processedIds.add(doc.id);
          combinedResults.add(doc);
        }
      }

      // 제외 키워드 필터링
      if (filterExcluded &&
          excludeKeywords != null &&
          excludeKeywords!.isNotEmpty) {
        combinedResults = _filterExcludedItems(
          docs: combinedResults,
          excludeKeywords: excludeKeywords!,
        );
      }

      // 정렬 추가: 최신순 -> 조회수 높은 순 -> 좋아요 많은 순
      combinedResults.sort((a, b) {
        final createdAtA = a['date'] as Timestamp?;
        final createdAtB = b['date'] as Timestamp?;
        final viewCountA = a['views'] as int? ?? 0;
        final viewCountB = b['views'] as int? ?? 0;
        final likeCountA = (a['rating'] as num?)?.toDouble() ?? 0.0; // 수정된 부분
        final likeCountB = (b['rating'] as num?)?.toDouble() ?? 0.0; // 수정된 부분

        // 최신순
        if (createdAtA != null && createdAtB != null) {
          final createdAtComparison = createdAtB.compareTo(createdAtA); // 내림차순
          if (createdAtComparison != 0) return createdAtComparison;
        }

        // 조회수 높은 순
        final viewCountComparison = viewCountB.compareTo(viewCountA);
        if (viewCountComparison != 0) return viewCountComparison;

        // 좋아요 많은 순
        return likeCountB.compareTo(likeCountA);
      });
      // 상태 업데이트
      setState(() {
        matchingRecipes = combinedResults
            .map((doc) =>
                RecipeModel.fromFirestore(doc.data() as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Error fetching recipes: $e');
    }
  }

  // 사용자의 역할 불러오기
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

  // 스크랩 여부 데이타 불러오기
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

  // 스크랩하기/해제하기
  void _toggleScraped(String recipeId) async {
    bool newState = await ScrapedRecipeService.toggleScraped(
      context,
      recipeId,
      (bool state) {
        setState(() {
          isScraped = state;
        });
      },
    );
  }
  Future<void> toggleMangnaeyaRecipeScraped(
      String title, String image, String link) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      // Firestore에서 해당 레시피의 스크랩 상태 확인
      final snapshot = await FirebaseFirestore.instance
          .collection('scraped_recipes')
          .where('userId', isEqualTo: userId)
          .where('recipeId', isEqualTo: link)
          .get();

      isScraped;
      if (snapshot.docs.isNotEmpty) {
        // 이미 스크랩된 경우 -> 스크랩 해제
        await snapshot.docs.first.reference.delete();
        print('스크랩 해제 완료');
        isScraped = false;
      } else {
        // 스크랩되지 않은 경우 -> 새로 스크랩 추가
        await FirebaseFirestore.instance.collection('scraped_recipes').add({
          'userId': userId,
          'link': link,
          'isScraped': true,
          'scrapedGroupName': '기본함',
          'scrapedAt': FieldValue.serverTimestamp(),
        });
        isScraped = true;
      }
    } catch (e) {
      print('Error toggling Mangnaeya recipe scrap: $e');
    }
  }
  // 검색한 키워드 저장하기
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

  // 레시피 다시 렌더링하기
  void _refreshRecipeData() {
    fetchRecipes(
        keywords: keywords,
        topIngredients: topIngredients,
        cookingMethods: this.selectedCookingMethods); // 레시피 목록을 다시 불러오는 메서드
  }

  Future<void> fetchSearchResultsFromWeb(String query) async {
    final String baseUrl =
        'https://www.googleapis.com/customsearch/v1?q=$query&key=$apiKey&cx=$cx';

    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 데이터를 변환하며 null-safe 접근 및 기본값 설정
        final items = (data['items'] as List<dynamic>?)
            ?.map((item) => {
          'title': item['title'] ?? 'Unknown Title',
          'snippet' : item['snippet'] ?? 'No description',
          'imageUrl': item['pagemap']?['cse_thumbnail']?[0]?['src'] ??
              'https://via.placeholder.com/150', // 기본 이미지
          'link': item['link'] ?? '',
        })
            .toList() ??
            [];

        setState(() {
          _results = items; // 상태 업데이트
        });
      } else {
        throw Exception('웹 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      print("웹 검색 중 오류 발생: $e");
      setState(() {
        _results = []; // 오류 시 빈 리스트로 설정
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecipesFromMangnaeya(
      String query) async {
    setState(() {
      isLoading = true; // 검색 시작 시 로딩 상태 활성화
    });
    try {
    final String url = 'https://www.10000recipe.com/recipe/list.html?q=$query';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parse(response.body);

        // 첫 번째 레시피의 상세 링크를 찾기
        final recipeLinks = document.querySelectorAll('.common_sp_link');
        final recipeTitles =
            document.querySelectorAll('.common_sp_caption_tit');
        if (recipeLinks.isEmpty || recipeTitles.isEmpty) {
          return [];
        }

        List<Map<String, dynamic>> recipes = [];
        for (int i = 0; i < recipeLinks.length; i++) {
          final link =
              'https://www.10000recipe.com${recipeLinks[i].attributes['href']}';

          final recipeResponse = await http.get(Uri.parse(link));

          if (recipeResponse.statusCode == 200) {
            final recipeDocument = parse(recipeResponse.body);

            final title = recipeDocument
                    .querySelector('.view2_summary.st3 h3')
                    ?.text
                    .trim() ??
                'Unknown';
            final ingredientsElements =
                recipeDocument.querySelectorAll('.ready_ingre3 > ul > li');
            final ingredients = ingredientsElements
                .map((e) =>
                    e.text.trim().split(RegExp(r'\s+'))[0]) // 공백 전 첫 단어만 가져오기
                .where((ingredient) => !ingredient.endsWith("구매"))
                .toList();
            final imageElement =
                recipeDocument.querySelector('.centeredcrop img');
            final imageUrl = imageElement?.attributes['src'] ?? '';

            // 반환 데이터
            recipes.add({
              'title': title,
              'ingredients': ingredients,
              'image': imageUrl,
              'link': link,
            });
          }
        }
        return recipes; // 모든 레시피 데이터 반환
      }
    } catch (e) {
      print('Error fetching recipes from Mangnaeya: $e');
    } finally {
      setState(() {
        isLoading = false; // 로딩 상태 비활성화
      });
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final queryKeywords = [...keywords, ...topIngredients];
    //
    // // "레시피"와 "만드는법" 키워드 추가
    // if (!queryKeywords.contains("레시피")) queryKeywords.add("레시피");
    // if (!queryKeywords.contains("요리")) queryKeywords.add("요리");
    // if (!queryKeywords.contains("만드는법")) queryKeywords.add("만드는법");
    // print('queryKeywords $queryKeywords');
    // final query = queryKeywords.join(" "); // 키워드를 공백으로 연결
    // print('query $query');
    return Scaffold(
      appBar: AppBar(
        title: Text('레시피 검색'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // 로딩 중일 때 로딩 스피너 표시
          : SingleChildScrollView(
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
                          style: TextStyle(
                              color: theme.chipTheme.labelStyle!.color),
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
                                  cookingMethods:
                                      selectedCookingMethods); // 검색 실행
                              _searchController.clear();
                            }
                          }),
                    ),
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
            if (_mangaeresults.isNotEmpty)
              _buildMangnaeyaSearchResults(_mangaeresults),
            if (_results.isNotEmpty) _buildWebSearchResults(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (matchingRecipes.length < 30 &&
                _results.isEmpty &&
                _mangaeresults.isEmpty)
              Container(
                color: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: NavbarButton(
                    buttonTitle: '웹으로 검색하기',
                    onPressed: () async {
                      if (keywords.isNotEmpty || topIngredients.isNotEmpty) {
                        // final refinedQueryKeywords = [...queryKeywords];
                        // print('queryKeywords $queryKeywords');
                        // print('refinedQueryKeywords $refinedQueryKeywords');
                        // final query = refinedQueryKeywords.join(" ");
                        _mangaeUpdateQuery();
                        final mangnaeyaRecipes =
                            await fetchRecipesFromMangnaeya(mangaeQuery);
                        setState(() {
                          _mangaeresults = mangnaeyaRecipes; // 만개의 레시피 결과 저장
                        });
                        await fetchSearchResultsFromWeb(query); // 웹 검색 함수 호출
                      } else {
                        print("검색할 키워드가 없습니다.");
                      }
                    },
                  ),
                ),
              ),
            if (userRole != 'admin' && userRole != 'paid_user')
              SafeArea(
                bottom: false, // 하단 여백 제거
                child: BannerAdWidget(),
              ),
          ]),
    );
  }

  List<Widget> _buildChips() {
    final theme = Theme.of(context);
    List<String> keywordsChips = [];
    keywordsChips.addAll(
        keywords.where((ingredient) => !keywordsChips.contains(ingredient)));
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
          setState(() {
            // 키워드 삭제
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
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12.0,
            color: theme.chipTheme.labelStyle!.color,
          ),
        ),
        deleteIcon: Icon(Icons.close, size: 16.0),
        onDeleted: () {
          setState(() {
            useFridgeIngredientsState = false;
            keywords.remove(fridgeIngredients);
            fetchRecipes(
                keywords: keywords,
                topIngredients: null,
                cookingMethods: this.selectedCookingMethods); // 레시피 다시 불러오기
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
    final theme = Theme.of(context);
    if (matchingRecipes.isEmpty && _results.isEmpty && _mangaeresults.isEmpty) {
      return Center(
        child: Text(
          '조건에 맞는 레시피가 없습니다.',
          style:
              TextStyle(
                  fontSize: 14,
                  color: theme.chipTheme.labelStyle!.color
              ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      // 화면 너비에 따라 레이아웃 조정
      bool isWeb = constraints.maxWidth > 600;
      // int crossAxisCount = isWeb ? 2 : 1; // 웹에서는 두 열, 모바일에서는 한 열
      double aspectRatio = isWeb ? 1.2 : 3.0; // 웹에서는 더 넓은 비율
      double imageSize = isWeb ? 120.0 : 60.0; // 웹에서는 더 큰 이미지 크기

      return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 8.0),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3), // 그림자 위치
                        ),
                      ],
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
                                    width: MediaQuery.of(context).size.width *
                                        0.25,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6.0,
                                        runSpacing: 4.0,
                                        children: keywordList.map((ingredient) {
                                          bool inFridge = fridgeIngredients
                                              .contains(ingredient);
                                          bool isKeyword = keywords
                                                  .contains(ingredient) ||
                                              (useFridgeIngredientsState &&
                                                  topIngredients
                                                      .contains(ingredient));
                                          ;
                                          bool isFromPreferredFoods =
                                              itemsByCategory.values.any(
                                                  (list) => list
                                                      .contains(ingredient));
                                          return Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 2.0, horizontal: 4.0),
                                            decoration: BoxDecoration(
                                              color: isKeyword ||
                                                      isFromPreferredFoods ||
                                                      topIngredients.contains(
                                                          ingredient) // 추가된 조건
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
    });
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

  Widget _buildWebSearchResults() {
    final theme = Theme.of(context);
    if (_results.isEmpty) {
      return Center(
          child: Text(
        '웹 검색 결과가 없습니다.',
        style:
            TextStyle(fontSize: 14, color: theme.chipTheme.labelStyle!.color),
      ));
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
        physics: BouncingScrollPhysics(), // 스크롤 가능하게 설정
        padding: EdgeInsets.symmetric(horizontal: 11.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1, // 한 줄에 하나씩 표시
          crossAxisSpacing: 8.0, // 아이템 간 가로 간격
          mainAxisSpacing: 8.0, // 아이템 간 세로 간격
          childAspectRatio: isWeb ? 1.2 : (aspectRatio ?? 3.0), // 세로 비율 조정
          mainAxisExtent: isWeb ? 200 : null, // 웹에서 세로 고정
        ),
        itemCount: _results.length,
        itemBuilder: (context, index) {
            final result = _results[index];
            final title = result['title'] ?? 'No title available';
            final snippet = result['snippet'] ?? 'No description available';
            final link = result['link'] ?? '';
            final imageUrl = result['imageUrl'] ??
                'https://seuunng.github.io/food_for_later_policy/favicon.png'; // 기본 이미지

          return GestureDetector(
            onTap: () {
              if (link.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text(title)),
                      body: WebViewWidget(
                        controller: WebViewController()
                          ..setJavaScriptMode(JavaScriptMode.unrestricted)
                          ..loadRequest(Uri.parse(link)),
                      ),
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // 그림자의 위치 조정
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 이미지
                  Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: Colors.grey[300],
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.0), // 이미지와 텍스트 간격
                  // 텍스트 영역
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // SizedBox(height: 8.0),
                        Text(
                          snippet,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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

  Widget _buildMangnaeyaSearchResults(List<Map<String, dynamic>> recipes) {
    if (recipes.isEmpty) {
      return Center(
        child: Text(
          '검색된 레시피가 없습니다.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // 'constraints'로 수정
        bool isWeb = constraints.maxWidth > 600; // 올바르게 수정된 변수 이름
        double aspectRatio = isWeb ? 1.2 : 3.0; // 웹에서는 더 넓은 비율
        double imageSize = isWeb ? 120.0 : 60.0; // 웹에서는 더 큰 이미지
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 3.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            // 열 개수
            crossAxisSpacing: 2.0,
            mainAxisSpacing: 2.0,
            childAspectRatio: isWeb ? 1.2 : (aspectRatio ?? 3.0),
            // 앱에서만 비율 적용
            mainAxisExtent: isWeb ? 200 : null, // 웹에서 세로 고정
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final String title = recipe['title'] ?? '제목 없음';
            final List<String> ingredients = recipe['ingredients'] ?? [];
            final String link = recipe['link'] ?? '';
            final String image = recipe['image'] ?? '';
            return GestureDetector(
              onTap: () {
                // 타일 클릭 시 WebView 페이지로 이동
                if (link.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: Text(title),
                        ),
                        body: WebViewWidget(
                          controller: WebViewController()
                            ..setJavaScriptMode(JavaScriptMode.unrestricted)
                            ..loadRequest(Uri.parse(link)),
                        ),
                      ),
                    ),
                  );
                } else {
                  print('Link is empty or invalid');
                }
              },
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3), // 그림자 위치
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 이미지
                    Image.network(
                      image,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image, // 기본 이미지 대체
                          size: 40,
                          color: Colors.grey,
                        );
                      },
                    ),
                    SizedBox(width: 10.0), // 간격 추가

                    // 제목 및 재료
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 레시피 제목
                          Row(
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width *
                                    0.5,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isScraped
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 20,
                                  color: Colors.black,
                                ), // 스크랩 아이콘 크기 조정
                                onPressed: () {
                                  toggleMangnaeyaRecipeScraped(title, image, link);
                                },
                              ),
                            ],
                          ),
                            ],
                          ),
                          // SizedBox(height: 8.0), // 간격 추가

                          // 재료 칩
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6.0,
                                    runSpacing: 4.0,
                                    children: ingredients.map((ingredient) {
                                      bool inFridge = fridgeIngredients
                                          .contains(ingredient);
                                      bool isKeyword =
                                          keywords.contains(ingredient) ||
                                              (useFridgeIngredientsState &&
                                                  topIngredients
                                                      .contains(ingredient));
                                      ;
                                      bool isFromPreferredFoods =
                                          itemsByCategory.values.any((list) =>
                                              list.contains(ingredient));
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 2.0, horizontal: 4.0),
                                        decoration: BoxDecoration(
                                          // color: Colors.transparent,
                                          color: isKeyword ||
                                                  isFromPreferredFoods ||
                                                  topIngredients.contains(
                                                      ingredient) // 추가된 조건
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
      },
    );
  }
}
