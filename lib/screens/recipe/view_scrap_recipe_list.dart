import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/custom_dropdown.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/services/scraped_recipe_service.dart';

class ViewScrapRecipeList extends StatefulWidget {
  @override
  _ViewScrapRecipeListState createState() => _ViewScrapRecipeListState();
}

class _ViewScrapRecipeListState extends State<ViewScrapRecipeList> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? selectedRecipe;
  String selectedFilter = '기본함';

  // 요리명 리스트
  List<String> scrapedRecipes = [];
  List<RecipeModel> recipeList = [];
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

  @override
  void initState() {
    super.initState();
    selectedRecipes.clear();
    _loadData();
    _loadScrapedGroups();
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
  Future<void> _loadData() async {
    setState(() {
      isLoading = true; // 로딩 상태 시작
    });

    await fetchRecipesByScrap();
    await _loadFridgeItemsFromFirestore();

    setState(() {
      isLoading = false; // 로딩 상태 종료
    });
  }

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
        // 기본값 설정
        selectedFilter = '전체';
      });
    } catch (e) {
      print('Error loading scraped groups: $e');
    }
  }

  // 레시피 목록 필터링 함수
  List<RecipeModel> getFilteredRecipes() {
    if (selectedFilter == '전체') {
      return recipeList;
    }
    return myRecipeList;
  }

  Future<List<RecipeModel>> fetchRecipesByScrap() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot snapshot;
      print('선택된 필터: $selectedFilter');
      if (selectedFilter == '전체') {
        snapshot = await _db
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .orderBy('scrapedAt', descending: true)
            .get();
      } else {
        // 특정 그룹명을 기준으로 필터링
        snapshot = await _db
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('scrapedGroupName', isEqualTo: selectedFilter)
            .orderBy('scrapedAt', descending: true)
            .get();
      }

      // 각 문서의 recipeId로 레시피 정보를 불러옴
      recipeList.clear();
      for (var doc in snapshot.docs) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?; // 데이터를 Map<String, dynamic>으로 캐스팅
        String? recipeId = data?['recipeId']; // null 안전하게 접근
        if (recipeId != null && recipeId.isNotEmpty) {
          DocumentSnapshot<Map<String, dynamic>> recipeSnapshot =
              await FirebaseFirestore.instance
                  .collection('recipe')
                  .doc(recipeId)
                  .get();

          if (recipeSnapshot.exists && recipeSnapshot.data() != null) {
            recipeList.add(RecipeModel.fromFirestore(recipeSnapshot.data()!));
          }
        }
      }
      return recipeList;
    } catch (e) {
      print('Error fetching matching recipes: $e');
      return [];
    }
  }

  Future<void> _loadFridgeItemsFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('fridge_items').get();

      setState(() {
        fridgeIngredients =
            snapshot.docs.map((doc) => doc['items'] as String).toList();
      });
    } catch (e) {
      print('Error loading fridge items: $e');
    }
  }

  Future<bool> loadScrapedData(String recipeId) async {
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
        return false; // 스크랩된 레시피가 없으면 false 반환
      }
    } catch (e) {
      print("Error fetching recipe data: $e");
      return false;
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
        SnackBar(content: Text('기본 냉장고를 생성하는 데 실패했습니다.')),
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
      builder: (BuildContext context) {final theme = Theme.of(context);

      String newCategory = '';
        return AlertDialog(
          title: Text('스크랩 그룹 추가',
              style: TextStyle(
              color: theme.colorScheme.onSurface
          ),),
          content: TextField(
            onChanged: (value) {
              newCategory = value;
            },
            decoration: InputDecoration(hintText: '새로운 그룹 입력'),style:
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
          title: Text('그룹 삭제',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),),
          content: Text('스크랩 그룹을 삭제하시겠습니까?',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),),
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
    for (String recipeId in selectedRecipes) {
      final snapshot = await FirebaseFirestore.instance
          .collection('scraped_recipes')
          .where('userId', isEqualTo: userId)
          .where('recipeId', isEqualTo: recipeId)
          .get();

      for (var doc in snapshot.docs) {
        await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .doc(doc.id)
            .update({'scrapedGroupName': newGroupName});
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
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    '컬렉션',
                    style: TextStyle(
                      fontSize: 18, // 원하는 폰트 크기로 지정 (예: 18)
                      fontWeight: FontWeight.bold, // 폰트 굵기 조정 (선택사항)
                        color: theme.colorScheme.onSurface
                    ),
                  ),
                  // Spacer(),
                  Expanded(
                    child: CustomDropdown(
                      title: '',
                      items: _scraped_groups,
                      selectedItem: selectedFilter, // 리스트에 없으면 기본값 설정
                      onItemChanged: (value) async {
                        setState(() {
                          selectedFilter = value;
                        });
                        await fetchRecipesByScrap();
                        setState(() {});
                      },
                      onItemDeleted: (item) {
                        if (item != '전체') {
                          _deleteCategory(item, _scraped_groups, '스크랩 그룹');
                        }
                      },
                      onAddNewItem: () {
                        _addNewGroup(_scraped_groups, '스크랩 그룹');
                      },
                    ),
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
        if(selectedRecipes.isNotEmpty)
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
        RecipeModel recipe = recipeList[index];
        String recipeName = recipe.recipeName;
        double recipeRating = recipe.rating;
        bool hasMainImage = recipe.mainImages.isNotEmpty;
        // 카테고리 그리드 렌더링
        return FutureBuilder<bool>(
            future: loadScrapedData(recipe.id), // 각 레시피별로 스크랩 상태를 확인
            builder: (context, snapshot) {
              bool isScraped = snapshot.data ?? false;
              return Row(
                children: [
                  SizedBox(
                    width: 20, // 원하는 너비로 조정
                    height: 20, // 원하는 높이로 조정
                    child: Checkbox(
                      value: selectedRecipes.contains(recipe.id),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedRecipes.add(recipe.id);
                          } else {
                            selectedRecipes.remove(recipe.id);
                          }
                        });
                      },
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap, // 여백 줄이기
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ReadRecipe(
                                      recipeId: recipe.id,
                                      searchKeywords: [],
                                    )));
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
                                      _buildRatingStars(recipeRating),
                                      IconButton(
                                        icon: Icon(
                                          isScraped
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          size: 20,
                                          color: Colors.black,
                                        ), // 스크랩 아이콘 크기 조정
                                        onPressed: () =>
                                            _toggleScraped(recipe.id),
                                      ),
                                    ],
                                  ), // 간격 추가
                                  // 재료
                                  _buildChips(recipe),
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
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 2.0, // 아이템 간의 간격
      runSpacing: 2.0,
      children: [
        _buildTagSection("재료", recipe.foods),
        _buildTagSection("조리 방법", recipe.methods),
        _buildTagSection("테마", recipe.themes),
      ],
    );
  }

  Widget _buildTagSection(String title, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
                  color: inFridge ? Colors.white : Colors.black,
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
          title: Text('그룹 변경',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),
          ),
          content: DropdownButtonFormField<String>(
            value: _scraped_groups.isNotEmpty ? _scraped_groups[0] : null,
            items: _scraped_groups
                .map((group) => DropdownMenuItem(
                      value: group,
                      child: Text(group,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface
                        ),),
                    ))
                .toList(),
            onChanged: (value) {
              newGroupName = value;
            },
          ),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.pop(context, null),
            ),
            TextButton(
              child: Text('확인'),
              onPressed: () => Navigator.pop(context, newGroupName),
            ),
          ],
        );
      },
    );
  }
}
