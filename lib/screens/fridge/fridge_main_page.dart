import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/models/fridge_category_model.dart';
import 'package:food_for_later_new/screens/fridge/fridge_category_search.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/screens/fridge/fridge_item_details.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FridgeMainPage extends StatefulWidget {
  FridgeMainPage({Key? key}) : super(key: key);
  // static void stopDeleteMode() {
    // stopDeleteMode();
  // }
  @override
  FridgeMainPageState createState() => FridgeMainPageState();
}

class FridgeMainPageState extends State<FridgeMainPage>
    with RouteAware, SingleTickerProviderStateMixin {
  DateTime currentDate = DateTime.now();
  // late final DeleteModeObserver _deleteModeObserver;
  // 카테고리 리스트
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<String> fridgeName = [];
  String? selectedFridge = '';
  String? selectedFoodStatusManagement = '';

  List<FridgeCategory> storageSections = [];
  FridgeCategory? selectedSection;

  List<List<Map<String, dynamic>>> itemLists = [[], [], []];

  List<String> selectedItems = [];
  bool isDeletedMode = false;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _loadSelectedFridge();
    _loadCategoriesFromFirestore();
    _loadFridgeNameFromFirestore();
    _loadCategoriesAndFridgeData();

    // 애니메이션 초기화
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    ); // 애니메이션을 반복하도록 설정

    _animation = Tween(begin: -0.2, end: 0.1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticInOut,
    ));

    setState(() {
      isDeletedMode = false;
    });
    // WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didPopNext() { // 다른 페이지로 이동했다가 다시 이 페이지로 돌아올 때 호출
    super.didPopNext();
    stopDeleteMode();
    _loadSelectedFridge();
  }

  @override
  void dispose() { // 페이지가 완전히 사라지거나 소멸될 때 호출
    routeObserver.unsubscribe(this);
    if (isDeletedMode) {
      stopDeleteMode();
    }
    _loadSelectedFridge();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() { // 이 페이지에서 사용되는 종속성이 변경될 때 호출됩니다
    super.didChangeDependencies();
    // routeObserver 구독을 설정하여 내비게이션 변경 감지
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  void _loadCategoriesAndFridgeData() async {
    await _loadCategoriesFromFirestore();
  }

  Future<void> _loadFridgeCategoriesFromFirestore(String? fridgeId) async {
    final fridgeId = selectedFridge;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .where('FridgeId', isEqualTo: fridgeId)
          .get(); // 해당 유저 ID에 맞는 냉장고 데이터

      if (!mounted) return;
      List<Map<String, dynamic>> items =
          snapshot.docs.map((doc) => doc.data()).toList();

      if (storageSections.isEmpty) {
        print("storageSections is empty. Make sure it's loaded.");
        return;
      }
      setState(() {
        itemLists =
            List.generate(storageSections.length, (_) => [], growable: true);
      });

      for (var itemData in items) {
        if (!mounted) return;
        String fridgeCategoryId = itemData['fridgeCategoryId'] ?? '기타';
        String itemName = itemData['items'] ?? 'Unknown Item';
        Timestamp registrationTimestamp = itemData['registrationDate'] ?? Timestamp.now();
        DateTime registrationDate = registrationTimestamp.toDate();
        
        try {
          final foodsSnapshot = await FirebaseFirestore.instance
              .collection('foods')
              .where('foodsName', isEqualTo: itemName)
              .get();

          if (!mounted) return;
          if (foodsSnapshot.docs.isNotEmpty) {
            final foodsData = foodsSnapshot.docs.first.data();
            // int expirationDate = foodsData['expirationDate'] ?? 0;
            int shelfLife = foodsData['shelfLife'] ?? 0;

            // fridgeCategoryId가 storageSections의 categoryName과 일치하는지 확인
            int index = storageSections.indexWhere(
                (section) => section.categoryName == fridgeCategoryId);

            if (index >= 0) {
              setState(() {
                itemLists[index].add({
                  'itemName': itemName,
                  'shelfLife': shelfLife,
                  'registrationDate': registrationDate,
                });
              });
            } else {
              print("Category not found: $fridgeCategoryId");
            }
          } else {
            print("Item not found in foods collection: $itemName");
          }
        } catch (e) {
          print('Error fetching or processing food data for $itemName: $e');
        }
      }
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
    setState(() {
      selectedFridge = prefs.getString('selectedFridge');
      if (selectedFridge == null || !fridgeName.contains(selectedFridge)) {
        selectedFridge = fridgeName.isNotEmpty ? fridgeName.first : '기본 냉장고';
      }
      selectedFoodStatusManagement = prefs.getString('selectedFoodStatusManagement') ?? '소비기한 기준';
    });
    _loadFridgeCategoriesFromFirestore(selectedFridge); // 냉장고 데이터 로드
  }

  //냉장고 내부 구분
  Future<void> _loadCategoriesFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('fridge_categories').get();

    final categories = snapshot.docs.map((doc) {
      return FridgeCategory.fromFirestore(doc);
    }).toList();

    setState(() {
      storageSections = categories;
    });
  }

  Future<void> _loadFridgeNameFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('fridges')
            .where('userId', isEqualTo: userId)
            .get();

    List<String> fridgeList = snapshot.docs.map((doc) {
      return (doc['FridgeName'] ?? 'Unknown Fridge')
          as String; // 명시적으로 String 타입으로 변환
    }).toList();

    if (!mounted) return;
    setState(() {
      fridgeName = fridgeList; // fridgeName 리스트에 저장
    });
  }

  Future<DateTime?> getRegistrationDate(String itemId) async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('fridge_items')
          .doc(itemId)
          .get();

      // registrationDate 필드를 DateTime 형식으로 변환
      if (document.exists && document.data() != null) {
        Timestamp timestamp = document['registrationDate'];
        DateTime registrationDate = timestamp.toDate();
        return registrationDate;
      } else {
        print("문서가 존재하지 않거나 데이터가 없음.");
        return null;
      }
    } catch (e) {
      print("오류 발생: $e");
      return null;
    }
  }

  void refreshFridgeItems() {
    _loadFridgeCategoriesFromFirestore(selectedFridge); // 아이템 목록 새로고침
  }

  // 유통기한에 따른 색상 결정 함수
  Color _getBackgroundColor(int shelfLife, DateTime registrationDate) {
    int dayLeft;
    final today = DateTime.now();

    if (selectedFoodStatusManagement == '소비기한 기준') {
      // 소비기한 기준으로 dayLeft를 남은 일수로 계산
      dayLeft = shelfLife - today.difference(registrationDate).inDays;

      // 소비기한 기준 색상 설정
      if (dayLeft > 3) {
        return Colors.green; // 3일 초과 남았을 때: 녹색
      } else if (dayLeft == 3) {
        return Colors.yellow; // 3일 남았을 때: 노랑색
      } else {
        return Colors.red; // 소비기한이 지나거나 3일 미만 남았을 때: 빨강색
      }
    } else {
      // 유통기한 기준으로 dayLeft를 등록일 기준으로 계산
      dayLeft = today.difference(registrationDate).inDays;
      
      // 입고일 기준 색상 설정
      if (dayLeft >= 0 && dayLeft <= 7) {
        return Colors.green; // 1~7일: 녹색
      } else if (dayLeft >= 8 && dayLeft <= 10) {
        return Colors.yellow; // 8~10일: 노랑색
      } else {
        return Colors.red; // 11일 이상: 빨강색
      }
    }
  }

