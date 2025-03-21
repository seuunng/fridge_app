import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/ad/interstitial_ad_service.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/constants.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';
import 'package:food_for_later_new/screens/foods/add_item_to_category.dart';
import 'package:food_for_later_new/screens/fridge/fridge_item_details.dart';
import 'package:intl/intl.dart';
import 'package:food_for_later_new/constants.dart';

class AddItem extends StatefulWidget {
  final String pageTitle;
  final String addButton;
  final String sourcePage;
  final Function onItemAdded;
  final String? selectedFridge; // ✅ 추가된 매개변수
  final String? selectedFridgeId; // ✅ 추가된 매개변수

  AddItem({
    required this.pageTitle,
    required this.addButton,
    required this.sourcePage,
    required this.onItemAdded,
    this.selectedFridge, // ✅ 추가
    this.selectedFridgeId, // ✅ 추가
  });

  @override
  _AddItemState createState() => _AddItemState();
}

class _AddItemState extends State<AddItem> with RouteAware {
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
  final InterstitialAdService _adManager = InterstitialAdService();

  @override
  void initState() {
    super.initState();
    _adManager.loadInterstitialAd();
    _loadSelectedFridge();
    // if (widget.sourcePage == 'preferred_foods_category') {
    //   _loadPreferredFoodsCategoriesFromFirestore();
    // } else {
    _loadCategoriesFromFirestore();
    // }
    _loadDeletedItems();
    _loadUserRole();
  }

