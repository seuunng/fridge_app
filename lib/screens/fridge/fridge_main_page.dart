import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/components/floating_button_with_arrow.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/constants.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/models/fridge_category_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/screens/fridge/fridge_item_details.dart';
// import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FridgeMainPage extends StatefulWidget {
  FridgeMainPage({Key? key}) : super(key: key);

  @override
  FridgeMainPageState createState() => FridgeMainPageState();
}

class FridgeMainPageState extends State<FridgeMainPage>
    with RouteAware, SingleTickerProviderStateMixin {
  DateTime currentDate = DateTime.now();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<String> fridgeName = [];
  String? selectedFridge = '';
  String? selected_fridgeId = '';
  String? selectedFoodStatusManagement = '';

  List<FridgeCategory> storageSections = [];
  FridgeCategory? selectedSection;
  bool isCondimentsHidden = false;

  List<List<Map<String, dynamic>>> itemLists = [[], [], []];
  List<Map<String, dynamic>> recentlyDeletedItems = [];

  List<String> selectedItems = [];
  bool isDeletedMode = false;
  bool isDragActive = false;
  bool isDragOver = false; // 드래그 상태를 관리하는 변수
  bool hasCustomSection = false;

  late AnimationController _controller;
  late Animation<double> _animation;
  String userRole = '';
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();

    _initializeData();

    _scrollController = ScrollController();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _animation = Tween(begin: -0.2, end: 0.1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticInOut,
    ));

    setState(() {
      isDeletedMode = false;
    });
    _loadUserRole();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedFridge();
      _loadFridgeNameFromFirestore();
    });

    _loadCondimentsHiddenStatus();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    stopDeleteMode();
    _loadSelectedFridge();
    // _loadFridgeNameFromFirestore();
    _loadCategoriesFromFirestore();
    // _loadFridgeItemsFromFirestore(selected_fridgeId);
    // _reloadFridgeData();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    if (isDeletedMode) {
      stopDeleteMode();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  // Future<void> _reloadFridgeData() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     selectedFridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
  //   });
  //   if (selectedFridge != null) {
  //     selected_fridgeId = await fetchFridgeId(selectedFridge!);
  //     await _loadFridgeCategoriesFromFirestore(selected_fridgeId);
  //   }
  // }
  void _loadCondimentsHiddenStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? savedValue = prefs.getBool('isCondimentsHidden');

    if (savedValue != null) {
      setState(() {
        isCondimentsHidden = savedValue;
      });
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

  Future<void> _initializeData() async {
    await _loadFridgeId();
    await _loadCategoriesFromFirestore();
    await _loadSelectedFridge();
    await _loadFridgeItemsFromFirestore(selected_fridgeId);
    // setState(() {});
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

  Future<String?> fetchFridgeId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          // .where('FridgeName', isEqualTo: fridgeName)
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

  Future<void> _loadFridgeItemsFromFirestore(String? fridgeId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridge_items')
          .where('userId', isEqualTo: userId)
          .where('FridgeId', isEqualTo: fridgeId)
          .get(); // 해당 유저 ID에 맞는 냉장고 데이터

      if (!mounted) return;

      // ✅ 변경된 데이터를 저장할 임시 리스트 생성
      List<List<Map<String, dynamic>>> updatedItemLists =
          List.generate(storageSections.length, (_) => []);

      Set<String> processedItemIds = {};

      List<Map<String, dynamic>> items = snapshot.docs.map((doc) {
        final itemData = doc.data();
        itemData['documentId'] = doc.id; // ✅ Firestore 문서 ID 추가
        return itemData;
      }).toList();

      // if (storageSections.isEmpty) {
      //   await _loadCategoriesFromFirestore();
      // }
      // setState(() {
      //   itemLists =
      //       List.generate(storageSections.length, (_) => [], growable: true);
      // });

      for (var itemData in items) {
        String fridgeCategoryId = itemData['fridgeCategoryId'] ?? '기타';
        String itemName = itemData['items'] ?? 'Unknown Item';
        DateTime registrationDate =
            (itemData['registrationDate'] as Timestamp).toDate();
        String defaultCategory = itemData['defaultCategory'] ?? '';
        String documentId = itemData['documentId'] ?? '';

        try {
          Map<String, dynamic>? foodsData;
          String? foodDocId;

          final foodsSnapshot = await FirebaseFirestore.instance
              .collection('foods')
              .where('foodsName', isEqualTo: itemName)
              .get();

          if (foodsSnapshot.docs.isNotEmpty) {
            foodsData = foodsSnapshot.docs.first.data();
            foodDocId = foodsSnapshot.docs.first.id;
          } else {
            // ✅ 2. `foods`에 없으면 `default_foods`에서 찾기
            final defaultFoodsSnapshot = await FirebaseFirestore.instance
                .collection('default_foods')
                .where('foodsName', isEqualTo: itemName)
                .get();

            if (defaultFoodsSnapshot.docs.isNotEmpty) {
              foodsData = defaultFoodsSnapshot.docs.first.data();
              foodDocId = defaultFoodsSnapshot.docs.first.id;
            }
          }
          if (foodDocId != null && processedItemIds.contains(foodDocId)) {
            // 이미 처리된 아이템이면 건너뛰기
            continue;
          }
          processedItemIds.add(foodDocId ?? itemName); // 중복 방지

          int shelfLife = foodsData?['shelfLife'] ?? 365;
          if (foodsData != null) {
            defaultCategory = foodsData['defaultCategory'] ?? '기타';
          }

          int index = storageSections.indexWhere(
              (section) => section.categoryName == fridgeCategoryId);
          if (index >= 0) {
            updatedItemLists[index].add({
              'itemName': itemName,
              'shelfLife': shelfLife,
              'registrationDate': registrationDate,
              'defaultCategory': defaultCategory,
              'documentId': documentId
            });
          }
          // } else {
          //   int defaultIndex = storageSections.indexWhere((section) =>
          //   section.categoryName == '냉장');
          //
          // 만약 '냉장' 섹션이 존재하지 않으면 추가
          // if (defaultIndex == -1) {
          //   FridgeCategory defaultSection = FridgeCategory(
          //     id: 'default_refrigerator',
          //     categoryName: '냉장',
          //     userId: userId,
          //   );
          //
          //   setState(() {
          //     storageSections.add(defaultSection);
          //     itemLists.add([]);
          //     defaultIndex = storageSections.length - 1; // 새로 추가된 섹션의 인덱스 설정
          //   });
          // }
        } catch (e) {
          print('Error fetching or processing food data for $itemName: $e');
        }
      }
      // ✅ `setState()`를 한 번만 호출하여 한꺼번에 변경 적용
      setState(() {
        itemLists = updatedItemLists;
      });
    } catch (e) {
      print('Error loading fridge categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('냉장고 목록을 불러오는 데 실패했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    if (isCondimentsHidden) {
      return items.where((item) {
        String categoryName = item['defaultCategory'] ?? '  기타';
        return categoryName != '양념'; // 양념 카테고리 제외
      }).toList();
    }
    return items;
  }

  Future<void> _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      // selectedFridge = prefs.getString('selectedFridge');
      // if (selectedFridge == null || !fridgeName.contains(selectedFridge)) {
      //   selectedFridge = fridgeName.isNotEmpty ? fridgeName.first : '기본 냉장고';
      // }
      selectedFoodStatusManagement =
          prefs.getString('selectedFoodStatusManagement') ?? '소비기한 기준';
    });
    // if (selectedFridge != null) {
    //   selected_fridgeId = await fetchFridgeId(selectedFridge);
    // }
  }

  Future<void> _loadCategoriesFromFirestore() async {
    try {
      // 🔹 기본 카테고리 불러오기
      final defaultSnapshot = await FirebaseFirestore.instance
          .collection('default_fridge_categories')
          .get();

      final customSnapshot = await FirebaseFirestore.instance
          .collection('fridge_categories')
          .where('userId', isEqualTo: userId)
          .get();

      // 🔹 기본 카테고리 변환
      final defaultCategories = defaultSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      // 🔹 사용자 커스텀 카테고리 변환
      final customCategories = customSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      // 🔹 기본 + 커스텀 카테고리를 합쳐서 사용
      setState(() {
        hasCustomSection = customCategories.isNotEmpty;
        storageSections = [...defaultCategories, ...customCategories];
      });
    } catch (e) {
      print('카테고리 불러오기 오류: $e');
    }
  }

  Future<void> _loadFridgeNameFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fridges')
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

  void _startAutoScroll(double dragPosition) {
    const double scrollThreshold = 100.0; // 상하단에서 100px 이내에 있을 때 스크롤 시작
    const double scrollSpeed = 10.0; // 스크롤 속도 조절
    print('!_scrollController.hasClients ${!_scrollController.hasClients}');
    if (!_scrollController.hasClients) return; // ✅ 스크롤 컨트롤러가 없으면 실행 안 함

    if (_scrollController.hasClients) {
      if (dragPosition < scrollThreshold) {
        // 🔺 상단에서 드래그 시 위로 스크롤
        _scrollController.animateTo(
          _scrollController.offset - scrollSpeed,
          duration: Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      } else if (dragPosition >
          _scrollController.position.maxScrollExtent - scrollThreshold) {
        // 🔻 하단에서 드래그 시 아래로 스크롤
        _scrollController.animateTo(
          _scrollController.offset + scrollSpeed,
          duration: Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    }
  }

  void _stopAutoScroll() {
    // 스크롤을 멈출 필요 없음, `animateTo`는 한 번 실행되므로 반복적으로 호출하지 않음
  }
  Future<void> _saveNewSectionToFirestore(String sectionName) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('fridge_categories')
          .doc(); // 새로운 문서 생성

      await docRef.set({
        'id': docRef.id,
        'categoryName': sectionName,
        'userId': userId,
      });

      await _loadCategoriesFromFirestore(); // UI 새로고침

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('새 섹션이 추가되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('섹션 저장 중 오류 발생: $e');
    }
  }

  // 카테고리순 정렬
  void sortItemsByCategory() {
    setState(() {
      itemLists = itemLists.map((items) {
        items.sort((a, b) {
          int indexA = predefinedCategoryFridge.indexOf(a['defaultCategory']);
          int indexB = predefinedCategoryFridge.indexOf(b['defaultCategory']);
          if (indexA == -1) indexA = predefinedCategoryFridge.length;
          if (indexB == -1) indexB = predefinedCategoryFridge.length;
          return indexA.compareTo(indexB);
        });
        return items;
      }).toList(); // 🔹 정렬 후 리스트를 업데이트
    });
  }

  void sortItemsByRegistrationDate() {
    setState(() {
      itemLists = itemLists.map((items) {
        items.sort((a, b) {
          DateTime dateA = a['registrationDate'] is Timestamp
              ? (a['registrationDate'] as Timestamp).toDate()
              : (a['registrationDate'] ?? DateTime.now());

          DateTime dateB = b['registrationDate'] is Timestamp
              ? (b['registrationDate'] as Timestamp).toDate()
              : (b['registrationDate'] ?? DateTime.now());

          return dateA.compareTo(dateB); // 🔹 입고일 오름차순 정렬
        });
        return items;
      }).toList();
    });
  }

  // 소비기한 마감 임박순 정렬
  void sortItemsByExpiration() {
    setState(() {
      itemLists = itemLists.map((items) {
        items.sort((a, b) {
          int shelfLifeA = a['shelfLife'] ?? 365; // 기본 1년
          int shelfLifeB = b['shelfLife'] ?? 365;
          DateTime regDateA = a['registrationDate'] ?? DateTime.now();
          DateTime regDateB = b['registrationDate'] ?? DateTime.now();

          int daysLeftA =
              shelfLifeA - DateTime.now().difference(regDateA).inDays;
          int daysLeftB =
              shelfLifeB - DateTime.now().difference(regDateB).inDays;

          return daysLeftA.compareTo(daysLeftB); // 🔹 남은 일수 기준 오름차순 정렬
        });
        return items;
      }).toList();
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

  // 유통기한에 따른 색상 결정 함수
  Color _getBackgroundColor(int shelfLife, DateTime registrationDate) {
    int dayLeft;
    final today = DateTime.now();

    if (selectedFoodStatusManagement == '소비기한 기준') {
      dayLeft = shelfLife - today.difference(registrationDate).inDays;

      if (dayLeft > 3) {
        return Colors.green; // 3일 초과 남았을 때: 녹색
      } else if (dayLeft == 3) {
        return Colors.yellow; // 3일 남았을 때: 노랑색
      } else {
        return Colors.red; // 소비기한이 지나거나 3일 미만 남았을 때: 빨강색
      }
    } else {
      dayLeft = today.difference(registrationDate).inDays;

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
    final theme = Theme.of(context);
    // 삭제 모드에서 선택된 식품이 없으면 스낵바를 표시하고 함수 종료
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('선택된 식품이 없습니다. 삭제할 항목을 선택해주세요.'),
          duration: Duration(seconds: 2), // 스낵바 표시 시간
        ),
      );
      return;
    }
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '삭제 확인',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '선택된 아이템들을 삭제하시겠습니까?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
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
      // _deleteSelectedItems(); // 실제 삭제 로직 실행
      setState(() {
        isDeletedMode = false; // 삭제 작업 후 삭제 모드 해제
      });
    }
  }

  // 삭제 모드에서 선택된 아이템들을 삭제하는 함수
  void _deleteSelectedItems() async {
    // final fridgeId = selected_fridgeId;
    if (selectedItems == null || selectedItems.isEmpty) {
      print("선택된 아이템이 없습니다. 삭제할 수 없습니다.");
      return;
    }

    List<String> itemsToDelete = List.from(selectedItems);
    recentlyDeletedItems.clear(); // 복원 시 기존 데이터 정리

    try {
      for (String item in itemsToDelete) {
        final snapshot = await FirebaseFirestore.instance
            .collection('fridge_items')
            .where('items', isEqualTo: item) // 선택된 아이템 이름과 일치하는 문서 검색
            .where('FridgeId', isEqualTo: selected_fridgeId) // 선택된 냉장고 ID 필터
            .where('userId', isEqualTo: userId)
            .get();

        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            recentlyDeletedItems.add(doc.data()); // 삭제 전 데이터 저장
            await FirebaseFirestore.instance
                .collection('fridge_items')
                .doc(doc.id) // 문서 ID로 삭제
                .delete();
          }
        } else {
          print('삭제할 문서를 찾을 수 없습니다.');
        }
      }

      setState(() {
        for (String item in itemsToDelete) {
          for (var section in itemLists) {
            section.removeWhere((map) => map.keys.first == item);
          }
        }
        selectedItems.clear();
        isDeletedMode = false;
      });
      await _loadFridgeItemsFromFirestore(selected_fridgeId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('선택된 아이템이 삭제되었습니다. 복원하시겠습니까?'),
          action: SnackBarAction(
            label: '복원',
            onPressed: _restoreDeletedItems, // 복원 함수 호출
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error deleting items from Firestore: $e');
    }
  }

  void _restoreDeletedItems() async {
    try {
      for (var itemData in recentlyDeletedItems) {
        await FirebaseFirestore.instance
            .collection('fridge_items')
            .add(itemData);
      }

      setState(() {
        for (var itemData in recentlyDeletedItems) {
          String itemName = itemData['items'];
          String fridgeCategory = itemData['fridgeCategoryId'] ?? '기타';
          DateTime registrationDate =
              (itemData['registrationDate'] as Timestamp).toDate();

          int index = storageSections
              .indexWhere((section) => section.categoryName == fridgeCategory);

          if (index >= 0) {
            itemLists[index].add({
              'itemName': itemName, // 명시적으로 itemName 저장
              'registrationDate': registrationDate,
              ...itemData,
            });
          }
        }
        recentlyDeletedItems.clear(); // 복원 후 임시 리스트 초기화
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제된 아이템이 복원되었습니다.')),
      );
    } catch (e) {
      print('Error restoring items: $e');
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
          // appBar: AppBar(
          //   title:
          // ),
          body: Column(
            children: [
              Row(
                children: [
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      '냉장고 관리',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20, // 글자 크기 (기본보다 크게 조정)
                        fontWeight: FontWeight.bold, // 글자 굵게 설정
                      ),
                    ),
                  ),
                  // SizedBox(width: 20),
                  // Expanded(
                  //   child: DropdownButtonFormField<String>(
                  //     value: fridgeName.contains(selectedFridge)
                  //         ? selectedFridge
                  //         : fridgeName.isNotEmpty
                  //             ? fridgeName.first
                  //             : null,
                  //     items: fridgeName.map((section) {
                  //       return DropdownMenuItem(
                  //         value: section,
                  //         child: Text(section,
                  //             style:
                  //                 TextStyle(color: theme.colorScheme.onSurface)),
                  //       );
                  //     }).toList(), // 반복문을 통해 DropdownMenuItem 생성
                  //     onChanged: (value) async {
                  //       setState(() {
                  //         selectedFridge = value!;
                  //       });
                  //       selected_fridgeId = await fetchFridgeId(value!);
                  //       if (selected_fridgeId != null) {
                  //         _loadFridgeCategoriesFromFirestore(selected_fridgeId!);
                  //       }
                  //     },
                  //     decoration: InputDecoration(
                  //       labelText: '냉장고 선택',
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: _buildSections(), // 섹션 렌더링
                ),
              ),
              // _buildDragTargetForFridgeTransfer(),  // 냉장고 전송 드롭 영역
            ],
          ),

          floatingActionButton: (!isDeletedMode && !isDragActive)
              ? (itemLists.every((items) => _filterItems(items).isEmpty)
                  ? FloatingButtonWithArrow(
                      heroTag: 'fridge_arrow_button',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddItem(
                              pageTitle: '냉장고에 추가',
                              addButton: '냉장고에 추가',
                              sourcePage: 'fridge',
                              onItemAdded: () {
                                _loadFridgeItemsFromFirestore(
                                    selected_fridgeId);
                              },
                              selectedFridge: selectedFridge, // ✅ 전달하는 냉장고 이름
                              selectedFridgeId: selected_fridgeId,
                            ),
                          ),
                        );
                        setState(() {
                          _loadFridgeItemsFromFirestore(selected_fridgeId);
                        });
                      },
                    )
                  : FloatingAddButton(
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
                                _loadFridgeItemsFromFirestore(
                                    selected_fridgeId);
                              },
                              selectedFridge: selectedFridge, // ✅ 전달하는 냉장고 이름
                              selectedFridgeId: selected_fridgeId,
                            ),
                          ),
                        );
                        setState(() {
                          _loadFridgeItemsFromFirestore(selected_fridgeId);
                        });
                      },
                    ))
              : null,

          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
            mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
            children: [
              if (isDeletedMode)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: NavbarButton(
                      buttonTitle: '삭제 하기',
                      onPressed: _confirmDeleteItems,
                    ),
                  ),
                ),
              if (isDragActive)
                Row(
                  children: [
                    if (!hasCustomSection)
                      Expanded(
                        child: _buildDragTargetForAddSection(),
                      ),
                    // Expanded(
                    //   child: _buildDragTargetForFridgeTransfer(),
                    // ),
                  ],
                ),
              if (userRole != 'admin' && userRole != 'paid_user')
                BannerAdWidget(),
            ],
          ),
        ));
  }

  Widget _buildSections() {
    bool allSectionsEmpty =
        itemLists.every((items) => _filterItems(items).isEmpty);

    if (allSectionsEmpty) {
      return _buildAnimatedEmptyFridge(); // 모든 섹션이 비어 있으면 애니메이션 표시
    }

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

  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
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
  }

  Widget _buildGridForSection(
      List<Map<String, dynamic>> items, int sectionIndex) {
    List<Map<String, dynamic>> filteredItems = _filterItems(items);
    return LayoutBuilder(
      builder: (context, constraints) {
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
          itemCount: filteredItems.isNotEmpty ? filteredItems.length : 1,
          itemBuilder: (context, index) {
            if (filteredItems.isEmpty) {
              return Container(
                height: 80, // 최소 높이
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Center(
                  child: Text(""),
                ),
              );
            } else {
              String currentItem =
                  filteredItems[index]['itemName'] ?? 'Unknown Item'; // 아이템 이름
              // int expirationDays = items[index].values.first;
              int shelfLife = filteredItems[index]['shelfLife'] ?? 0;
              // 🔹 registrationDate를 안전하게 변환
              DateTime registrationDate =
                  (filteredItems[index]['registrationDate'] is Timestamp)
                      ? (filteredItems[index]['registrationDate'] as Timestamp)
                          .toDate()
                      : filteredItems[index]['registrationDate'] as DateTime;

              bool isSelected = selectedItems.contains(currentItem);
              String formattedDate =
                  DateFormat('yyyy-MM-dd').format(registrationDate);

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
                child: Draggable<Map<String, dynamic>>(
                  data: {
                    'itemName': currentItem,
                    'documentId': filteredItems[index]['documentId'],
                    'fridgeId': selected_fridgeId, // 문서 ID 포함
                  },
                  onDragStarted: () {
                    setState(() {
                      isDragActive = true; // 드래그가 시작되면 true로 설정
                    });
                  },
                  onDragEnd: (details) {
                    setState(() {
                      isDragActive = false; // 드래그가 끝나면 다시 false로 설정
                    });
                  },
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
                          minFontSize: 6,
                          // 최소 글자 크기 설정
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
                        // 🔹 Firestore에서 `foods` 컬렉션에서 먼저 검색
                        final foodsSnapshot = await FirebaseFirestore.instance
                            .collection('foods')
                            .where('foodsName', isEqualTo: currentItem)
                            .get();

                        Map<String, dynamic>? foodData;

                        if (foodsSnapshot.docs.isNotEmpty) {
                          final doc =
                              foodsSnapshot.docs.first; // 🔹 첫 번째 문서 가져오기
                          foodData = doc.data(); // 🔹 Firestore에서 가져온 데이터
                          foodData['id'] = doc.id; // ✅ 문서 ID를 직접 추가
                          print("🔥 foods 컬렉션에서 찾은 foodData: $foodData");
                        } else {
                          final defaultFoodsSnapshot = await FirebaseFirestore
                              .instance
                              .collection('default_foods')
                              .where('foodsName', isEqualTo: currentItem)
                              .get();

                          if (defaultFoodsSnapshot.docs.isNotEmpty) {
                            final doc = defaultFoodsSnapshot.docs.first;
                            foodData = doc.data();
                            foodData['id'] = doc.id; // ✅ 문서 ID를 추가
                            print(
                                "🔥 default_foods 컬렉션에서 찾은 foodData: $foodData");
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

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FridgeItemDetails(
                                foodsId: foodsId,
                                foodsName: currentItem,
                                foodsCategory: defaultCategory,
                                fridgeCategory: defaultFridgeCategory,
                                shoppingListCategory: shoppingListCategory,
                                consumptionDays: shelfLife,
                                registrationDate: DateFormat('yyyy-MM-dd')
                                    .format(DateTime.now()),
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('아이템의 상세내용이 없습니다.')),
                          );
                          print(
                              "Item not found in foods collection: $currentItem");
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
            }
          },
        );
      },
    );
  }

  Widget _buildDragTargetSection(int sectionIndex) {
    if (sectionIndex < 0 || sectionIndex >= itemLists.length) {
      return Container(); // 인덱스가 유효하지 않으면 빈 컨테이너 반환
    }

    List<Map<String, dynamic>> filteredItems =
        _filterItems(itemLists[sectionIndex]);

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (draggedItem) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset localOffset = box.globalToLocal(draggedItem.offset);
        _startAutoScroll(localOffset.dy); // ✅ 현재 드래그 위치 전달하여 자동 스크롤 실행
        return true;
      },
      onLeave: (data) {
        _stopAutoScroll(); // ✅ 드래그가 벗어나면 자동 스크롤 멈춤
      },
      onAcceptWithDetails:
          (DragTargetDetails<Map<String, dynamic>> details) async {
        final draggedItem = details.data;
        final String draggedItemName = draggedItem['itemName'] ?? '';
        final String draggedItemDocumentId = draggedItem['documentId'] ?? '';
        final String newFridgeCategoryId =
            storageSections[sectionIndex].categoryName;

        try {
          // Firestore에서 정확한 문서 ID를 찾아서 업데이트
          await FirebaseFirestore.instance
              .collection('fridge_items')
              .doc(draggedItemDocumentId)
              .update({'fridgeCategoryId': newFridgeCategoryId});
        } catch (e) {
          print('Error updating fridgeCategoryId: $e');
        }

        await _loadFridgeItemsFromFirestore(selected_fridgeId);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            // 기존 그리드
            _buildGridForSection(filteredItems, sectionIndex),
            if (candidateData.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2), // 예상 위치의 배경색
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: Colors.grey, // 예상 위치의 테두리 색
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add, // 예상 위치에 아이콘 표시
                      color: Colors.grey,
                      size: 48,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Widget _buildItem(String itemName, int shelfLife, DateTime registrationDate) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: _getBackgroundColor(shelfLife, registrationDate),
  //       borderRadius: BorderRadius.circular(8.0),
  //     ),
  //     child: Center(
  //       child: Text(
  //         itemName,
  //         style: TextStyle(color: Colors.white),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildAnimatedEmptyFridge() {
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
              'assets/favicon.png',
              width: 150,
              height: 150,
            ),
            SizedBox(height: 10),
            Text(
              '냉장고가 비어 있습니다.',
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

  // Widget _buildDragTargetForFridgeTransfer() {
  //   return DragTarget<Map<String, dynamic>>(
  //     onWillAcceptWithDetails: (DragTargetDetails<Map<String, dynamic>> details) {
  //
  //       setState(() {
  //         isDragActive = true; // 드래그가 활성화되면 상태 업데이트
  //       });
  //       setState(() {
  //         isDragOver = true; // 드래그가 버튼 위에 올라왔을 때 상태 변경
  //       });
  //       return true; // 모든 드래그 항목 허용
  //     }, // 모든 아이템 드롭 허용
  //     onAcceptWithDetails: (DragTargetDetails<Map<String, dynamic>> details) async {
  //       final draggedItem = details.data;
  //       final documentId = draggedItem['documentId']; // ✅ 전달받은 문서 ID
  //
  //       setState(() {
  //         isDragOver = false; // 드래그가 버튼 위에 올라왔을 때 상태 변경
  //       });
  //       // 🔽 냉장고 선택 다이얼로그 띄우기
  //       String? targetFridgeId = await showDialog<String>(
  //         context: context,
  //         builder: (context) {
  //           List<String> availableFridges = fridgeName.where((fridge) => fridge != selectedFridge).toList();
  //           return AlertDialog(
  //             title: Text("어떤 냉장고로 이동할까요?"),
  //             content: Column(
  //               mainAxisSize: MainAxisSize.min, // 다이얼로그 크기를 자식에 맞게
  //               children: [
  //                 // 각 냉장고에 대한 선택 버튼
  //                 ...availableFridges.map((fridge) {
  //                   return SizedBox(
  //                     width: double.infinity,
  //                     child: NavbarButton(
  //                       buttonTitle: fridge,
  //                       onPressed: () {
  //                         Navigator.of(context).pop(fridge); // 선택된 냉장고 반환
  //                       },
  //                     ),
  //                   );
  //                 }).toList(),
  //                 // 🔽 취소 버튼 추가
  //                 SizedBox(
  //                   width: double.infinity,
  //                   child: NavbarButton(
  //                     buttonTitle: "취소",
  //                     onPressed: () {
  //                       Navigator.of(context).pop(null); // null 반환하여 취소
  //                     },
  //                     // backgroundColor: Colors.redAccent, // 취소 버튼 색상
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //
  //       // 🔽 사용자가 냉장고를 선택한 경우만 Firestore 업데이트
  //       if (targetFridgeId != null && targetFridgeId.isNotEmpty) {
  //         // 선택된 냉장고의 ID 가져오기
  //         String? targetFridgeDocumentId = await fetchFridgeId(targetFridgeId);
  //
  //         if (targetFridgeDocumentId != null) {
  //           await FirebaseFirestore.instance
  //               .collection('fridge_items')
  //               .doc(documentId) // 드래그된 아이템의 문서 ID
  //               .update({'FridgeId': targetFridgeDocumentId}); // 선택한 냉장고로 전송
  //
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(content: Text('${draggedItem['itemName']}이(가) $targetFridgeId로 이동되었습니다.')),
  //           );
  //         }
  //         setState(() {
  //           isDragActive = false; // 드래그 종료 시 상태 리셋
  //         });
  //       }
  //     },
  //     onLeave: (data) {
  //       setState(() {
  //         isDragActive = false; // 드래그가 벗어나면 상태 리셋
  //       });
  //       setState(() {
  //         isDragActive = false; // 드래그가 벗어나면 상태 리셋
  //       });
  //     },
  //     builder: (context, candidateData, rejectedData) {
  //       return Container(
  //         margin: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
  //         padding: EdgeInsets.all(10),
  //         decoration: BoxDecoration(
  //           color: isDragOver ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
  //           border: Border.all(color: isDragOver ? Colors.blue : Colors.grey),
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         child: Center(
  //           child: Text(
  //             '다른 냉장고로 이동',
  //             style: TextStyle(color: isDragOver ? Colors.blue : Colors.grey),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }
  Widget _buildDragTargetForAddSection() {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails:
          (DragTargetDetails<Map<String, dynamic>> details) {
        setState(() {
          isDragActive = true; // 드래그가 활성화되면 상태 업데이트
        });
        setState(() {
          isDragOver = true; // 드래그가 버튼 위에 올라왔을 때 상태 변경
        });
        return true; // 모든 드래그 항목 허용
      }, // 모든 아이템 드롭 허용
      onLeave: (data) {
        setState(() {
          isDragActive = false; // 드래그가 벗어나면 상태 리셋
        });
        setState(() {
          isDragOver = false; // 드래그가 버튼을 벗어났을 때 상태 리셋
        });
      },
      onAcceptWithDetails:
          (DragTargetDetails<Map<String, dynamic>> details) async {
        final draggedItem = details.data;
        final documentId = draggedItem['documentId']; // ✅ 전달받은 문서 ID
        setState(() {
          isDragOver = false; // 드래그가 성공적으로 완료되었을 때 상태 리셋
        });
        // 🔽 냉장고 선택 다이얼로그 띄우기
        String? targetFridgeId = await showDialog<String>(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            String newSectionName = ''; // 입력된 섹션 이름 저장
            return AlertDialog(
              title: Text(
                "섹션을 추가할까요?",
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: TextField(
                onChanged: (value) {
                  newSectionName = value; // 사용자가 입력하는 값 업데이트
                },
                decoration: InputDecoration(
                  hintText: '섹션 이름 입력',
                  border: OutlineInputBorder(), // 입력 필드에 테두리 추가
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // 다이얼로그 닫기
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    if (newSectionName.isNotEmpty) {
                      await _saveNewSectionToFirestore(
                          newSectionName); // 섹션 저장 함수 호출
                      Navigator.pop(context); // 다이얼로그 닫기
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('섹션 이름을 입력해주세요.')),
                      );
                    }
                  },
                  child: Text('추가'),
                ),
              ],
            );
          },
        );

        // if (targetFridgeDocumentId != null) {
        //   await FirebaseFirestore.instance
        //       .collection('fridge_items')
        //       .doc(documentId) // 드래그된 아이템의 문서 ID
        //       .update({'fridgeCategoryId': targetFridgeDocumentId}); // 선택한 냉장고로 전송
        //
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('${draggedItem['itemName']}이(가) $targetFridgeId로 이동되었습니다.')),
        //   );
        // }
        setState(() {
          isDragActive = false; // 드래그 종료 시 상태 리셋
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDragOver
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              border: Border.all(
                color: isDragOver
                    ? Colors.blue
                    : Colors.grey, // 드래그 상태에 따라 테두리 색 변경
                width: isDragOver ? 3.0 : 1.0, // 두께도 변경 가능
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '섹션 추가',
                style: TextStyle(
                  color: isDragOver ? Colors.blue : Colors.grey, // 글자색 변경
                  fontWeight: isDragOver
                      ? FontWeight.bold
                      : FontWeight.normal, // 폰트 굵기 변경
                ),
              ),
            ),
          ),
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
