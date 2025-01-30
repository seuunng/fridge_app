import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/screens/recipe/add_recipe.dart';
import 'package:food_for_later_new/screens/recipe/add_recipe_review.dart';
import 'package:food_for_later_new/screens/recipe/full_screen_image_view.dart';
import 'package:food_for_later_new/screens/recipe/recipe_review.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/screens/recipe/share_options.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:food_for_later_new/screens/records/records_calendar_view.dart';
import 'package:food_for_later_new/screens/records/view_record_main.dart';
import 'package:food_for_later_new/screens/settings/feedback_submission.dart';
import 'package:food_for_later_new/services/scraped_recipe_service.dart';
import 'package:uuid/uuid.dart';

class ReadRecipe extends StatefulWidget {
  final String recipeId;
  final List<String> searchKeywords;

  ReadRecipe({
    required this.recipeId,
    required this.searchKeywords,
  });

  @override
  _ReadRecipeState createState() => _ReadRecipeState();
}

class _ReadRecipeState extends State<ReadRecipe> {
  final firebase_auth.User? currentUser = FirebaseAuth.instance.currentUser;
  late String userId;
  late String fromEmail;
  late String toEmail;
  late String nickname;
  int scrapedCount = 0; // 스크랩 수
  int likedCount = 0;

  List<String> ingredients = []; // 재료 목록
  String recipeName = '';
  int views = 0;
  List<String> mainImages = [];
  List<bool> selectedIngredients = []; // 선택된 재료 상태 저장
  List<String> shoppingList = []; // 장바구니 목록

  List<String> fridgeIngredients = []; // 냉장고에 있는 재료들
  List<String> searchKeywords = []; // 검색 키워드

  bool isLiked = false; // 좋아요 상태
  bool isScraped = false; // 스크랩 상태

  late PageController _pageController;
  int _currentIndex = 0;

  bool isAdmin = false;
  late String recipeUrl;

  String userRole = '';

  @override
  void initState() {
    super.initState();

    // 유저 정보 초기화
    userId = currentUser?.uid ?? '';
    fromEmail = currentUser?.email ?? '이메일 없음';
    toEmail = currentUser?.email ?? '이메일 없음';
    nickname = '닉네임 없음'; // 기본값 설정

    loadUserData(); // Firestore에서 닉네임 로드
    _checkAdminRole();
    searchKeywords = widget.searchKeywords;
    selectedIngredients = List.generate(ingredients.length, (index) {
      return !fridgeIngredients.contains(ingredients[index]);
    });
    _fetchInitialRecipeName();
    loadScrapedData(widget.recipeId);
    loadLikedData(widget.recipeId);
    _increaseViewCount(widget.recipeId);
    _loadUserRole();
    _pageController = PageController(initialPage: 0);
    recipeUrl = 'https://food-for-later.web.app/recipe/${widget.recipeId}';
    _loadScrapedAndLikedCounts();
  }

