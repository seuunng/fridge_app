import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/components/floating_button_with_arrow.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/main.dart';
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
  List<Map<String, dynamic>> recentlyDeletedItems = [];
  String userRole = '';

  // String? selectedFridge = '';
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
    print('initState() 에서 _loadItemsFromFirestore 실행');
    _loadCategoriesFromFirestore();
    _loadFridgeCategoriesFromFirestore(userId).then((_) {
      // _loadSelectedFridge(); // 🔹 냉장고 목록을 불러온 후 기본값 설정
    });
    _loadFridgeId();
    setState(() {
      showCheckBoxes = false;
    });
    _loadUserRole();
  }
  @override
  void didPopNext() {
    super.didPopNext();
    stopShoppingListDeleteMode();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // routeObserver 구독 해제
    super.dispose();
  }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadItemsFromFirestore(userId).then((_) {
      if (mounted) {
        setState(() {}); // ✅ 올바르게 닫음
      }
    });
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }
  void refreshShoppingList() {
    print("🛒 장보기 목록 새로고침 실행");
    _loadItemsFromFirestore(userId);
    if (mounted) {
      setState(() {}); // UI 강제 갱신
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

  Future<void> _loadFridgeId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // 유저의 첫 번째 냉장고 ID 사용
        setState(() {
          selected_fridgeId = snapshot.docs.first.id;
        });
      } else {
        throw Exception('사용자 냉장고가 존재하지 않습니다.');
      }
    } catch (e) {
      print('냉장고 ID 로드 중 오류 발생: $e');
    }
  }
  Future<void> _loadItemsFromFirestore(String userId) async {
    try {
      // 🔹 Firestore에서 쇼핑 목록 가져오기 (현재 유저의 데이터만 필터링)
      final snapshot = await FirebaseFirestore.instance
          .collection('shopping_items')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> allItems = [];
      Set<String> processedItemIds = {}; // 중복 방지를 위한 Set

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final itemName = data['items']?.toString() ?? 'Unknown Item';
        final isChecked = data['isChecked'] ?? false;

        Map<String, dynamic>? foodData;
        String? foodDocId;

        // 🔍 1. `foods` 컬렉션에서 검색 (사용자 정의 아이템)
        final foodsSnapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where('foodsName', isEqualTo: itemName)
            .get();

        if (foodsSnapshot.docs.isNotEmpty) {
          // ✅ 사용자 데이터가 있는 경우
          foodData = foodsSnapshot.docs.first.data();
          foodDocId = foodsSnapshot.docs.first.id;
        } else {
          // 🔍 2. `default_foods`에서 검색 (기본 아이템)
          final defaultFoodsSnapshot = await FirebaseFirestore.instance
              .collection('default_foods')
              .where('foodsName', isEqualTo: itemName)
              .get();

          if (defaultFoodsSnapshot.docs.isNotEmpty) {
            foodData = defaultFoodsSnapshot.docs.first.data();
            foodDocId = defaultFoodsSnapshot.docs.first.id;
          }
        }
        if (foodDocId != null && processedItemIds.contains(foodDocId)) {
          // 이미 추가된 아이템이면 건너뛰기
          continue;
        }

        processedItemIds.add(foodDocId ?? itemName); // 중복 방지


        // 데이터가 없는 경우 "기타"로 처리
        final category = foodData?['shoppingListCategory'] ?? '기타';

        allItems.add({
          'category': category,
          'itemName': itemName,
          'isChecked': isChecked,
        });
      }

      // 🔹 쇼핑 카테고리 기준으로 그룹화
      setState(() {
        itemLists.clear(); // ✅ 기존 데이터 초기화
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

      groupedItems.putIfAbsent(category, () => []).add(itemName);
    }

    // 🔹 카테고리 순서를 미리 정의된 순서에 맞게 정렬a
    Map<String, List<String>> sortedGroupedItems = {
      for (var category in predefinedCategoryOrder)
        if (groupedItems.containsKey(category)) category: groupedItems[category]!,
    };

    // 🔹 정렬되지 않은 나머지 카테고리 추가
    groupedItems.forEach((category, items) {
      if (!sortedGroupedItems.containsKey(category)) {
        sortedGroupedItems[category] = items;
      }
    });

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

//   void _loadSelectedFridge() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
//
//     String? savedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
//
//     // 🔹 Firestore에서 해당 냉장고 ID 가져오기
//     String? fridgeId = await fetchFridgeId(savedFridge);
//
// // 🔹 fridgeName 리스트가 비어있지 않다면 기본값 설정
//     if (fridgeName.isNotEmpty && !fridgeName.contains(savedFridge)) {
//       savedFridge = fridgeName.first; // 🔹 리스트의 첫 번째 냉장고를 기본값으로 설정
//       fridgeId = await fetchFridgeId(savedFridge);
//     }
//
//     setState(() {
//       selectedFridge = savedFridge;
//       selected_fridgeId = fridgeId; // 🔹 ID 업데이트
//     });
//   }

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
    Set<String> duplicateItems = {}; // 중복된 아이템 목록 저장
    // final fridgeId = selected_fridgeId;

    // if (fridgeId == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text('선택된 냉장고를 찾을 수 없습니다.')),
    //   );
    //   return;
    // }

    try {
      for (var category in checkedItems.keys) {
        List<String> categoryItems = List<String>.from(itemLists[category] ?? []);

        for (int index = 0; index < checkedItems[category]!.length; index++) {
          if (checkedItems[category]![index]) {
            String itemName = categoryItems[index];

            // 🔍 1. `foods` 컬렉션에서 검색
            final foodsSnapshot = await FirebaseFirestore.instance
                .collection('foods')
                .where('foodsName', isEqualTo: itemName)
                .get();

            Map<String, dynamic>? foodData;

            if (foodsSnapshot.docs.isNotEmpty) {
              foodData = foodsSnapshot.docs.first.data(); // ✅ 사용자 데이터 사용
            } else {
              // 🔍 2. `default_foods`에서 검색
              final defaultFoodsSnapshot = await FirebaseFirestore.instance
                  .collection('default_foods')
                  .where('foodsName', isEqualTo: itemName)
                  .get();

              if (defaultFoodsSnapshot.docs.isNotEmpty) {
                foodData = defaultFoodsSnapshot.docs.first.data();
              }
            }

            final fridgeCategoryId = foodData?['defaultFridgeCategory'] ?? '냉장';
// 🔍 3. `fridge_items`에서 동일한 아이템이 있는지 확인
            final existingItemSnapshot = await FirebaseFirestore.instance
                .collection('fridge_items')
                .where('items', isEqualTo: itemName)
                .where('FridgeId', isEqualTo: selected_fridgeId) // 같은 냉장고 내에서 중복 확인
                .get();

            if (existingItemSnapshot.docs.isNotEmpty) {
              // print('⚠️ 중복 아이템: $itemName -> 이미 냉장고에 있음');
              duplicateItems.add(itemName); // 중복된 아이템 추가
              continue; // ❌ 이미 있으면 추가하지 않음
            }

            // 🔹 3. 냉장고에 추가
            await FirebaseFirestore.instance.collection('fridge_items').add({
              'items': itemName,
              'FridgeId':  selected_fridgeId,
              'fridgeCategoryId': fridgeCategoryId,
              'userId': userId,
              'registrationDate': Timestamp.fromDate(DateTime.now()),
            });

            // 🔹 4. 장보기 목록에서 삭제
            await _deleteShoppingItem(itemName);
          }
        }
      }
      for (var duplicate in duplicateItems) {
        await _deleteShoppingItem(duplicate);
      }
      await _loadItemsFromFirestore(userId).then((_) {
        if (mounted) {
          setState(() {}); // UI 갱신
        }
      });
      if (duplicateItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${duplicateItems.join(', ')}은(는) 이미 냉장고에 있는 아이템입니다.',
              style: TextStyle(fontSize: 14),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('아이템 추가 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 추가 중 오류가 발생했습니다.')),
      );
    }
  }
  Future<void> _deleteShoppingItem(String itemName) async {

    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_items')
        .where('items', isEqualTo: itemName)
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in snapshot.docs) {
      await FirebaseFirestore.instance
          .collection('shopping_items')
          .doc(doc.id)
          .delete();
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
      // ✅ 새로운 삭제 항목만 저장하도록 리스트 초기화
      recentlyDeletedItems.clear();
      for (var category in checkedItems.keys.toList()) {
        List<String> categoryItems = List<String>.from(itemLists[category]!, growable: true);

        List<int> itemsToRemove = [];

        for (int index = 0; index < checkedItems[category]!.length; index++) {
          if (checkedItems[category]![index]) {
            String itemName = categoryItems[index];
// 🔹 Firestore에서 삭제 전 아이템을 임시 저장
            recentlyDeletedItems.add({
              'category': category,
              'itemName': itemName,
            });
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
        SnackBar(content: Text('아이템이 삭제되었습니다.'),
          action: SnackBarAction(
          label: '복원',
          onPressed: _restoreDeletedItems,
          ),
        ),
      );
    } catch (e) {
      print('아이템 삭제 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('아이템 삭제 중 오류가 발생했습니다.')),
      );
    }
  }
  void _restoreDeletedItems() async {
    for (var item in recentlyDeletedItems) {
      final category = item['category'];
      final itemName = item['itemName'];

      // 1. Firestore에 다시 추가
      await FirebaseFirestore.instance.collection('shopping_items').add({
        'userId': userId,
        'items': itemName,
        'isChecked': false, // 복원 시 기본값은 미체크 상태
      });

      // 2. 상태 업데이트 (UI에 다시 추가)
      setState(() {
        if (!itemLists.containsKey(category)) {
          itemLists[category] = [];
          checkedItems[category] = [];
          strikeThroughItems[category] = [];
        }
        itemLists[category]!.add(itemName);
        checkedItems[category]!.add(false);
        strikeThroughItems[category]!.add(false);
      });
    }

    recentlyDeletedItems.clear(); // 복원 후 임시 저장 리스트 초기화
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
          // appBar: AppBar(
          //   title:
          // ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text('장보기 목록',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 20, // 글자 크기 (기본보다 크게 조정)
                          fontWeight: FontWeight.bold, // 글자 굵게 설정
            
                        ),),
                    ),
                    // SizedBox(width: 20),
                    // Expanded(
                    //   child: DropdownButtonFormField<String>(
                    //     value: fridgeName.contains(selectedFridge)
                    //         ? selectedFridge
                    //         : null,
                    //     items: fridgeName.map((section) {
                    //       return DropdownMenuItem(
                    //         value: section,
                    //         child: Text(section,
                    //             style:
                    //                 TextStyle(color: theme.colorScheme.onSurface)),
                    //       );
                    //     }).toList(), // 반복문을 통해 DropdownMenuItem 생성
                    //     onChanged: (value) async {
                    //       String? fridgeId =
                    //           await fetchFridgeId(value!); // 🔹 새 ID 가져오기
                    //       setState(() {
                    //         selectedFridge = value;
                    //         selected_fridgeId = fridgeId; // 🔹 변경된 냉장고 ID 저장
                    //       });
                    //       print('Selected fridge: $selectedFridge, Fridge ID: $selected_fridgeId');
                    //       SharedPreferences prefs =
                    //           await SharedPreferences.getInstance();
                    //       await prefs.setString(
                    //           'selectedFridge', value); // 🔹 새 냉장고 저장
                    //     },
                    //     decoration: InputDecoration(
                    //       labelText: '냉장고 선택',
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              SingleChildScrollView(
              child: _buildSections(), // 섹션 동적으로 생성
            ),
            
              ],
            ),
          ),
          // 물건 추가 버튼
          floatingActionButton:
              !showCheckBoxes || !shouldShowMoveToFridgeButton()
                  ? itemLists.isEmpty || itemLists.values.every((items) => items.isEmpty)
                  ? FloatingButtonWithArrow(
                heroTag: 'shopping_add_button',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddItem(
                        pageTitle: '장보기 목록에 추가',
                        addButton: '장보기 목록에 추가',
                        sourcePage: 'shoppingList',
                          onItemAdded: () {},
                      ),
                    ),
                  );
                  setState(() {
                    itemLists.clear(); // 중복 방지를 위해 아이템 리스트 초기화
                    checkedItems.clear(); // 체크박스 상태 초기화
                    strikeThroughItems.clear(); // 취소선 상태 초기화
                    _loadItemsFromFirestore(userId);
                  });
                },
              ):
              FloatingAddButton(
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
                            // fullscreenDialog: true, // 모달 다이얼로그처럼 보이게 설정
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
          bottomNavigationBar:
              Column(
                mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if(showCheckBoxes && shouldShowMoveToFridgeButton())
                  Container(
                      color: Colors.transparent,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: NavbarButton(
                              buttonTitle: '냉장고로 이동',
                              onPressed: () async {
                                _addItemsToFridge();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => HomeScreen()
                                  ),
                                );

                                Future.delayed(Duration(milliseconds: 100), () async {
                                  await _loadItemsFromFirestore(userId);
                                  if (mounted) {
                                    setState(() {}); // ✅ UI 강제 갱신
                                  }
                                });
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
                    ),
                  if (userRole != 'admin' && userRole != 'paid_user')
                    SafeArea(
                      bottom: false, // 하단 여백 제거
                      child: BannerAdWidget(),
                    ),
                ],
              )


        ));
  }

  Widget _buildSections() {
    bool allSectionsEmpty = itemLists.isEmpty ||
        itemLists.values.every((items) => items.isEmpty);

    if (allSectionsEmpty) {
      return _buildAnimatedEmptyShoppingList(); // 모든 섹션이 비어 있으면 애니메이션 표시
    }
    return Column(
      children: itemLists.keys
          .where((category) => itemLists[category] != null && itemLists[category]!.isNotEmpty) // 아이템이 비어있지 않은 섹션만 렌더링
          .map((category) {
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
    List<dynamic> resultsWithAds = [];
    int adFrequency = 10;
    if (!checkedItems.containsKey(category) ||
        checkedItems[category]!.length != items.length) {
      checkedItems[category] =
          List<bool>.filled(items.length, false, growable: true); // 수정!
    }
    for (int i = 0; i < items.length; i++) {
      resultsWithAds.add(items[i]);
      if ((i + 1) % adFrequency == 0) {
        resultsWithAds.add('ad'); // 광고 위치를 표시하는 문자열
      }
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
            if (resultsWithAds[index] == 'ad') {
              // 광고 위젯
              if (userRole != 'admin' && userRole != 'paid_user')
                return SafeArea(
                  bottom: false, // 하단 여백 제거
                  child: BannerAdWidget(),
                );
            }
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
  Widget _buildAnimatedEmptyShoppingList() {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column 크기를 자식 크기에 맞춤
          mainAxisAlignment: MainAxisAlignment.center, // 세로 중앙 정렬
          crossAxisAlignment: CrossAxisAlignment.center, // 가로 중앙 정렬
          children: [
            Image.asset(
              'assets/shopping_cart.png',
              width: 150,
              height: 150,
            ),
            SizedBox(height: 10),
            Text(
              '장바구니가 비어 있습니다.',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '지금 물건을 추가해 보세요!',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
