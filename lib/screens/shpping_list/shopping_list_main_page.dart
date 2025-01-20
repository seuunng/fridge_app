import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/shopping_category_model.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/screens/home_screen.dart';
import 'package:food_for_later_new/services/default_fridge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShoppingListMainPage extends StatefulWidget {
  ShoppingListMainPage({Key? key}) : super(key: key);

  @override
  ShoppingListMainPageState createState() => ShoppingListMainPageState();
}

class ShoppingListMainPageState extends State<ShoppingListMainPage>
    with RouteAware {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<String> fridgeName = [];
  List<ShoppingCategory> _categories = [];

  String? selectedFridge = '';
  String? selected_fridgeId = '';

  Map<String, List<String>> itemLists = {};
  Map<String, List<bool>> checkedItems = {};
  Map<String, List<bool>> strikeThroughItems = {};
  Map<String, List<String>> groupedItems = {};

  bool showCheckBoxes = false;
  List<String> predefinedCategoryOrder = [
    '과일/채소',
    '정육/수산',
    '유제품/간편식',
    '양념/오일',
    '과자/간식',
    '가공식품',
    '음료/주류',
    '쌀/잡곡/견과류',
    '기타'
  ];
  @override
  void initState() {
    super.initState();
    _loadItemsFromFirestore(userId);
    _loadCategoriesFromFirestore();
    _loadFridgeCategoriesFromFirestore(userId).then((_) {
      _loadSelectedFridge(); // 🔹 냉장고 목록을 불러온 후 기본값 설정
    });

    setState(() {
      showCheckBoxes = false;
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    stopShoppingListDeleteMode();
    _loadSelectedFridge();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // routeObserver 구독 해제
    _loadSelectedFridge();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  void _loadItemsFromFirestore(String userId) async {
    try {
      // 🔹 Firestore에서 default_foods 데이터 가져오기
      final foodsSnapshot =
          await FirebaseFirestore.instance.collection('default_foods').get();

      final List<FoodsModel> foodsList = foodsSnapshot.docs
          .map((doc) => FoodsModel.fromFirestore(doc))
          .toList();

      // 🔹 Firestore에서 쇼핑 목록 가져오기 (현재 유저의 데이터만 필터링)
      final snapshot = await FirebaseFirestore.instance
          .collection('shopping_items')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> allItems = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final itemName = data['items']?.toString() ?? 'Unknown Item';
        final isChecked = data['isChecked'] ?? false;

        // 🔹 foodsList에서 해당 아이템 찾기
        final matchingFood = foodsList.firstWhere(
          (food) => food.foodsName == itemName,
          orElse: () => FoodsModel(
            id: 'unknown',
            foodsName: itemName,
            defaultCategory: '기타',
            defaultFridgeCategory: '기타',
            shoppingListCategory: '기타', // 🔹 쇼핑 카테고리가 없으면 "기타" 처리
            shelfLife: 0,
          ),
        );

        allItems.add({
          'category': matchingFood.shoppingListCategory, // 🔹 쇼핑 카테고리
          'itemName': itemName,
          'isChecked': isChecked,
        });
      }

      // 🔹 쇼핑 카테고리 기준으로 그룹화
      setState(() {
        itemLists = _groupItemsByShoppingCategory(allItems);

        allItems.forEach((item) {
          final category = item['category'];
          final itemName = item['itemName'];
          final isChecked = item['isChecked'];

          if (itemLists.containsKey(category)) {
            final itemIndex = itemLists[category]?.indexOf(itemName) ?? -1;
            if (itemIndex != -1) {
              checkedItems[category] ??= List<bool>.filled(
                  itemLists[category]!.length, false,
                  growable: true);
              strikeThroughItems[category] ??= List<bool>.filled(
                  itemLists[category]!.length, false,
                  growable: true);

              if (isChecked) {
                checkedItems[category]![itemIndex] = true;
                strikeThroughItems[category]![itemIndex] = true;
              }
            }
          }
        });
      });
    } catch (e) {
      print('Firestore에서 아이템 불러오는 중 오류 발생: $e');
    }
  }

  Map<String, List<String>> _groupItemsByShoppingCategory(
      List<Map<String, dynamic>> items) {
    Map<String, List<String>> groupedItems = {};

    for (var item in items) {
      final category = item['category'] ?? '기타'; // 카테고리가 없으면 "기타"
      final itemName = item['itemName'];

      if (groupedItems.containsKey(category)) {
        groupedItems[category]!.add(itemName);
      } else {
        groupedItems[category] = [itemName];
      }
    }

    // 🔹 카테고리 순서를 미리 정의된 순서에 맞게 정렬
    Map<String, List<String>> sortedGroupedItems = {};
    for (var category in predefinedCategoryOrder) {
      if (groupedItems.containsKey(category)) {
        sortedGroupedItems[category] = groupedItems[category]!;
      }
    }

    // 🔹 정의된 순서에 없는 나머지 카테고리 추가
    for (var category in groupedItems.keys) {
      if (!sortedGroupedItems.containsKey(category)) {
        sortedGroupedItems[category] = groupedItems[category]!;
      }
    }

    return sortedGroupedItems;
  }

  Future<void> _loadCategoriesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_categories')
        .get();

    final categories = snapshot.docs.map((doc) {
      return ShoppingCategory.fromFirestore(doc);
    }).toList();

    setState(() {
      _categories = categories;
    });
  }

  Future<void> _loadFridgeCategoriesFromFirestore(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          .get();

      List<String> fridgeList =
          snapshot.docs.map((doc) => doc['FridgeName'] as String).toList();

      if (fridgeList.isEmpty) {
        await DefaultFridgeService().createDefaultFridge(userId);

      }
      if (!mounted) return;

      setState(() {
        fridgeName = fridgeList; // 불러온 냉장고 목록을 상태에 저장
      });
    } catch (e) {
      print('Error loading fridge categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 목록을 불러오는 데 실패했습니다.')),
      );
    }
  }

  void _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인

    String? savedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';

    // 🔹 Firestore에서 해당 냉장고 ID 가져오기
    String? fridgeId = await fetchFridgeId(savedFridge);