// 삭제 모드에서 선택된 아이템들을 삭제하기 전에 확인 다이얼로그를 띄우는 함수
  Future<void> _confirmDeleteItems() async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('삭제 확인'),
          content: Text('선택된 아이템들을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop(false); // 취소 시 false 반환
              },
            ),
            TextButton(
              child: Text('삭제'),
              onPressed: () {
                _deleteSelectedItems();
                Navigator.of(context).pop(true); // 삭제 시 true 반환
              },
            ),
          ],
        );
      },
    );
    // 사용자가 삭제를 확인했을 때만 삭제 작업을 진행
    if (confirmDelete) {
      _deleteSelectedItems(); // 실제 삭제 로직 실행
      setState(() {
        isDeletedMode = false; // 삭제 작업 후 삭제 모드 해제
      });
    }
  }

  // 삭제 모드에서 선택된 아이템들을 삭제하는 함수
  void _deleteSelectedItems() async {
    if (selectedItems == null || selectedItems.isEmpty) {
      print("선택된 아이템이 없습니다. 삭제할 수 없습니다.");
      return;
    }

    List<String> itemsToDelete = List.from(selectedItems);

    try {
      for (String item in itemsToDelete) {
        final snapshot = await FirebaseFirestore.instance
            .collection('fridge_items')
            .where('items', isEqualTo: item) // 선택된 아이템 이름과 일치하는 문서 검색
            .where('FridgeId', isEqualTo: selectedFridge) // 선택된 냉장고 ID 필터
            .where('userId', isEqualTo: userId)
            .get();

        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            await FirebaseFirestore.instance
                .collection('fridge_items')
                .doc(doc.id) // 문서 ID로 삭제
                .delete();
          }
        }
      }
      // 로컬 상태에서도 삭제
      setState(() {
        for (String item in itemsToDelete) {
          for (var section in itemLists) {
            section.removeWhere((map) => map.keys.first == item);
          }
        }
        selectedItems.clear(); // 선택된 아이템 목록 초기화
        isDeletedMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('선택된 아이템이 삭제되었습니다.')),
      );
    } catch (e) {
      print('Error deleting items from Firestore: $e');
    }
  }

  // 삭제 모드에서 애니메이션을 시작
  void _startDeleteMode() {
    setState(() {
      isDeletedMode = true;
      _controller.repeat(reverse: true); // 애니메이션 시작
    });
  }