  @override
  void dispose() {
    _pageController.dispose(); // 페이지 컨트롤러 해제
    super.dispose();
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
  void loadUserData() async {
    if (userId.isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (userDoc.exists) {
        setState(() {
          nickname = userDoc.data()?['nickname'] ?? '닉네임 없음';
        });
      } else {
        setState(() {
          nickname = '닉네임 없음';
        });
      }
    }
  }
  void _loadScrapedAndLikedCounts() async {
    int scraped = await _getScrapedCount(widget.recipeId);
    int liked = await _getLikedCount(widget.recipeId);

    setState(() {
      scrapedCount = scraped;
      likedCount = liked;
    });
  }
  Future<void> _checkAdminRole() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          isAdmin = userDoc.data()?['role'] == 'admin'; // 관리자 역할 확인
        });
      }
    } catch (e) {
      print("Error checking admin role: $e");
    }
  }
  Future<Map<String, dynamic>> _fetchRecipeData() async {
    return await fetchRecipeData(widget.recipeId); // Firestore에서 데이터 가져오기
  }
  Future<Map<String, dynamic>> fetchRecipeData(String recipeId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('recipe')
          .doc(recipeId)
          .get();

      return snapshot.data() ?? {};
    } catch (e) {
      print("Error fetching recipe data: $e");
      return {};
    }
  }
  Future<void> _fetchInitialRecipeName() async {
    var data = await fetchRecipeData(widget.recipeId);
    setState(() {
      recipeName = data['recipeName'] ?? 'Unnamed Recipe';
      mainImages =
          List<String>.from(data['mainImages'] ?? []); // mainImages 업데이트
    });
  }
  Future<void> loadScrapedData(String recipeId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('scraped_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        isScraped = snapshot.docs.first.data()['isScraped'] ?? false;
      });
    } catch (e) {
      print("Error fetching recipe isScraped data: $e");
    }
  }
  Future<void> loadLikedData(String recipeId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('liked_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        isLiked = snapshot.docs.first.data()['isLiked'] ?? false;
      });
    } catch (e) {
      print("Error fetching recipe isLiked data: $e");
    }
  }

  void _addToShoppingList() async {
    // 아이템을 컬렉션에 저장
    Future<void> _addToShoppingList(List<String> ingredients) async {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      try {
        for (int i = 0; i < ingredients.length; i++) {
          if (selectedIngredients[i] &&
              !shoppingList.contains(ingredients[i])) {
            final existingItemSnapshot = await FirebaseFirestore.instance
                .collection('shopping_items')
                .where('items', isEqualTo: ingredients[i])
                .where('userId', isEqualTo: userId) // 현재 유저의 아이템만 확인
                .get();

            if (existingItemSnapshot.docs.isEmpty) {
              await FirebaseFirestore.instance
                  .collection('shopping_items')
                  .add({
                'items': ingredients[i],
                'isChecked': false, // 체크되지 않은 상태로 저장
                'userId': userId, // 사용자 ID
              });
            } else {
              print('"${ingredients[i]}"이(가) 이미 장바구니에 있습니다.');
            }
          }
        }
      } catch (e) {
        print('Error adding items to shopping list: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('장바구니에 추가하는 도중 오류가 발생했습니다.'),
        ));
      }
    }
    //장바구니에 넣을 아이템 선택하는 다이어로그 UI
    void _showAddToShoppingListDialog(List<String> ingredients) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Text(
                  '장바구니에 추가할 재료 선택',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ingredients.map((ingredient) {
                      int index = ingredients.indexOf(ingredient);
                      if (!fridgeIngredients.contains(ingredient)) {
                        return CheckboxListTile(
                          title: Text(ingredient),
                          value: selectedIngredients[index],
                          onChanged: (bool? value) {
                            setState(() {
                              selectedIngredients[index] = value ?? false;
                            });
                          },
                        );
                      }
                      return SizedBox.shrink();
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text('취소'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('추가'),
                    onPressed: () {
                      _addToShoppingList(ingredients);
                      Navigator.of(context).pop();
                      if (selectedIngredients.any((selected) => selected)) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('선택한 재료를 장바구니에 추가했습니다.'),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('추가할 재료가 없습니다.'),
                        ));
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> _loadFridgeItemsFromFirestore() async {
      try {
        var recipeData = await fetchRecipeData(widget.recipeId);
        List<String> ingredients = List<String>.from(recipeData['foods'] ?? []);

        final snapshot =
            await FirebaseFirestore.instance.collection('fridge_items').get();

        setState(() {
          fridgeIngredients =
              snapshot.docs.map((doc) => doc['items'] as String).toList();
          selectedIngredients = List<bool>.filled(ingredients.length, true);
        });

        if (ingredients.isNotEmpty) {
          _showAddToShoppingListDialog(ingredients);
        } else {
          print('Ingredients 배열이 비어있습니다.');
        }
      } catch (e) {
        print('Error loading fridge items: $e');
      }
    }

    _loadFridgeItemsFromFirestore(); // 데이터를 모두 로드한 후에 다이얼로그를 표시
  }

  void _deleteRecipe() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '레시피 삭제',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '정말 이 레시피를 삭제하시겠습니까?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop(); // 대화상자 닫기
              },
            ),
            TextButton(
              child: Text('삭제'),
              onPressed: () async {
                // bool isScraped = recipe[index]['isScraped'] ?? false;
                // bool isLiked = recipe[index]['isLiked'] ?? false;

                try {
                  await FirebaseFirestore.instance
                      .collection('recipe')
                      .doc(widget.recipeId)
                      .delete();

                  // 관련된 스크랩된 데이터 삭제
                  QuerySnapshot<Map<String, dynamic>> scrapedRecipesSnapshot =
                      await FirebaseFirestore.instance
                          .collection('scraped_recipes')
                          .where('recipeId', isEqualTo: widget.recipeId)
                          .get();

                  for (var doc in scrapedRecipesSnapshot.docs) {
                    await FirebaseFirestore.instance
                        .collection('scraped_recipes')
                        .doc(doc.id)
                        .delete();
                  }

                  // 관련된 좋아요 데이터 삭제
                  QuerySnapshot<Map<String, dynamic>> likedRecipesSnapshot =
                      await FirebaseFirestore.instance
                          .collection('liked_recipes')
                          .where('recipeId', isEqualTo: widget.recipeId)
                          .get();

                  for (var doc in likedRecipesSnapshot.docs) {
                    await FirebaseFirestore.instance
                        .collection('liked_recipes')
                        .doc(doc.id)
                        .delete();
                  }

                  Navigator.of(context).pop();
                  // 상위 페이지로 결과 전달 및 페이지 나가기
                  Navigator.of(context).pop(); // AlertDialog 닫기
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('레시피가 삭제되었습니다.'),
                  ));
                  Navigator.of(context).pop(true); // 삭제 성공 신호를 상위 페이지로 전달
                } catch (e) {
                  print('레시피 삭제 실패: $e');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('레시피 삭제에 실패했습니다. 다시 시도해주세요.'),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<String> _collectAllImages(
      List<String> mainImages, List<Map<String, String>> steps) {
    List<String> allImages = [];
    allImages.addAll(mainImages); // 메인 이미지 추가
    for (var step in steps) {
      if (step['image'] != null && step['image']!.isNotEmpty) {
        allImages.add(step['image']!); // 조리 과정 이미지 추가
      }
    }
    return allImages;
  }
  Future<void> _increaseViewCount(String recipeId) async {
    try {
      DocumentReference recipeDoc =
      FirebaseFirestore.instance.collection('recipe').doc(recipeId);

      FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(recipeDoc);

        if (!snapshot.exists) {
          throw Exception("레시피 문서가 존재하지 않습니다.");
        }

        int currentViewCount = snapshot['views'] ?? 0;

        // 조회수 증가
        transaction.update(recipeDoc, {'views': currentViewCount + 1});
      });
    } catch (e) {
      print("조회수 증가 중 오류 발생: $e");
    }
  }

  void _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == 'guest@foodforlater.com') {
      // 🔹 방문자(게스트) 계정이면 스크랩 차단 및 안내 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후 레시피를 좋아요 할 수 있습니다.')),
      );
      return; // 🚫 여기서 함수 종료 (스크랩 기능 실행 안 함)
    }

    final userId = user.uid;

    try {
      // 스크랩 상태 확인을 위한 쿼리
      QuerySnapshot<Map<String, dynamic>> existingScrapedRecipes =
      await FirebaseFirestore.instance
          .collection('liked_recipes')
          .where('recipeId', isEqualTo: widget.recipeId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingScrapedRecipes.docs.isEmpty) {
        // 스크랩이 존재하지 않으면 새로 추가
        await FirebaseFirestore.instance.collection('liked_recipes').add({
          'userId': userId,
          'recipeId': widget.recipeId,
          'isLiked': true,
        });

        setState(() {
          isLiked = true; // 스크랩 상태로 변경
        });
      } else {
        DocumentSnapshot<Map<String, dynamic>> doc =
            existingScrapedRecipes.docs.first;
        bool currentIsScraped = doc.data()?['isLiked'] ?? false;

        await FirebaseFirestore.instance
            .collection('liked_recipes')
            .doc(doc.id)
            .update({'isLiked': !currentIsScraped});

        setState(() {
          isLiked = !currentIsScraped; // 스크랩 상태 변경
        });
      }
    } catch (e) {
      print('Error scraping recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('레시피 스크랩 중 오류가 발생했습니다.'),
      ));
    }
  }

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

  Future<int> _getScrapedCount(String recipeId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('scraped_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('isScraped', isEqualTo: true)
          .get();
      return snapshot.docs.length; // 스크랩된 문서 수 반환
    } catch (e) {
      print('Error fetching scraped count: $e');
      return 0; // 에러 시 0 반환
    }
  }

  Future<int> _getLikedCount(String recipeId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('liked_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('isLiked', isEqualTo: true)
          .get();
      return snapshot.docs.length; // 좋아요된 문서 수 반환
    } catch (e) {
      print('Error fetching liked count: $e');
      return 0; // 에러 시 0 반환
    }
  }

  void _refreshRecipeData() async {
    var newData = await fetchRecipeData(widget.recipeId);

    setState(() {
      recipeName = newData['recipeName'] ?? 'Unnamed Recipe';
      ingredients = List<String>.from(newData['foods'] ?? []);
      mainImages = List<String>.from(newData['mainImages'] ?? []);
      selectedIngredients = List.generate(ingredients.length, (index) {
        return !fridgeIngredients.contains(ingredients[index]);
      });
    });
  }

  DateTime getTomorrowDate() {
    return DateTime.now().add(Duration(days: 1));
  }

  void _saveRecipeForTomorrow() async {
    try {
      // 레시피 데이터를 불러옵니다.
      var recipeData = await fetchRecipeData(widget.recipeId);

      // 내일 날짜로 저장
      DateTime tomorrow = getTomorrowDate().toUtc();

      // records 배열 구성
      List<Map<String, dynamic>> records = [
        {
          'unit': '레시피 보기',  // 고정값 혹은 다른 값으로 대체 가능
          'contents': recipeData['recipeName'] ?? 'Unnamed Recipe',
          'images': recipeData['mainImages'] ?? [], // 이미지 배열
          'recipeId': widget.recipeId,
        }
      ];

      // 저장할 데이터 구조 정의
      Map<String, dynamic> recordData = {
        'id': Uuid().v4(),  // 고유 ID 생성
        'date': Timestamp.fromDate(tomorrow),
        'userId': userId,
        'color': '#88E09F',  // 고정된 색상 코드 또는 동적 값 사용 가능
        'zone': '레시피',  // 고정값 또는 다른 값으로 대체 가능
        'records': records,
      };

      // Firestore에 저장
      await FirebaseFirestore.instance.collection('record').add(recordData);

      // 저장 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레시피가 내일 날짜로 기록되었습니다.'),
          action: SnackBarAction(
            label: '기록 보기',
            onPressed: () {
              // 기록 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewRecordMain(),
                ),
              );
            },
          ),),
      );
    } catch (e) {
      print('레시피 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레시피 저장에 실패했습니다. 다시 시도해주세요.')
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                recipeName,
                maxLines: 1, // 최대 1줄만 보여줌
                overflow: TextOverflow.ellipsis, // 넘칠 경우 말줄임표로 표시
              ),
            ),
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min, // 최소 공간만 차지하도록 설정
                  children: [
                    IconButton(
                      visualDensity: const VisualDensity(horizontal: -4),
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border, // 상태에 따라 아이콘 변경
                        size: 26, // 아이콘 크기
                      ),
                      onPressed: _toggleLike,
                    ), // 아이콘과 텍스트 사이 간격 조정
                    Text(
                      '$likedCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4),
              icon: Icon(isScraped ? Icons.bookmark : Icons.bookmark_border,
                  size: 26), // 스크랩 아이콘 크기 조정
              onPressed: () => _toggleScraped(widget.recipeId),
            ),
            IconButton(
              visualDensity: const VisualDensity(horizontal: -4),
              icon: Icon(Icons.calendar_today, size: 25), // 스크랩 아이콘 크기 조정
              onPressed: () => _saveRecipeForTomorrow(),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchRecipeData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (snapshot.hasData && snapshot.data != null) {
            // Firestore에서 받아온 레시피 데이터를 사용
            var data = snapshot.data!;
            List<String> ingredients = List<String>.from(data['foods'] ?? []);
            List<String> themes = List<String>.from(data['themes'] ?? []);
            List<String> methods = List<String>.from(data['methods'] ?? []);
            List<Map<String, String>> steps = List<Map<String, String>>.from(
                (data['steps'] as List<dynamic>).map((step) {
              return Map<String, String>.from(step as Map<String, dynamic>);
            }));
            recipeName = data['recipeName'] ?? 'Unnamed Recipe';
            List<String> mainImages =
                List<String>.from(data['mainImages'] ?? []);

            final bool isOwner = userId == data['userID'];
            final bool showAdminOptions = isAdmin || isOwner;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainImageSection(mainImages, steps),
                  _buildInfoSection(data),
                  _buildIngredientsSection(ingredients),
                  _buildCookingStepsSection(methods),
                  _buildThemesSection(themes),
                  _buildRecipeSection(steps),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Spacer(),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4),
                        icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: theme.colorScheme.onSurface), // 스크랩 아이콘 크기 조정
                        onPressed: _toggleLike,
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4),
                        icon: Icon(
                          isScraped ? Icons.bookmark : Icons.bookmark_border,
                          size: 18,
                            color: theme.colorScheme.onSurface
                        ), // 스크랩 아이콘 크기 조정
                        onPressed: () => _toggleScraped(widget.recipeId),
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4),
                        icon: Icon(Icons.calendar_today, size: 18), // 스크랩 아이콘 크기 조정
                        onPressed: () => _saveRecipeForTomorrow(),
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4),
                        icon: Icon(Icons.share, size: 18,
                            color: theme.colorScheme.onSurface), // 스크랩 아이콘 크기 조정
                        onPressed: () {
                          showShareOptions(context, fromEmail, toEmail, nickname, recipeName, recipeUrl);
                        },
                      ),
                      IconButton(
                        visualDensity: const VisualDensity(horizontal: -4),
                        icon: Icon(Icons.feedback_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurface), // 스크랩 아이콘 크기 조정
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => FeedbackSubmission(
                                        postNo: widget.recipeId,
                                        postType: '레시피',
                                      )));
                        },
                      ),
                      SizedBox(width: 4),
                      if (isAdmin || isOwner)
                        Row(children: [
                          Text('|',
                              style: TextStyle(color: theme.colorScheme.onSurface)),
                          SizedBox(width: 4),
                          Container(
                            child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            AddRecipe(recipeData: {
                                              'id': widget.recipeId,
                                              'recipeName': recipeName,
                                              'mainImages': List<String>.from(
                                                  data['mainImages'] ?? []),
                                              'ingredients': ingredients,
                                              'themes': themes,
                                              'methods': methods,
                                              'serving': data['serving'],
                                              'cookTime': data['time'],
                                              'difficulty': data['difficulty'],
                                              'steps': steps
                                                  .map((step) => {
                                                        'description': step[
                                                                'description'] ??
                                                            '',
                                                        'image':
                                                            step['image'] ?? '',
                                                      })
                                                  .toList(),
                                            })),
                                  ).then((result) {
                                    if (result == true) {
                                      // 레시피 목록을 다시 불러오거나 화면을 새로고침
                                      _refreshRecipeData(); // 레시피 데이터를 새로고침하는 메서드
                                    }
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, // 버튼 패딩을 없앰
                                  minimumSize: Size(40, 30), // 최소 크기 설정
                                  tapTargetSize: MaterialTapTargetSize
                                      .shrinkWrap, // 터치 영역 최소화
                                ),
                                child: Text('수정')),
                          ),
                          Container(
                            child: TextButton(
                                onPressed: _deleteRecipe,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero, // 버튼 패딩을 없앰
                                  minimumSize: Size(40, 30), // 최소 크기 설정
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 터치 영역 최소화
                                ),
                                child: Text('삭제')),
                          ),
                        ]),
                    ],
                  ),
                  RecipeReview(
                    recipeId: widget.recipeId,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
                    mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
                    children: [
                      Container(
                        color: Colors.transparent,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: NavbarButton(
                            buttonTitle: '리뷰쓰기',
                            onPressed: () {
                              final user = FirebaseAuth.instance.currentUser;

                              if (user == null || user.email == 'guest@foodforlater.com') {
                                // 🔹 방문자(게스트) 계정이면 접근 차단 및 안내 메시지 표시
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인 후 리뷰를 작성할 수 있습니다.')),
                                );
                                return; // 🚫 여기서 함수 종료 (페이지 이동 X)
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddRecipeReview(
                                    recipeId: widget.recipeId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      if (userRole != 'admin' && userRole != 'paid_user')
                        SafeArea(
                          bottom: false, // 하단 여백 제거
                          child: BannerAdWidget(),
                        ),
                    ],
                  )
                ],
              ),
            );
          } else {
            return Center(child: Text("레시피를 찾을 수 없습니다."));
          }
        },
      ),
    );
  }

  Widget _buildMainImageSection(
      List<String> mainImages, List<Map<String, String>> steps) {
    if (mainImages.isEmpty) {
      return Container(
        height: 400,
        // color: Colors.grey,
        child: Icon(Icons.image, color: Colors.white, size: 100),
      );
    }

    final allImages = _collectAllImages(mainImages, steps); // 모든 이미지를 수집

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImageView(
              images: allImages,
              initialIndex: 0, // 메인 이미지부터 시작
            ),
          ),
        );
      },
      child: Column(
        children: [
          SizedBox(
            height: 400,
            child: PageView.builder(
              controller: _pageController,
              itemCount: mainImages.length,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  mainImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                        child: Icon(Icons.error, color: Colors.red, size: 100));
                  },
                );
              },
            ),
          ),
          SizedBox(height: 10,),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(mainImages.length, (index) {
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 5),
                width:  _currentIndex == index ? 12 : 8,
                height:  _currentIndex == index ? 12 : 8,
                decoration: BoxDecoration(
                  color:  _currentIndex == index ? Colors.black : Colors.grey,
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> data) {
    final theme = Theme.of(context);
    int servings = data['serving'] ?? 0;
    int cookTime = data['time'] ?? 0;
    String difficulty = data['difficulty'] ?? '중';
    int viewCount = data['views'] ?? 0;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Icon(Icons.people, size: 25,
                  color: theme.colorScheme.onSurface),
              Text('$servings 인분',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
          Column(
            children: [
              Icon(Icons.timer, size: 25,
                  color: theme.colorScheme.onSurface),
              Text('$cookTime 분',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
          Column(
            children: [
              Icon(Icons.emoji_events, size: 25,
                  color: theme.colorScheme.onSurface),
              Text(difficulty,
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
          Column(
            children: [
              Icon(Icons.remove_red_eye_sharp, size: 25,
                  color: theme.colorScheme.onSurface),
              Text('$viewCount명 읽음',
                  style:
                      TextStyle(color: theme.colorScheme.onSurface)), // 조회수 표시
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(List<String> ingredients) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('재료',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface)),
              Spacer(),
              Text("냉장고에 없는 재료 장바구니 담기",
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              _buildAddToShoppingListButton(),
            ],
          ),
          SizedBox(
            height: 10,
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: ingredients.map((ingredient) {
              bool inFridge = fridgeIngredients.contains(ingredient);
              bool isKeyword = searchKeywords.contains(ingredient);
              return Container(
                padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 5.0),
                decoration: BoxDecoration(
                  color: isKeyword
                      ? Colors.lightGreen
                      : inFridge
                          ? Colors.grey
                          : Colors.transparent, // 그 외는 기본 스타일
                  border: Border.all(
                    color: Colors.grey,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(ingredient,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToShoppingListButton() {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(Icons.add_shopping_cart,
          color: theme.colorScheme.onSurface),
      onPressed: _addToShoppingList, // 팝업 다이얼로그 호출
    );
  }

  Widget _buildCookingStepsSection(List<String> methods) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '조리방법',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface),
          ),
          SizedBox(
            height: 10,
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: methods.map((method) {
              bool isKeyword = searchKeywords.contains(method);
              return Container(
                padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 5.0),
                decoration: BoxDecoration(
                  color: isKeyword
                      ? Colors.lightGreen // 검색 키워드에 있으면 녹색
                      : Colors.transparent,
                  border: Border.all(
                    color: Colors.grey,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(method,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemesSection(List<String> themes) {
    final themes1 = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('테마',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: themes1.colorScheme.onSurface)),
          SizedBox(
            height: 10,
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: themes.map((theme) {
              bool isKeyword = searchKeywords.contains(theme);
              return Container(
                padding: EdgeInsets.symmetric(vertical: 3.0, horizontal: 5.0),
                decoration: BoxDecoration(
                  color: isKeyword
                      ? Colors.lightGreen // 검색 키워드에 있으면 녹색
                      : Colors.transparent,
                  border: Border.all(
                    color: Colors.grey,
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(theme,
                    style: TextStyle(color: themes1.colorScheme.onSurface)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSection(List<Map<String, String>> steps) {
    final theme = Theme.of(context);
    final allImages = _collectAllImages(mainImages, steps);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('레시피',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface)),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              bool hasImage = steps[index]['image'] != null &&
                  steps[index]['image']!.isNotEmpty;
              return GestureDetector(
                  onTap: () {
                    if (hasImage) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            images: allImages,
                            initialIndex:
                                mainImages.length + index, // 조리 과정 이미지의 시작 인덱스
                          ),
                        ),
                      );
                    }
                  },
                  child: Column(
                    children: [
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          hasImage
                              ? Image.network(
                                  steps[index]['image']!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text('Error loading image');
                                  },
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey, // 이미지가 없을 때 회색 배경
                                  child: Icon(Icons.image, color: Colors.white),
                                ),
                          Expanded(
                            child: Center(
                              child: Text(steps[index]['description']!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ));
            },
          ),
        ],
      ),
    );
  }
}