// 🔹 fridgeName 리스트가 비어있지 않다면 기본값 설정
    if (fridgeName.isNotEmpty && !fridgeName.contains(savedFridge)) {
      savedFridge = fridgeName.first; // 🔹 리스트의 첫 번째 냉장고를 기본값으로 설정
      fridgeId = await fetchFridgeId(savedFridge);
    }

    setState(() {
      selectedFridge = savedFridge;
      selected_fridgeId = fridgeId; // 🔹 ID 업데이트
    });
  }

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

  void _selectStrikeThroughItems() async {
    for (var category in itemLists.keys) {
      int itemCount = itemLists[category]?.length ?? 0;

      checkedItems[category] ??=
          List<bool>.filled(itemCount, false, growable: true); // 수정!
      strikeThroughItems[category] ??=
          List<bool>.filled(itemCount, false, growable: true); // 수정!

      for (int index = 0; index < itemCount; index++) {
        if (strikeThroughItems[category]![index]) {
          checkedItems[category]![index] = true;

          String itemName = itemLists[category]?[index] ?? '';

          if (itemName.isNotEmpty) {
            try {
              final snapshot = await FirebaseFirestore.instance
                  .collection('shopping_items')
                  .where('items', isEqualTo: itemName) // 아이템 이름으로 문서 찾기
                  .get();

              if (snapshot.docs.isNotEmpty) {
                for (var doc in snapshot.docs) {
                  await FirebaseFirestore.instance
                      .collection('shopping_items')
                      .doc(doc.id) // 문서 ID를 사용하여 업데이트
                      .update({
                    'isChecked': true, // 'isChecked' 필드를 true로 업데이트
                  });
                }
              } else {
                print('Item not found in shopping_items: $itemName');
              }
            } catch (e) {
              print('Error updating isChecked for $itemName: $e');
            }
          }
        }
      }
    }
    setState(() {});
  }