// 삭제 모드를 해제하고 애니메이션을 중지
  void stopDeleteMode() {
    if (!mounted) return;
    setState(() {
      isDeletedMode = false;
      selectedItems.clear();
      _controller.stop(); // 애니메이션 중지
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
        onTap: () {
      if (isDeletedMode) {
        stopDeleteMode(); // 빈 곳을 클릭할 때 삭제 모드 해제
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('냉장고 관리'),
            SizedBox(width: 20),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: fridgeName.contains(selectedFridge) ? selectedFridge : fridgeName.isNotEmpty ? fridgeName.first : null,
                items: fridgeName.map((section) {
                  return DropdownMenuItem(
                    value: section,
                    child: Text(section,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                  );
                }).toList(), // 반복문을 통해 DropdownMenuItem 생성
                onChanged: (value) {
                  setState(() {
                    selectedFridge = value!;
                    _loadFridgeCategoriesFromFirestore(selectedFridge!);
                  });
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
      floatingActionButton: !isDeletedMode
          ? FloatingAddButton(
              heroTag: 'fridge_add_button',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddItem(
                      pageTitle: '냉장고에 추가',
                      addButton: '냉장고에 추가',
                      sourcePage: 'fridge',
                      onItemAdded: () {
                        _loadFridgeCategoriesFromFirestore(
                            selectedFridge ?? '기본 냉장고');
                      },
                    ),
                  ),
                );
                setState(() {
                  _loadFridgeCategoriesFromFirestore(
                      selectedFridge ?? '기본 냉장고');
                });
              },
            )
          : null,

      bottomNavigationBar: isDeletedMode
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: NavbarButton(
                  buttonTitle: '삭제 하기',
                  onPressed: _confirmDeleteItems,
                ),
              ),
            )
          : null,
    ));
  }

  Widget _buildSections() {
    return Column(
      children: List.generate(storageSections.length, (index) {
        return Column(
          children: [
            _buildSectionTitle(storageSections[index].categoryName), // 섹션 타이틀
            _buildDragTargetSection(index), // 드래그 타겟으로 각 섹션 구성
          ],
        );
      }),
    );
  }

  // 각 섹션의 타이틀 빌드
  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
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
  }

  Widget _buildGridForSection(List<Map<String, dynamic>> items, int sectionIndex) {
    return LayoutBuilder(
        builder: (context, constraints) {
          // 화면 크기나 플랫폼에 따라 crossAxisCount와 itemSize 조정
          bool isWeb = constraints.maxWidth > 600; // 임의의 기준 너비 설정
          double maxCrossAxisExtent = isWeb ? 200 : 70;
          double childAspectRatio = 1.0; // 웹에서 항목 크기 조정

      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent, // 한 줄에 5칸
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          String currentItem = items[index]['itemName'] ?? 'Unknown Item'; // 아이템 이름
          // int expirationDays = items[index].values.first;
          int shelfLife = items[index]['shelfLife'] ?? 0;
          DateTime registrationDate = items[index]['registrationDate'] ?? DateTime.now();
          bool isSelected = selectedItems.contains(currentItem);
          String formattedDate = DateFormat('yyyy-MM-dd').format(registrationDate);

          return AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: isDeletedMode && isSelected
                    ? Offset(0, _animation.value * 10) // Vertical shake
                    : Offset(0, 0), // 흔들림 효과
                child: child,
              );
            },
            child: Draggable<String>(
              data: currentItem, // 드래그할 데이터 (현재 아이템 이름)
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[200],
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AutoSizeText(
                      currentItem,
                      style: TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6, // 최소 글자 크기 설정
                      maxFontSize: 16, // 최대 글자 크기 설정
                    ),
                  ),
                ),
              ),
              childWhenDragging: Container(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: AutoSizeText(
                    currentItem,
                    style: TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    minFontSize: 6,
                    maxFontSize: 16,
                  ),
                ),
              ),
              child: GestureDetector(
                onLongPress: () {
                  setState(() {
                    if (isDeletedMode) {
                      stopDeleteMode();
                    } else {
                      _startDeleteMode(); // 삭제 모드를 시작합니다.
                      selectedItems.add(currentItem); // 현재 아이템을 선택 상태로 설정
                    }
                  });
                },
                onTap: () {
                  if (isDeletedMode) {
                    setState(() {
                      if (selectedItems.contains(currentItem)) {
                        selectedItems.remove(currentItem);
                      } else {
                        selectedItems.add(currentItem);
                      }
                    });
                  }
                },
                onDoubleTap: () async {
                  try {
                    // Firestore에서 현재 선택된 아이템의 정보를 불러옵니다.
                    final foodsSnapshot = await FirebaseFirestore.instance
                        .collection('foods')
                        .where('foodsName',
                            isEqualTo: currentItem) // 현재 아이템과 일치하는지 확인
                        .get();

                    if (foodsSnapshot.docs.isNotEmpty) {
                      final foodsData = foodsSnapshot.docs.first.data();

                      // Firestore에서 불러온 데이터를 동적으로 할당
                      String defaultCategory =
                          foodsData['defaultCategory'] ?? '기타';
                      String defaultFridgeCategory =
                          foodsData['defaultFridgeCategory'] ?? '기타';
                      String shoppingListCategory =
                          foodsData['shoppingListCategory'] ?? '기타';
                      // int expirationDays = foodsData['expirationDate'] ?? 0;
                      int shelfLife = foodsData['shelfLife'] ?? 0;
                      DateTime registrationDate = items[index]['registrationDate'] ?? DateTime.now();

                      // FridgeItemDetails로 동적으로 데이터를 전달
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FridgeItemDetails(
                            foodsName: currentItem, // 아이템 이름
                            foodsCategory: defaultCategory, // 동적 카테고리
                            fridgeCategory: defaultFridgeCategory, // 냉장고 섹션
                            shoppingListCategory:
                                shoppingListCategory, // 쇼핑 리스트 카테고리
                            // expirationDays: expirationDays, // 유통기한
                            consumptionDays: shelfLife, // 소비기한
                            registrationDate: formattedDate,
                          ),
                        ),
                      );
                    } else {
                      print("Item not found in foods collection: $currentItem");
                    }
                  } catch (e) {
                    print('Error fetching food details: $e');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDeletedMode && isSelected
                        ? Colors.orange
                        : _getBackgroundColor(shelfLife, registrationDate),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: AutoSizeText(
                      currentItem,
                      style: TextStyle(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6,
                      maxFontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
        },
    );
  }

  Widget _buildDragTargetSection(int sectionIndex) {
    return DragTarget<String>(
      onAccept: (draggedItem) async {
        setState(() {
          // 해당 섹션으로 아이템 이동
          if (!itemLists[sectionIndex]
              .any((map) => map['items'] == draggedItem)) {
            itemLists[sectionIndex].add(
                {'items': draggedItem, 'expirationDate': 7}); // 예시로 7일 유통기한 설정
          }

          // 기존 섹션에서 아이템 제거
          for (var section in itemLists) {
            section.removeWhere((item) => item['items'] == draggedItem);
          }
        });

        // Firestore에서 fridgeCategoryId 업데이트
        String newFridgeCategoryId = storageSections[sectionIndex].categoryName;

        try {
          // Firestore에서 해당 아이템을 찾아 fridgeCategoryId 업데이트
          QuerySnapshot snapshot = await FirebaseFirestore.instance
              .collection('fridge_items')
              .where('items', isEqualTo: draggedItem)
              .get();

          if (snapshot.docs.isNotEmpty) {
            String docId = snapshot.docs.first.id;

            // fridgeCategoryId 업데이트
            await FirebaseFirestore.instance
                .collection('fridge_items')
                .doc(docId)
                .update({'fridgeCategoryId': newFridgeCategoryId});

            refreshFridgeItems();
          }
        } catch (e) {
          print('Error updating fridgeCategoryId: $e');
        }
      },
      builder: (context, candidateData, rejectedData) {
        return _buildGridForSection(
            itemLists[sectionIndex], sectionIndex); // 섹션 내 그리드 빌드
      },
    );
  }

  Widget _buildItem(String itemName, int shelfLife, DateTime registrationDate) {
    return Container(
      decoration: BoxDecoration(
        color: _getBackgroundColor(shelfLife, registrationDate),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Text(
          itemName,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  // 물건을 추가할 수 있는 그리드
  Widget _buildGrid(int sectionIndex, DateTime registrationDate) {
    if (sectionIndex >= itemLists.length) {
      return Container(); // 인덱스가 범위를 벗어나면 빈 컨테이너 반환
    }

    List<Map<String, dynamic>> items = itemLists[sectionIndex] ?? [];
    return DragTarget<String>(
      onAccept: (data) async {
        setState(() {
          if (!itemLists[sectionIndex].any((map) => map.keys.first == data)) {
            itemLists[sectionIndex].add({data: 7});
          }

          for (var section in itemLists) {
            section.removeWhere((item) => item.keys.first == data);
          }
        });

        // 드래그한 항목의 fridgeCategoryId 업데이트
        String newFridgeCategoryId = storageSections[sectionIndex].categoryName;

        try {
          // Firestore에서 해당 아이템을 찾아 fridgeCategoryId를 업데이트
          QuerySnapshot snapshot = await FirebaseFirestore.instance
              .collection('fridge_items')
              .where('items', isEqualTo: data)
              .get();

          if (snapshot.docs.isNotEmpty) {
            // 해당 아이템의 문서 ID 가져오기
            String docId = snapshot.docs.first.id;

            // fridgeCategoryId 업데이트
            await FirebaseFirestore.instance
                .collection('fridge_items')
                .doc(docId)
                .update({'fridgeCategoryId': newFridgeCategoryId});
          } else {
            print("Item not found in fridge_items collection: $data");
          }
        } catch (e) {
          print("Error updating fridgeCategoryId: $e");
        }
      },
      builder: (context, candidateData, rejectedData) {
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // 한 줄에 5칸
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            String currentItem = items[index].keys.first ?? 'Unknown Item';
            int expirationDays = items[index][currentItem]!;
            bool isSelected = selectedItems.contains(currentItem);

            return Draggable<String>(
              data: currentItem,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[200],
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black26,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      currentItem,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              childWhenDragging: Container(
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Text(
                    currentItem,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              child: GestureDetector(
                onLongPress: () {
                  setState(() {
                    // 삭제 모드 전환 및 해제
                    if (isDeletedMode) {
                      isDeletedMode = false; // 삭제 모드 해제
                      selectedItems.clear(); // 선택된 아이템 목록 초기화
                    } else {
                      isDeletedMode = true; // 삭제 모드로 전환
                      selectedItems.add(currentItem);
                    }
                  });
                },
                onTap: () {
                  if (isDeletedMode) {
                    setState(() {
                      if (selectedItems.contains(currentItem)) {
                        selectedItems.remove(currentItem); // 선택 해제
                      } else {
                        selectedItems.add(currentItem); // 선택
                      }
                    });
                  }
                },
                onDoubleTap: () async {
                  try {
                    // Firestore에서 현재 선택된 아이템의 정보를 불러옵니다.
                    final foodsSnapshot = await FirebaseFirestore.instance
                        .collection('foods')
                        .where('foodsName',
                            isEqualTo: currentItem) // 현재 아이템과 일치하는지 확인
                        .get();

                    if (foodsSnapshot.docs.isNotEmpty) {
                      final foodsData = foodsSnapshot.docs.first.data();

                      // Firestore에서 불러온 데이터를 동적으로 할당
                      String defaultCategory =
                          foodsData['defaultCategory'] ?? '기타';
                      String defaultFridgeCategory =
                          foodsData['defaultFridgeCategory'] ?? '기타';
                      String shoppingListCategory =
                          foodsData['shoppingListCategory'] ?? '기타';
                      // int expirationDays = foodsData['expirationDate'] ?? 0;
                      int shelfLife = foodsData['shelfLife'] ?? 0;
                      DateTime registrationDate = items[index]['registrationDate'] ?? DateTime.now();
                      String formattedDate = DateFormat('yyyy-MM-dd').format(registrationDate);
                      // FridgeItemDetails로 동적으로 데이터를 전달
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FridgeItemDetails(
                            foodsName: currentItem, // 아이템 이름
                            foodsCategory: defaultCategory, // 동적 카테고리
                            fridgeCategory: defaultFridgeCategory, // 냉장고 섹션
                            shoppingListCategory:
                                shoppingListCategory, // 쇼핑 리스트 카테고리
                            // expirationDays: expirationDays, // 유통기한
                            consumptionDays: shelfLife, // 소비기한
                            registrationDate: formattedDate,
                          ),
                        ),
                      );
                    } else {
                      print("Item not found in foods collection: $currentItem");
                    }
                  } catch (e) {
                    print('Error fetching food details: $e');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDeletedMode && isSelected
                        ? Colors.orange // 삭제 모드에서 선택된 항목은 주황색
                        : _getBackgroundColor(expirationDays, registrationDate),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Text(
                      currentItem,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class DeleteModeObserver extends NavigatorObserver {
  final VoidCallback onPageChange;

  DeleteModeObserver({required this.onPageChange});

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    onPageChange();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    onPageChange();
  }
}