  @override
  void didPopNext() {
    _loadCategoriesFromFirestore(); // ✅ 다른 페이지 갔다가 다시 돌아오면 실행
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _loadSelectedFridge() async {
    setState(() {
      // selectedFridge = widget.selectedFridge ?? '기본 냉장고';
      selected_fridgeId = widget.selectedFridgeId ?? '';
    });
  }

  // void _setDefaultFridge() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   try {
  //     // 현재 계정과 연결된 냉장고 가져오기
  //     final snapshot = await FirebaseFirestore.instance
  //         .collection('fridges')
  //         .where('userId', isEqualTo: userId)
  //         .get();
  //
  //     if (snapshot.docs.isNotEmpty) {
  //       // 첫 번째 냉장고를 기본으로 설정
  //       final fridgeName = snapshot.docs.first.data()['FridgeName'] ?? '기본 냉장고';
  //       setState(() {
  //         selectedFridge = fridgeName;
  //       });
  //       await prefs.setString('selectedFridge', fridgeName);
  //     } else {
  //       print('해당 계정에 연결된 냉장고가 없습니다.');
  //     }
  //   } catch (e) {
  //     print('기본 냉장고 설정 중 오류 발생: $e');
  //   }
  // }
  Future<List<FoodsModel>> _fetchFoods() async {
    List<FoodsModel> userFoods = [];
    List<FoodsModel> defaultFoods = [];
    Set<String> modifiedFoodIds = {}; // 사용자가 수정한 defaultFoodsDocId 저장

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('foods')
          .where('userId', isEqualTo: userId)
          .get();

      // 🔹 사용자가 수정한 식품 불러오기
      for (var doc in userSnapshot.docs) {
        final food = FoodsModel.fromFirestore(doc);
        userFoods.add(food);
        if (food.defaultFoodsDocId != null &&
            food.defaultFoodsDocId!.isNotEmpty) {
          modifiedFoodIds.add(food.defaultFoodsDocId!); // 사용자가 수정한 기본 식품 ID 저장
        }
      }
      final defaultSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      // 🔹 기본 식품 목록 불러오기 (사용자가 수정하지 않은 것만 추가)
      for (var doc in defaultSnapshot.docs) {
        final food = FoodsModel.fromFirestore(doc);
        if (!modifiedFoodIds.contains(food.id)) {
          // 기본 데이터 중 사용자가 수정한 것은 제외
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
      if (mounted)
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
                .compareTo(
                    indexB == -1 ? predefinedCategoryFridge.length : indexB);
          });

        itemsByCategory = Map.fromEntries(
          sortedKeys.map((key) => MapEntry(key, itemsByCategory[key]!)),
        );
      });
    } catch (e) {
      print('카테고리 데이터를 불러오는 데 실패했습니다: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('카테고리 데이터를 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),
        ),
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

  // void _loadPreferredFoodsCategoriesFromFirestore() async {
  //   try {
  //     final snapshot = await FirebaseFirestore.instance
  //         .collection('preferred_foods_categories')
  //         .where('userId', isEqualTo: userId)
  //         .get();
  //
  //     if (snapshot.docs.isEmpty) {
  //       await _addDefaultPreferredCategories();
  //     } else {
  //       final Map<String, List<PreferredFoodModel>> loadedData = {};
  //
  //       for (var doc in snapshot.docs) {
  //         final data = doc.data();
  //         final model = PreferredFoodModel.fromFirestore(data);
  //
  //         model.category.forEach((key, value) {
  //           if (loadedData.containsKey(key)) {
  //             loadedData[key]!.addAll(value.map((item) => PreferredFoodModel(
  //                   category: {
  //                     key: [item]
  //                   },
  //                   userId: model.userId,
  //                 )));
  //           } else {
  //             loadedData[key] = value
  //                 .map((item) => PreferredFoodModel(
  //                       category: {
  //                         key: [item]
  //                       },
  //                       userId: model.userId,
  //                     ))
  //                 .toList();
  //           }
  //         });
  //       }
  //       setState(() {
  //         itemsByPreferredCategory = Map.from(loadedData);
  //       });
  //     }
  //   } catch (e) {
  //     print('Error loading preferred categories: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('카테고리를 불러오는 중 오류가 발생했습니다.')),
  //     );
  //   }
  // }

  // Future<void> _addDefaultPreferredCategories() async {
  //   await PreferredFoodsService.addDefaultPreferredCategories(
  //     context,
  //     _loadPreferredFoodsCategoriesFromFirestore,
  //   );
  // }

  Future<void> _addItemsToFridge() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 후에 냉장고에 추가할 수 있습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return; // 🚫 게스트 사용자는 추가 불가
    }
    if (userRole != 'admin' && userRole != 'paid_user')
      await _adManager.showInterstitialAd(context);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final fridgeId = selected_fridgeId;

    try {
      for (String itemName in selectedItems) {
        // 🔍 foods 컬렉션에서 먼저 찾기
        final foodsSnapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where('foodsName', isEqualTo: itemName.trim().toLowerCase())
            .where('userId', isEqualTo: userId) // 사용자 데이터 우선
            .get();

        Map<String, dynamic>? foodData;

        if (foodsSnapshot.docs.isNotEmpty) {
          final doc = foodsSnapshot.docs.first;
          foodData = doc.data();
          foodData['id'] = doc.id; // ✅ 문서 ID를 데이터에 추가
          print("🔥 foods 컬렉션에서 찾은 foodData: $foodData");
        } else {
          // 🔍 사용자 데이터가 없으면 default_foods에서 찾기
          final defaultFoodsSnapshot = await FirebaseFirestore.instance
              .collection('default_foods')
              .where('foodsName', isEqualTo: itemName.trim().toLowerCase())
              .get();

          if (defaultFoodsSnapshot.docs.isNotEmpty) {
            final doc = defaultFoodsSnapshot.docs.first;
            foodData = doc.data();
            foodData['id'] = doc.id; // ✅ 문서 ID를 추가
            print("🔥 default_foods 컬렉션에서 찾은 foodData: $foodData");
          }
        }

        if (foodData == null) {
          foodData = {
            'foodsName': itemName, // 입력된 이름 그대로 저장
            'defaultFridgeCategory': '냉장',
            'shelfLife': 365, // 기본 유통기한 1년 설정
          };
        }

        String fridgeCategoryId = foodData['defaultFridgeCategory'] ?? '냉장';
        final defaultCategorySnapshot = await FirebaseFirestore.instance
            .collection('default_fridge_categories')
            .where('categoryName', isEqualTo: fridgeCategoryId)
            .get();

        if (defaultCategorySnapshot.docs.isEmpty) {
          // 🔍 기본 카테고리에 없으면 사용자 정의 카테고리 fridge_categories에서 찾기
          final customCategorySnapshot = await FirebaseFirestore.instance
              .collection('fridge_categories')
              .where('userId', isEqualTo: userId) // 사용자별 맞춤 카테고리 확인
              .where('categoryName', isEqualTo: fridgeCategoryId)
              .get();

          if (customCategorySnapshot.docs.isEmpty) {
            print(
                "⚠️ 유효하지 않은 fridgeCategoryId: $fridgeCategoryId, 기본값 '냉장' 사용");
            fridgeCategoryId = '냉장';
          } else {
            print("✅ fridge_categories에서 $fridgeCategoryId 찾음");
          }
        } else {
          print("✅ default_fridge_categories에서 $fridgeCategoryId 찾음");
        }

        // 🔍 기존에 동일한 아이템이 있는지 검사
        final existingItemSnapshot = await FirebaseFirestore.instance
            .collection('fridge_items')
            .where('items', isEqualTo: itemName.trim().toLowerCase())
            .where('FridgeId', isEqualTo: fridgeId)
            .get();

        if (existingItemSnapshot.docs.isEmpty) {
          // ✅ 새로운 아이템 추가
          await FirebaseFirestore.instance.collection('fridge_items').add({
            'items': itemName,
            'FridgeId': fridgeId,
            'fridgeCategoryId': fridgeCategoryId,
            'registrationDate': Timestamp.fromDate(DateTime.now()),
            'userId': userId,
          });
        } else {
          // 🔴 이미 존재하는 경우 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$itemName 아이템이 이미 냉장고에 있습니다.'),
              duration: Duration(seconds: 2),
            ),
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
        SnackBar(
          content: Text('아이템 추가 중 오류가 발생했습니다.'),
          duration: Duration(seconds: 2),
        ),
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
    if (userRole != 'admin' && userRole != 'paid_user')
      await _adManager.showInterstitialAd(context);
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

  // void _navigateAddPreferredCategory() {
  //   if (userRole != 'admin' && userRole != 'paid_user') {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text('프리미엄 서비스를 이용하면 나만의 제외 키워드 카테고리를 관리할 수 있어요!'),
  //             ],
  //           ),
  //           duration: Duration(seconds: 3), // 3초간 표시
  //         ),
  //       );
  //       return;
  //   }
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => AddPreferredCategory(
  //         categoryName: selectedCategory ?? '',
  //         sourcePage: 'add_category',
  //       ),
  //     ),
  //   ).then((_) {
  //     _loadPreferredFoodsCategoriesFromFirestore();
  //   });
  // }

  void _searchItems(String keyword) {
    List<FoodsModel> tempFilteredItems = [];
    setState(() {
      searchKeyword = keyword.trim().toLowerCase();
      isSearchActive = true; // 검색 버튼을 누르면 검색 활성화
      if (searchKeyword.isNotEmpty) {
        _saveSearchKeyword(searchKeyword);
      }

      // if (widget.sourcePage == 'preferred_foods_category') {
      //   itemsByPreferredCategory.forEach((category, categoryModels) {
      //     for (var categoryModel in categoryModels) {
      //       categoryModel.category.forEach((key, values) {
      //         for (var foodName in values) {
      //           if (foodName.toLowerCase().contains(searchKeyword)) {
      //             tempFilteredItems.add(
      //               FoodsModel(
      //                 id: 'unknown',
      //                 foodsName: foodName,
      //                 defaultCategory: category,
      //                 defaultFridgeCategory: '기타',
      //                 shoppingListCategory: '기타',
      //                 shelfLife: 0,
      //               ),
      //             );
      //           }
      //         }
      //       });
      //     }
      //   });
      // } else {
      itemsByCategory.forEach((category, items) {
        tempFilteredItems.addAll(
          items.where(
              (item) => item.foodsName.toLowerCase().contains(searchKeyword)),
        );
      });
      // }
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
        resizeToAvoidBottomInset: true,
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
                        style: TextStyle(color: theme.colorScheme.onSurface),
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
                // if (widget.sourcePage == 'preferred_foods_category')
                //   Padding(
                //     padding: const EdgeInsets.all(8.0),
                //     child: _buildPreferredCategoryGrid(),
                //   )
                // else
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
        bottomNavigationBar: (selectedItems.isNotEmpty &&
                (widget.sourcePage == 'shoppingList' ||
                    widget.sourcePage == 'fridge'))
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      5, // 키보드 높이만큼 올리기
                  left: 8,
                  right: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
                  mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
                  children: [
                    Container(
                      color: Colors.transparent,
                      // padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                ),
              )
            : (userRole != 'admin' && userRole != 'paid_user')
                ? BannerAdWidget()
                : null);
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
                    style: TextStyle(
                        color: selectedItems.contains(searchKeyword)
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
            String? imageFileName = categoryImages[category]; // 🟢 카테고리 이미지 가져오기
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
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    if (imageFileName != null)
                SvgPicture.asset(
                'assets/categories/$imageFileName', // ✅ 이미지 경로 적용
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
              else
              Icon(
              Icons.image,
              size: 50,
              color: Colors.grey,
            ),
            AutoSizeText(
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
            ]
                ),

              ),
            );
          });
    });
  }

  // Widget _buildPreferredCategoryGrid() {
  //   final theme = Theme.of(context);
  //
  //   return LayoutBuilder(builder: (context, constraints) {
  //     bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
  //     double maxCrossAxisExtent =
  //         isWeb ? webGridMaxExtent : mobileGridMaxExtent;
  //     return GridView.builder(
  //       shrinkWrap: true,
  //       physics: NeverScrollableScrollPhysics(),
  //       padding: EdgeInsets.all(8.0),
  //       gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  //         maxCrossAxisExtent: maxCrossAxisExtent,
  //         crossAxisSpacing: gridSpacing,
  //         mainAxisSpacing: gridSpacing,
  //         childAspectRatio: 1,
  //       ),
  //       itemCount: itemsByPreferredCategory.keys.length + 1,
  //       itemBuilder: (context, index) {
  //         if (index == itemsByPreferredCategory.keys.length) {
  //           // +아이콘 추가
  //           return GestureDetector(
  //             onTap: _navigateAddPreferredCategory,
  //             child: Container(
  //               decoration: BoxDecoration(
  //                 color: theme.chipTheme.backgroundColor,
  //                 borderRadius: BorderRadius.circular(8.0),
  //               ),
  //               child: Center(
  //                 child: Icon(Icons.add,
  //                     size: 32, color: theme.chipTheme.labelStyle!.color),
  //               ),
  //             ),
  //           );
  //         } else {
  //           String categoryName =
  //               itemsByPreferredCategory.keys.elementAt(index);
  //
  //           return GestureDetector(
  //             onTap: () {
  //               setState(() {
  //                 selectedCategory = categoryName;
  //               });
  //             },
  //             child: Container(
  //               decoration: BoxDecoration(
  //                 color: selectedCategory == categoryName
  //                     ? theme.chipTheme.selectedColor
  //                     : theme.chipTheme.backgroundColor,
  //                 borderRadius: BorderRadius.circular(8.0),
  //               ),
  //               child: Center(
  //                 child: AutoSizeText(
  //                   categoryName,
  //                   style: TextStyle(
  //                     color: selectedCategory == categoryName
  //                         ? theme.chipTheme.secondaryLabelStyle!.color
  //                         : theme.chipTheme.labelStyle!.color,
  //                   ),
  //                   maxLines: 1,
  //                 ),
  //               ),
  //             ),
  //           );
  //         }
  //       },
  //     );
  //   });
  // }

  // 카테고리별 아이템을 출력하는 그리드
  Widget _buildItemsGrid() {
    final theme = Theme.of(context);

    // final isPreferredCategory = widget.sourcePage == 'preferred_foods_category';
    List preferredItems = [];
    List<FoodsModel> regularItems = [];

    // if (isPreferredCategory) {
    //   if (selectedCategory != null &&
    //       itemsByPreferredCategory.containsKey(selectedCategory!)) {
    //     preferredItems = itemsByPreferredCategory[selectedCategory!]!;
    //   }
    // } else {
    if (selectedCategory != null &&
        itemsByCategory.containsKey(selectedCategory!)) {
      regularItems = itemsByCategory[selectedCategory!]!;
    }
    // }

    final itemCount = regularItems.length;

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
              onTap: _navigateToAddItemPage,
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
            final item = regularItems[index] as FoodsModel;
            final itemName = (item as FoodsModel).foodsName;
            final isSelected = selectedItems.contains(itemName);
            var isDeleted = deletedItemNames.contains(itemName);
            print("이미지 파일명: ${item.imageFileName}");
            return GestureDetector(
              onTap: widget.sourcePage != 'update_foods_category'
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
                    final doc = foodsSnapshot.docs.first; // 🔹 첫 번째 문서 가져오기
                    foodData = doc.data(); // 🔹 Firestore에서 가져온 데이터
                    foodData['id'] = doc.id; // ✅ 문서 ID를 직접 추가
                    print("🔥 foods 컬렉션에서 찾은 foodData: $foodData");
                  } else {
                    final defaultFoodsSnapshot = await FirebaseFirestore
                        .instance
                        .collection('default_foods')
                        .where('foodsName', isEqualTo: itemName)
                        .get();

                    if (defaultFoodsSnapshot.docs.isNotEmpty) {
                      final doc = defaultFoodsSnapshot.docs.first;
                      foodData = doc.data();
                      foodData['id'] = doc.id; // ✅ 문서 ID를 추가
                      print("🔥 default_foods 컬렉션에서 찾은 foodData: $foodData");
                    }
                  }

                  if (foodData != null) {
                    String defaultCategory =
                        foodData['defaultCategory'] ?? '기타';
                    String defaultFridgeCategory =
                        foodData['defaultFridgeCategory'] ?? '기타';
                    String shoppingListCategory =
                        foodData['shoppingListCategory'] ?? '기타';
                    int shelfLife = foodData['shelfLife'] ?? 0;
                    String foodsId = foodData['id'] ?? '기타';

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FridgeItemDetails(
                          foodsId: foodsId,
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
                    if (result == true) {
                      _loadCategoriesFromFirestore(); // ✅ 수정 후 즉시 목록 갱신
                    }
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
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.imageFileName != null && item.imageFileName!.isNotEmpty)
                        SvgPicture.asset(  // SVG 파일이면 flutter_svg로 표시
                          'assets/foods/${item.imageFileName}.svg',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      else
                        Icon(
                          Icons.image,  // 기본 이미지 없을 경우 사진 아이콘 표시
                          size: 50,  // 아이콘 크기 조절
                          color: Colors.grey,  // 색상 지정 가능
                        ),
                      AutoSizeText(
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
                    ]),
              ),
            );
          }
        },
      );
    });
  }
}
