import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/custom_dropdown.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/screens/recipe/recipe_webview_page.dart';
import 'package:food_for_later_new/screens/records/view_record_main.dart';
import 'package:food_for_later_new/services/scraped_recipe_service.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ViewScrapRecipeList extends StatefulWidget {
  @override
  _ViewScrapRecipeListState createState() => _ViewScrapRecipeListState();
}

class _ViewScrapRecipeListState extends State<ViewScrapRecipeList> with RouteAware {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? selectedRecipe;
  String selectedFilter = '기본함';

  // 요리명 리스트
  List<String> scrapedRecipes = [];
  List<Map<String, dynamic>> recipeList = [];
  List<RecipeModel> myRecipeList = []; // 나의 레시피 리스트
  String ratings = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  // 사용자별 즐겨찾기
  List<String> _scraped_groups = [];
  Set<String> selectedRecipes = {};

  // 냉장고에 있는 재료 리스트
  List<String> fridgeIngredients = [];
  bool isLoading = true; // 로딩 상태 추가
  bool isScraped = false;
  String userRole = '';
  // bool hasLink = false;
  Map<String, bool> scrapedStatus = {};

  @override
  void initState() {
    super.initState();
    selectedRecipes.clear();
    _initializePage();
    _loadUserRole();
    _loadFridgeIngredients();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 명시적 타입 캐스팅
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    // RouteObserver 해제
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _initializePage(); // 데이터를 다시 불러오는 함수 호출
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

  // 🔹 새로운 초기화 함수 추가
  Future<void> _initializePage() async {
    setState(() {
      isLoading = true; // 로딩 상태 시작
    });

    // 스크랩 그룹 로드
    await _loadScrapedGroups();
    if (selectedFilter == '내가 작성한 레시피') {
      // ✅ 내가 작성한 레시피만 불러오기
      List<Map<String, dynamic>> myRecipes = await _fetchMyRecipes();
      setState(() {
        recipeList = myRecipes;
        isLoading = false;
      });
    } else {
      // 레시피 로드
      List<Map<String, dynamic>> fetchedRecipes = await fetchRecipesByScrap();
      setState(() {
        recipeList = getFilteredRecipes(fetchedRecipes);
        isLoading = false;
      });
    }
  }
  Future<List<Map<String, dynamic>>> _fetchMyRecipes() async {
    final List<Map<String, dynamic>> myRecipes = [];
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('recipe')
          .where('userID', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      for (var doc in querySnapshot.docs) {
        RecipeModel recipe = RecipeModel.fromFirestore(
            doc.data() as Map<String, dynamic>);
        myRecipes.add({
          'id': doc.id,
          'recipe': recipe,
        });
      }
      print("✅ 내가 작성한 레시피 개수: ${myRecipes.length}");
    } catch (e) {
      print('❌ 내가 작성한 레시피 가져오는 중 오류 발생: $e');
    }
    return myRecipes;
  }
  // Future<void> _loadData() async {
  //   setState(() {
  //     isLoading = true; // 로딩 상태 시작
  //   });
  //
  //   await fetchRecipesByScrap();
  //   await _loadFridgeItemsFromFirestore();
  //
  //   setState(() {
  //     isLoading = false; // 로딩 상태 종료
  //   });
  // }

  Future<void> _loadScrapedGroups() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('scraped_group')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        _scraped_groups = snapshot.docs
            .map((doc) => doc['scrapedGroupName'] as String)
            .toList();

        // 항상 `전체`와 `기본함` 포함
        if (!_scraped_groups.contains('전체')) {
          _scraped_groups.insert(0, '전체'); // 가장 앞에 추가
        }
        _scraped_groups.remove('내가 작성한 레시피'); // 기존 위치 제거
        _scraped_groups.add('내가 작성한 레시피'); // 마지막에 추가
        // 기본값 설정
        selectedFilter = '전체';
      });
    } catch (e) {
      print('Error loading scraped groups: $e');
    }
  }
  void _loadFridgeIngredients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .get();

      setState(() {
        fridgeIngredients = snapshot.docs
            .expand((doc) {
          var items = doc['items'];
          if (items is List) {
            return List<String>.from(items); // ✅ List<String> 변환
          } else if (items is String) {
            return [items]; // ✅ 단일 문자열일 경우 리스트로 변환
          } else {
            return <String>[]; // ✅ 예외 처리 (비어있는 경우)
          }
        })
            .toList();
      });

    } catch (e) {
      print('❌ Error loading fridge items: $e');
    }
  }
  // 레시피 목록 필터링 함수
  List<Map<String, dynamic>> getFilteredRecipes(
      List<Map<String, dynamic>> fetchedRecipes) {
    return fetchedRecipes
        .where((entry) =>
            selectedFilter == '전체' ||
            entry['recipe'].scrapedGroupName == selectedFilter)
        .toList(); // 🔹 `fetchedRecipes` 그대로 반환 (Map 형태 유지)
  }

  Future<List<Map<String, dynamic>>> fetchRecipesByScrap() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final List<Map<String, dynamic>> fetchedRecipes = [];

    try {
      QuerySnapshot snapshot = await _db
          .collection('scraped_recipes')
          .where('userId', isEqualTo: userId)
          .orderBy('scrapedAt', descending: true)
          .get();

      // 1️⃣ Firestore에서 가져온 데이터 리스트
      List<Map<String, dynamic>> rawDataList = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'recipeId': doc['recipeId'] as String? ?? '',
          'link': doc['link'] as String? ?? '',
          'scrapedGroupName': doc['scrapedGroupName'] ?? '기본함',
        };
      }).toList();

      // 2️⃣ 웹 링크가 있는 레시피만 필터링하여 병렬로 가져오기
      List<Future<RecipeModel?>> webRequests = rawDataList.map((data) async {
        if (data['link'].isNotEmpty) {
          return _fetchRecipeDetailsFromLink(data['link']);
        }
        return null;
      }).toList();

      List<RecipeModel?> webResults = await Future.wait(webRequests);

      // 3️⃣ Firestore에서 레시피 ID 목록을 한 번의 `whereIn` 쿼리로 가져오기
      List<String> recipeIds = List<String>.from(rawDataList
          .map((data) => data['recipeId'])
          .where((id) => id != null && id.toString().isNotEmpty));

      Map<String, RecipeModel> firestoreRecipeMap = {};

      if (recipeIds.isNotEmpty) {
        final recipeSnapshot = await _db
            .collection('recipe')
            .where(FieldPath.documentId, whereIn: recipeIds)
            .get();

        firestoreRecipeMap = {
          for (var doc in recipeSnapshot.docs)
            doc.id: RecipeModel.fromFirestore(doc.data() as Map<String, dynamic>)
        };
      }

      // 4️⃣ 결과를 `fetchedRecipes` 리스트에 저장
      for (int i = 0; i < rawDataList.length; i++) {
        var data = rawDataList[i];

        RecipeModel? recipe;
        if (data['link'].isNotEmpty) {
          recipe = webResults[i]; // 웹에서 가져온 레시피
        } else {
          recipe = firestoreRecipeMap[data['recipeId']]; // Firestore에서 가져온 레시피
        }
        if (recipe != null) {
          recipe.scrapedGroupName = data['scrapedGroupName'];
          fetchedRecipes.add({
            'id': data['id'], // 🔹 Firestore 문서 ID 저장
            'recipe': recipe,
          });
        }
      }
    } catch (e) {
      print('Error fetching matching recipes: $e');
    }
    return fetchedRecipes;
  }

  Future<Map<String, dynamic>> loadScrapedData(String recipeId,
      {String? link}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (link != null) {
        // 🔹 웹 레시피의 경우 link로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('link', isEqualTo: link)
            .get();
      } else {
        // 🔹 Firestore 레시피의 경우 recipeId로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('recipeId', isEqualTo: recipeId)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'isScraped': data['isScraped'] ?? false,
          'scrapedGroupName': data['scrapedGroupName'] ?? '기본함'
        };
      } else {
        return {'isScraped': false, 'scrapedGroupName': '기본함'};
      }
    } catch (e) {
      print("Error fetching recipe data: $e");
      return {'isScraped': false, 'scrapedGroupName': '기본함'};
    }
  }

  Future<RecipeModel?> _fetchRecipeDetailsFromLink(String link) async {
    try {
      final response = await http.get(Uri.parse(link));
      if (response.statusCode == 200) {
        final document = parse(response.body);

        // 제목 가져오기
        String title =
            document.querySelector('.view2_summary.st3 h3')?.text.trim() ??
                '제목 없음';

        // 이미지 가져오기
        final imageElement = document.querySelector('.centeredcrop img');
        String imageUrl = imageElement != null
            ? '${imageElement.attributes['src']}'
            : 'https://via.placeholder.com/150'; // 기본 이미지
        // 재료 가져오기
        final ingredientsElements =
            document.querySelectorAll('.ready_ingre3 > ul > li');
        List<String> ingredients = ingredientsElements
            .map((e) => e.text.trim().split(RegExp(r'\s+'))[0])
            .where((ingredient) => !ingredient.endsWith("구매"))
            .toList();

        // RecipeModel 생성
        return RecipeModel.fromWeb(
          title: title,
          link: link,
          image: imageUrl,
          foods: ingredients,
        );
      }
    } catch (e) {
      print('Error fetching recipe from link: $e');
    }
    return null; // 오류 발생 시 null 반환
  }

  void _openRecipeLink(String link, String title, RecipeModel recipe, bool initialScraped) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeWebViewPage(
          link: link,
          title: title,
          recipe: recipe,
          initialScraped: initialScraped,
          onToggleScraped: toggleScraped,         // 기존의 toggleScraped 함수 사용
          onSaveRecipeForTomorrow: _saveRecipeForTomorrow, // 기존의 _saveRecipeForTomorrow 함수 사용
        ),
      ),
    );
  }

  DateTime getTomorrowDate() {
    return DateTime.now().add(Duration(days: 1));
  }
  void _saveRecipeForTomorrow(RecipeModel recipe) async {
    try {
      // 기존의 fetchRecipeData 대신 recipe 객체의 데이터를 사용합니다.
      var recipeData = {
        'recipeName': recipe.recipeName,
        'mainImages': recipe.mainImages,
      };

      // 내일 날짜로 저장
      DateTime tomorrow = getTomorrowDate().toUtc();

      // records 배열 구성
      List<Map<String, dynamic>> records = [
        {
          'unit': '레시피 보기',  // 고정값 혹은 다른 값으로 대체 가능
          'contents': recipeData['recipeName'] ?? 'Unnamed Recipe',
          'images': recipeData['mainImages'] ?? [], // 이미지 배열
          'link': recipe.link,
          'recipeId': recipe.id,
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
  Future<bool> toggleScraped(String recipeId, String? link) async {
    bool newState = await ScrapedRecipeService.toggleScraped(
      context,
      recipeId,
      link,
    );
    return newState; // 또는 비동기 작업 결과로 반환
  }
  String _generateScrapedKey(String recipeId, String? link) {
    return link != null && link.isNotEmpty ? 'link|$link' : 'id|$recipeId';
  }
  Future<void> _createDefaultGroup() async {
    try {
      // Firestore에 기본 냉장고 추가
      await FirebaseFirestore.instance.collection('scraped_group').add({
        'scrapedGroupName': '기본함',
        'userId': userId,
      });
      // UI 업데이트
      setState(() {
        if (!_scraped_groups.contains('기본함')) {
          _scraped_groups.add('기본함'); // 기본 그룹 추가
        }
        selectedFilter = '기본함'; // 기본 그룹 선택
      });
    } catch (e) {
      print('Error creating default fridge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 보관함을 생성하는 데 실패했습니다.')),
      );
    }
  }

  Future<void> _addNewScrapedGroupToFirestore(
      String newScrapedGroupName) async {
    final ref = FirebaseFirestore.instance.collection('scraped_group');
    try {
      await ref.add({
        'scrapedGroupName': newScrapedGroupName,
        'userId': userId,
      });
    } catch (e) {
      print('스크랩 그룹 추가 중 오류가 발생했습니다: $e');
    }
  }

  // 새로운 카테고리 추가 함수
  void _addNewGroup(List<String> categories, String categoryType) {
    if (categories.length >= 10) {
      // 카테고리 개수가 3개 이상이면 추가 불가
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryType은(는) 최대 10개까지만 추가할 수 있습니다.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        String newCategory = '';
        return AlertDialog(
          title: Text(
            '스크랩 그룹 추가',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: TextField(
            onChanged: (value) {
              newCategory = value;
            },
            decoration: InputDecoration(hintText: '새로운 그룹 입력'),
            style: TextStyle(color: theme.chipTheme.labelStyle!.color),
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
                  await _addNewScrapedGroupToFirestore(newCategory);
                  setState(() {
                    categories.add(newCategory);
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

  // 선택된 냉장고 삭제 함수
  void _deleteCategory(
      String category, List<String> categories, String categoryType) {
    final theme = Theme.of(context);
    final fridgeRef = FirebaseFirestore.instance.collection('scraped_group');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '그룹 삭제',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '스크랩 그룹을 삭제하시겠습니까?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
                child: Text('삭제'),
                onPressed: () async {
                  try {
                    // 해당 냉장고 이름과 일치하는 문서를 찾음
                    final snapshot = await fridgeRef
                        .where('scrapedGroupName', isEqualTo: category)
                        .where('userId', isEqualTo: userId)
                        .get();

                    for (var doc in snapshot.docs) {
                      // Firestore에서 문서 삭제
                      await fridgeRef.doc(doc.id).delete();
                    }
                    setState(() {
                      _scraped_groups.remove(category);
                      if (_scraped_groups.isNotEmpty) {
                        selectedFilter = _scraped_groups.first;
                      } else {
                        _createDefaultGroup(); // 모든 냉장고가 삭제되면 기본 냉장고 생성
                      }
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print('Error deleting fridge: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('냉장고를 삭제하는 중 오류가 발생했습니다.')),
                    );
                    Navigator.pop(context);
                  }
                  ;
                }),
          ],
        );
      },
    );
  }

  Future<void> updateScrapedGroupName(String newGroupName) async {
    for (String docId in selectedRecipes) {
      try {
        await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .doc(docId)
            .update({'scrapedGroupName': newGroupName});
      } catch (e) {
        print('❌ 문서 업데이트 실패: $docId, 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('스크랩 레시피 목록'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // 🔹 로딩 스피너 표시
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '컬렉션',
                          style: TextStyle(
                              fontSize: 18, // 원하는 폰트 크기로 지정 (예: 18)
                              fontWeight: FontWeight.bold, // 폰트 굵기 조정 (선택사항)
                              color: theme.colorScheme.onSurface),
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      CustomDropdown(
                        title: '',
                        items: _scraped_groups,
                        selectedItem: selectedFilter, // 리스트에 없으면 기본값 설정
                        onItemChanged: (value) async {
                          setState(() {
                            selectedFilter = value;
                            recipeList = []; // 🔹 UI를 빠르게 업데이트하기 위해 먼저 비움
                            isLoading = true; // 🔹 로딩 상태 시작
                          });
                          List<Map<String, dynamic>> fetchedData;

                          if (selectedFilter == '내가 작성한 레시피') {
                            // ✅ 내가 작성한 레시피 불러오기
                            fetchedData = await _fetchMyRecipes();
                          } else {
                            // ✅ 선택된 필터에 맞는 스크랩 레시피 불러오기
                            fetchedData = await fetchRecipesByScrap();
                            fetchedData = getFilteredRecipes(fetchedData);
                          }

                          setState(() {
                            recipeList = fetchedData; // 레시피 데이터 반영
                            isLoading = false; // 🔹 로딩 상태 종료
                          });
                        },
                        onItemDeleted: (item) {
                          if (item != '전체' && item != '내가 작성한 레시피') {
                            _deleteCategory(item, _scraped_groups, '스크랩 그룹');
                          }
                        },
                        onAddNewItem: () {
                          _addNewGroup(_scraped_groups, '스크랩 그룹');
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: _buildRecipeGrid(),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (selectedRecipes.isNotEmpty && selectedFilter != '내가 작성한 레시피')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: NavbarButton(
                  buttonTitle: '스크랩 그룹 변경',
                  onPressed: () async {
                    // 그룹 변경 팝업 표시
                    String? newGroupName = await _showGroupChangeDialog();
                    if (newGroupName != null) {
                      await updateScrapedGroupName(newGroupName);
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
        ],
      ),
    );
  }

  Widget _buildRecipeGrid() {
    // 광고를 삽입한 리스트 만들기
    List<dynamic> resultsWithAds = [];
    int adFrequency = 5; // 광고를 몇 개마다 넣을지 설정

    for (int i = 0; i < recipeList.length; i++) {
      resultsWithAds.add(recipeList[i]);
      if ((i + 1) % adFrequency == 0) {
        resultsWithAds.add('ad'); // 광고 위치를 표시하는 문자열
      }
    }
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 3,
      ),
      itemCount: recipeList.length,
      itemBuilder: (context, index) {
        if (resultsWithAds[index] == 'ad') {
          // 광고 위젯
          if (userRole != 'admin' && userRole != 'paid_user')
            return SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            );
        }
        final Map<String, dynamic> recipeEntry = recipeList[index];
        final String docId = recipeEntry['id']; // 🔹 정확히 Firestore 문서 ID 가져오기
        final RecipeModel recipe = recipeEntry['recipe']; // 🔹 RecipeModel 가져오기

        String recipeName = recipe.recipeName;
        double recipeRating = recipe.rating;
        bool hasMainImage = recipe.mainImages.isNotEmpty;
        // 카테고리 그리드 렌더링
        return FutureBuilder<Map<String, dynamic>>(
            future: loadScrapedData(recipe.id,
                link: recipe.link), // 각 레시피별로 스크랩 상태를 확인
            builder: (context, snapshot) {
              bool isScraped = (snapshot.data?['isScraped'] as bool?) ?? false;
              // scrapedStatus[recipe.id] = isScraped;
              return Row(
                children: [
                  Visibility(
                    visible: selectedFilter != '내가 작성한 레시피',
                    child: SizedBox(
                      width: 20, // 원하는 너비로 조정
                      height: 20, // 원하는 높이로 조정
                      child: Checkbox(
                        value: selectedRecipes.contains(docId),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedRecipes.add(docId);
                            } else {
                              selectedRecipes.remove(docId);
                            }
                          });
                        },
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap, // 여백 줄이기
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (recipe.link != null && recipe.link!.isNotEmpty) {
                          _openRecipeLink(recipe.link ?? '', recipeName, recipe, isScraped);
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ReadRecipe(
                                        recipeId: recipe.id,
                                        searchKeywords: [],
                                      )));
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 1.0, horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(8.0),
                        ), // 카테고리 버튼 크기 설정
                        child: Row(
                          children: [
                            // 왼쪽에 정사각형 그림
                            Container(
                              width: 60.0,
                              height: 60.0,
                              decoration: BoxDecoration(
                                color:
                                    Colors.grey, // Placeholder color for image
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: hasMainImage
                                  ? Image.network(
                                      recipe.mainImages[0],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                                  // 요리명
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          recipeName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1, // 제목이 한 줄로 표시되도록 설정
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      if (recipe.link == null ||
                                          recipe.link!.isEmpty)
                                        _buildRatingStars(recipeRating),
                                      IconButton(
                                        icon: Icon(
                                          isScraped
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          size: 20,
                                          color: Colors.black,
                                        ), // 스크랩 아이콘 크기 조정
                                        onPressed: () async {
                                          bool newState = await toggleScraped(recipe.id, recipe.link);

                                          // 🔹 UI 업데이트 (정확한 키로 상태 반영)
                                          setState(() {
                                            scrapedStatus[_generateScrapedKey(recipe.id, recipe.link)] = newState;
                                          });
                                        },
                                      ),
                                    ],
                                  ), // 간격 추가
                                  // 재료
                                  Expanded(
                                      child: _buildChips(recipe)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            });
      },
    );
  }

  Widget _buildChips(RecipeModel recipe) {
    final List<String> uniqueIngredients = recipe.foods.toSet().toList();
    return SingleChildScrollView(
      // scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          _buildTagSection("재료", uniqueIngredients),
          // _buildTagSection("조리 방법", recipe.methods),
          // _buildTagSection("테마", recipe.themes),
        ],
      ),
    );
  }

  Widget _buildTagSection(String title, List<String> tags) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 2.0, // 아이템 간의 간격
      runSpacing: 2.0,
      children: tags.map((tag) {
        bool inFridge = fridgeIngredients.contains(tag);
        return Container(
          padding: EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: inFridge ? Colors.grey : Colors.transparent,
            border: Border.all(
              color: Colors.grey,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 12.0,
              color: inFridge
                  ? theme.colorScheme.surface
                  : theme.colorScheme.onSurface
            ),
          ),
        );
      }).toList(),
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
            size: 12,
          );
        } else if (index == fullStars && hasHalfStar) {
          return Icon(
            Icons.star_half,
            color: Colors.amber,
            size: 12,
          );
        } else {
          return Icon(
            Icons.star_border,
            color: Colors.amber,
            size: 12,
          );
        }
      }),
    );
  }

  Future<String?> _showGroupChangeDialog() async {
    final theme = Theme.of(context);
    String? newGroupName;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '그룹 변경',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: DropdownButtonFormField<String>(
            value: _scraped_groups.isNotEmpty ? _scraped_groups[1] : null,
            items: _scraped_groups
                .where((group) => group != '전체')
                .map((group) => DropdownMenuItem(
                      value: group,
                      child: Text(
                        group,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                newGroupName = value; // 🔹 선택한 값으로 갱신
              });
            },
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.pop(context, null),
            ),
            TextButton(
              child: Text('확인'),
              onPressed: () async {
                if (newGroupName != null && newGroupName!.isNotEmpty) {
                  await updateScrapedGroupName(newGroupName!);

                  setState(() {
                    selectedFilter = newGroupName!; // 드롭다운 초기화
                    selectedRecipes.clear(); // 체크박스 초기화
                  });

                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }
}