// 냉장고로 이동 버튼이 나타나는 조건
  bool shouldShowMoveToFridgeButton() {
    for (var category in checkedItems.keys) {
      if (checkedItems[category]!.contains(true)) return true;
    }
    return false;
  }

  Future<void> _addItemsToFridge() async {
    final fridgeId = selected_fridgeId;

    if (fridgeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선택된 냉장고를 찾을 수 없습니다.')),
      );
      return;
    }

    try {
      for (var category in checkedItems.keys) {
        List<String> categoryItems = List<String>.from(itemLists[category]!);

        if (categoryItems.isEmpty) {
          continue;
        }

        List<int> itemsToRemove = [];

        for (int index = 0; index < checkedItems[category]!.length; index++) {
          if (checkedItems[category]![index]) {
            String itemName = categoryItems[index];

            // 🔹 1. `foods` 컬렉션에서 검색
            final matchingFoodSnapshot = await FirebaseFirestore.instance
                .collection('foods')
                .where('foodsName', isEqualTo: itemName)
                .get();

            Map<String, dynamic>? foodData;

            if (matchingFoodSnapshot.docs.isNotEmpty) {
              // `foods` 컬렉션에서 찾음
              foodData = matchingFoodSnapshot.docs.first.data();
            } else {
              // 🔹 2. `default_foods`에서 검색
              final defaultFoodsSnapshot = await FirebaseFirestore.instance
                  .collection('default_foods')
                  .where('foodsName', isEqualTo: itemName)
                  .get();

              if (defaultFoodsSnapshot.docs.isNotEmpty) {
                foodData = defaultFoodsSnapshot.docs.first.data();
              }
            }

            if (foodData == null) {
              print("일치하는 음식이 없습니다: $itemName");
              continue;
            }

            final fridgeCategoryId =
                foodData['defaultFridgeCategory'] ?? '기타'; // 냉장고 카테고리

            // 🔹 3. 냉장고에 이미 있는지 확인
            final existingItem = await FirebaseFirestore.instance
                .collection('fridge_items')
                .where('items', isEqualTo: itemName.trim().toLowerCase())
                .where('FridgeId', isEqualTo: fridgeId.trim())
                .get();

            if (existingItem.docs.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"$itemName"이(가) 이미 냉장고에 존재합니다.')),
              );
            } else {
              // 🔹 4. 냉장고에 추가
              await FirebaseFirestore.instance.collection('fridge_items').add({
                'items': itemName,
                'FridgeId': fridgeId,
                'fridgeCategoryId': fridgeCategoryId,
                'userId': userId,
                'registrationDate': Timestamp.fromDate(DateTime.now()),
              });
            }

            // 🔹 5. 장보기 목록에서 삭제
            final snapshot = await FirebaseFirestore.instance
                .collection('shopping_items')
                .where('items', isEqualTo: itemName)
                .where('userId', isEqualTo: userId) // 유저 ID로 필터
                .get();

            if (snapshot.docs.isNotEmpty) {
              for (var doc in snapshot.docs) {
                await FirebaseFirestore.instance
                    .collection('shopping_items')
                    .doc(doc.id)
                    .delete();
              }
            }
            itemsToRemove.add(index);
          }
        }

        setState(() {
          for (int i = itemsToRemove.length - 1; i >= 0; i--) {
            int removeIndex = itemsToRemove[i];
            categoryItems.removeAt(removeIndex);
            checkedItems[category]!.removeAt(removeIndex);
            strikeThroughItems[category]!.removeAt(removeIndex);
          }
          itemLists[category] = categoryItems;
        });
      }
    } catch (e) {
      print('아이템 추가 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 추가 중 오류가 발생했습니다.')),
      );
    }
  }

  void _updateIsCheckedInFirestore(String itemName, bool isChecked) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shopping_items')
          .where('items', isEqualTo: itemName) // 아이템 이름으로 문서 찾기
          .get();

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          await FirebaseFirestore.instance
              .collection('shopping_items')
              .doc(doc.id) // 문서 ID를 사용하여 업데이트
              .update({
            'isChecked': isChecked, // isChecked 필드를 업데이트
          });
        }
      } else {
        print('Item not found in shopping_items: $itemName');
      }
    } catch (e) {
      print('Error updating isChecked for $itemName: $e');
    }
  }

  Future<void> _deleteSelectedItems() async {
    try {
      for (var category in checkedItems.keys.toList()) {
        List<String> categoryItems = List<String>.from(itemLists[category]!);

        List<int> itemsToRemove = [];

        for (int index = 0; index < checkedItems[category]!.length; index++) {
          if (checkedItems[category]![index]) {
            String itemName = categoryItems[index];

            final snapshot = await FirebaseFirestore.instance
                .collection('shopping_items')
                .where('items', isEqualTo: itemName)
                .where('userId', isEqualTo: userId) // 유저 ID로 필터
                .get();

            if (snapshot.docs.isNotEmpty) {
              for (var doc in snapshot.docs) {
                try {
                  await FirebaseFirestore.instance
                      .collection('shopping_items')
                      .doc(doc.id) // 문서 ID를 사용하여 삭제
                      .delete();
                } catch (e) {
                  print('Firestore 문서 삭제 중 오류 발생 (ID: ${doc.id}): $e');
                }
              }
            }
            itemsToRemove.add(index);
          }
        }

        setState(() {
          for (int i = itemsToRemove.length - 1; i >= 0; i--) {
            int removeIndex = itemsToRemove[i];
            categoryItems.removeAt(removeIndex); // 아이템 삭제
            checkedItems[category]!.removeAt(removeIndex); // 체크 상태 삭제
            strikeThroughItems[category]!.removeAt(removeIndex); // 취소선 삭제
          }

          // 카테고리에 남아있는 아이템이 없으면 해당 카테고리를 삭제
          if (categoryItems.isEmpty) {
            itemLists.remove(category);
            checkedItems.remove(category);
            strikeThroughItems.remove(category);
          } else {
            itemLists[category] = categoryItems;
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템이 삭제되었습니다.')),
      );
    } catch (e) {
      print('아이템 삭제 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  void stopShoppingListDeleteMode() {
    if (!mounted) return;
    setState(() {
      showCheckBoxes = false;
    });
  }

  void _initializeCheckAndStrikeThrough(String category) {
    if (!checkedItems.containsKey(category) ||
        checkedItems[category]!.length != itemLists[category]!.length) {
      checkedItems[category] =
          List<bool>.filled(itemLists[category]!.length, false);
    }
    if (!strikeThroughItems.containsKey(category) ||
        strikeThroughItems[category]!.length != itemLists[category]!.length) {
      strikeThroughItems[category] =
          List<bool>.filled(itemLists[category]!.length, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
        onTap: () {
          if (showCheckBoxes) {
            stopShoppingListDeleteMode(); // 빈 곳을 클릭할 때 삭제 모드 해제
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text('장보기 목록'),
                SizedBox(width: 20),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: fridgeName.contains(selectedFridge)
                        ? selectedFridge
                        : null,
                    items: fridgeName.map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(section,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(), // 반복문을 통해 DropdownMenuItem 생성
                    onChanged: (value) async {
                      String? fridgeId =
                          await fetchFridgeId(value!); // 🔹 새 ID 가져오기
                      setState(() {
                        selectedFridge = value;
                        selected_fridgeId = fridgeId; // 🔹 변경된 냉장고 ID 저장
                      });
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.setString(
                          'selectedFridge', value); // 🔹 새 냉장고 저장
                    },
                    decoration: InputDecoration(
                      labelText: '냉장고 선택',
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: _buildSections(), // 섹션 동적으로 생성
          ),

          // 물건 추가 버튼
          floatingActionButton:
              !showCheckBoxes || !shouldShowMoveToFridgeButton()
                  ? FloatingAddButton(
                      heroTag: 'shopping_add_button',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddItem(
                              pageTitle: '장보기 목록에 추가',
                              addButton: '장보기 목록에 추가',
                              sourcePage: 'shoppingList',
                              onItemAdded: () {},
                            ),
                            fullscreenDialog: true, // 모달 다이얼로그처럼 보이게 설정
                          ),
                        );
                        setState(() {
                          itemLists.clear(); // 중복 방지를 위해 아이템 리스트 초기화
                          checkedItems.clear(); // 체크박스 상태 초기화
                          strikeThroughItems.clear(); // 취소선 상태 초기화
                          _loadItemsFromFirestore(userId);
                        });
                      },
                    )
                  : null,
          bottomNavigationBar: showCheckBoxes && shouldShowMoveToFridgeButton()
              ? Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: NavbarButton(
                          buttonTitle: '${fridgeName ?? "선택된 냉장고"} 로 이동',
                          onPressed: () {
                            _addItemsToFridge();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomeScreen()),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      NavbarButton(
                        buttonTitle: '삭제',
                        onPressed: () async {
                          await _deleteSelectedItems();
                        },
                      ),
                    ],
                  ),
                )
              : null,
        ));
  }

  Widget _buildSections() {
    return Column(
      children: itemLists.keys.map((category) {
        return Column(
          children: [
            _buildSectionTitle(category), // 카테고리 타이틀
            _buildGrid(itemLists[category]!, category), // 해당 카테고리의 아이템 렌더링
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹 기준 너비 설정
      double spacing = isWeb ? 4.0 : 8.0; // 웹에서는 더 좁은 간격

      return Padding(
        padding: EdgeInsets.only(left: 8, top: spacing, bottom: spacing),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            SizedBox(width: 10), // 제목과 수평선 사이 간격
            Expanded(
              child: Divider(
                thickness: 2, // 수평선 두께
                color: Colors.grey, // 수평선 색상
              ),
            ),
          ],
        ),
      );
    });
  }

  // 물건을 추가할 수 있는 그리드
  Widget _buildGrid(List<String> items, String category) {
    final theme = Theme.of(context);
    _initializeCheckAndStrikeThrough(category);
    if (items.isEmpty) {
      return Container();
    }
    if (!checkedItems.containsKey(category) ||
        checkedItems[category]!.length != items.length) {
      checkedItems[category] =
          List<bool>.filled(items.length, false, growable: true); // 수정!
    }
    if (!strikeThroughItems.containsKey(category) ||
        strikeThroughItems[category]!.length != items.length) {
      strikeThroughItems[category] =
          List<bool>.filled(items.length, false, growable: true); // 수정!
    }

    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600;
      double crossAxisSpacing = isWeb ? 4.0 : 8.0;
      double mainAxisSpacing = isWeb ? 2.0 : 8.0;
      double childAspectRatio = isWeb ? 12 : 9; // 웹에서 더 좁은 비율

      return Padding(
        padding: EdgeInsets.only(left: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: isWeb ? 2.0 : 8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: mainAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  strikeThroughItems[category]![index] =
                      !strikeThroughItems[category]![index];
                  checkedItems[category]![index] = strikeThroughItems[
                      category]![index]; // 취소선 상태에 따라 체크박스 업데이트

                  // Firestore에서 isChecked 값 업데이트
                  String itemName = items[index];
                  _updateIsCheckedInFirestore(
                      itemName, strikeThroughItems[category]![index]);
                });
              },
              onLongPress: () {
                setState(() {
                  if (showCheckBoxes) {
                    // 체크박스가 보이는 상태일 때 다시 누르면 체크박스 숨김
                    showCheckBoxes = false;

                    // 모든 checkedItems를 false로 초기화
                    checkedItems.forEach((category, checkedList) {
                      for (int i = 0; i < checkedList.length; i++) {
                        checkedList[i] = false;
                      }
                    });

                    // 냉장고로 이동 버튼을 감추기 위해 UI를 갱신
                  } else {
                    // 체크박스를 다시 보이게 할 때는 취소선이 있는 아이템 체크박스 true로 설정
                    showCheckBoxes = true;
                    _selectStrikeThroughItems(); // 취소선이 있는 아이템 체크박스 true
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    if (showCheckBoxes)
                      Checkbox(
                        value: checkedItems[category]![index], // 체크 상태
                        onChanged: (bool? value) {
                          setState(() {
                            checkedItems[category]![index] =
                                value!; // 체크박스 업데이트
                          });
                        },
                      ),
                    Expanded(
                      child: Text(
                        items[index],
                        style: TextStyle(
                            decoration: strikeThroughItems[category]![index]
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationThickness: 2.0, // 취소선의 두께
                            decorationColor: theme.colorScheme.onSurface,
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}
