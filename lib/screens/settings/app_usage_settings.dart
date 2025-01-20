import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/components/custom_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUsageSettings extends StatefulWidget {
  @override
  _AppUsageSettingsState createState() => _AppUsageSettingsState();
}

class _AppUsageSettingsState extends State<AppUsageSettings> {
  String _selectedCategory_fridge = '기본 냉장고'; // 기본 선택값
  List<String> _categories_fridge = []; // 카테고리 리스트
  String _selectedCategory_foods = '입고일 기준'; // 기본 선택값
  final List<String> _categories_foods = ['소비기한 기준', '입고일 기준']; // 카테고리 리스트
  String _selectedCategory_records = '달력형'; // 기본 선택값
  final List<String> _categories_records = ['앨범형', '달력형', '목록형']; // 카테고리 리스트
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadFridgeCategoriesFromFirestore(); // 초기화 시 Firestore에서 데이터를 불러옴
    _loadSelectedFridge();
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
  void _loadSelectedFridge() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      _selectedCategory_fridge = prefs.getString('selectedFridge') ?? '기본 냉장고';
      _selectedCategory_records =
          prefs.getString('selectedRecordListType') ?? '달력형';
      _selectedCategory_foods =
          prefs.getString('selectedFoodStatusManagement') ?? '소비기한 기준';
    });
  }

  // Firestore에서 냉장고 목록 불러오기
  void _loadFridgeCategoriesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('userId', isEqualTo: userId)
          .get();
      List<String> fridgeList =
          snapshot.docs.map((doc) => doc['FridgeName'] as String).toList();

      if (fridgeList.isEmpty) {
        await createDefaultFridge(); // 기본 냉장고 추가
      }

      setState(() {
        _categories_fridge = fridgeList; // 불러온 냉장고 목록을 상태에 저장
        // _selectedCategory_fridge = _categories_fridge.isNotEmpty ? _categories_fridge.first : '기본 냉장고';
      });
    } catch (e) {
      print('Error loading fridge categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 목록을 불러오는 데 실패했습니다.')),
      );
    }
  }

  Future<void> createDefaultFridge() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('FridgeName', isEqualTo: '기본 냉장고')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        // Firestore에 기본 냉장고 추가
        await FirebaseFirestore.instance.collection('fridges').add({
          'FridgeName': '기본 냉장고',
          'userId': userId,
        });
      } else {
        print('기본 냉장고가 이미 존재합니다.');
      }
      // UI 업데이트
      setState(() {
        _categories_fridge.add('기본 냉장고');
        _selectedCategory_fridge = '기본 냉장고';
      });
    } catch (e) {
      print('Error creating default fridge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 냉장고를 생성하는 데 실패했습니다.')),
      );
    }
  }

  Future<void> _addNewFridgeToFirestore(String newFridgeName) async {
    final fridgeRef = FirebaseFirestore.instance.collection('fridges');
    try {
      await fridgeRef.add({
        'FridgeName': newFridgeName,
        'userId': userId,
      });
    } catch (e) {
      print('냉장고 추가 중 오류가 발생했습니다: $e');
    }
  }

  // 새로운 카테고리 추가 함수
  void _addNewCategory(List<String> categories, String categoryType) {
    final theme = Theme.of(context);
    if (userRole != 'admin' && userRole != 'paid_user') {
      // 🔹 일반 사용자는 냉장고 추가 불가능
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프리미엄 서비스를 이용하면 냉장고를 여러 개 등록하고 스마트한 식재료 관리를 할 수 있어요!')),
      );
      return;
    }
    if (categories.length >= 3) {
      // 카테고리 개수가 3개 이상이면 추가 불가
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$categoryType은(는) 최대 3개까지만 추가할 수 있습니다.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newCategory = '';
        return AlertDialog(
          title: Text('$categoryType 추가',
            style: TextStyle(
                color: theme.colorScheme.onSurface
            ),
          ),
          content: TextField(
            onChanged: (value) {
              newCategory = value;
            },
            decoration: InputDecoration(hintText: '새로운 냉장고 이름 입력'),
            style:
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
                  await _addNewFridgeToFirestore(newCategory);
                  setState(() {
                    categories.add(newCategory);
                    // 추가 후 선택된 카테고리 업데이트
                    if (categoryType == '냉장고') {
                      _selectedCategory_fridge = newCategory;
                    }
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
    if (categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최소 한 개의 냉장고는 필요합니다.')),
      );
      return;
    }
    final fridgeRef = FirebaseFirestore.instance.collection('fridges');
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('냉장고 삭제',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          content: Text('$category를 삭제하시겠습니까?',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
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
                    if (_categories_fridge.length <= 1) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('최소 한 개의 냉장고는 필요합니다.')),
                      );
                      Navigator.pop(context);
                      return;
                    }
                    // 해당 냉장고 이름과 일치하는 문서를 찾음
                    final snapshot = await fridgeRef
                        .where('FridgeName', isEqualTo: category)
                        .where('userId', isEqualTo: userId)
                        .get();

                    for (var doc in snapshot.docs) {
                      // Firestore에서 문서 삭제
                      await fridgeRef.doc(doc.id).delete();
                    }

                    // UI 업데이트
                    setState(() {
                      _categories_fridge.remove(category);
                      if (_categories_fridge.isNotEmpty) {
                        _selectedCategory_fridge = _categories_fridge.first;
                      } else {
                        createDefaultFridge(); // 모든 냉장고가 삭제되면 기본 냉장고 생성
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

  void _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user?.email == 'guest@foodforlater.com') {
      // 🔹 게스트 계정이면 설정 저장 불가 & 로그인 요청 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후 설정을 저장할 수 있습니다.')),
      );
      return; // 🚫 여기서 함수 종료 (저장 X)
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedFridge', _selectedCategory_fridge);
    await prefs.setString('selectedRecordListType', _selectedCategory_records);
    await prefs.setString(
        'selectedFoodStatusManagement', _selectedCategory_foods);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('어플 사용 설정'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomDropdown(
                title: '냉장고 선택',
                items: _categories_fridge,
                selectedItem:
                    _categories_fridge.contains(_selectedCategory_fridge)
                        ? _selectedCategory_fridge
                        : '기본 냉장고', // 리스트에 없으면 기본값 설정
                onItemChanged: (value) {
                  setState(() {
                    _selectedCategory_fridge = value;
                  });
                },
                onItemDeleted: (item) {
                  _deleteCategory(item, _categories_fridge, '냉장고');
                },
                onAddNewItem: () {
                  _addNewCategory(_categories_fridge, '냉장고');
                },
              ),
              Text('가장 자주 보는 냉장고를 기본냉장고로 설정하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '식품 상태관리 선택',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory_foods,
                    // _categories_foods.contains(_selectedCategory_foods)
                    //     ? _selectedCategory_foods
                    //     : null,
                    items: _categories_foods.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedCategory_foods = value!;
                      });
                    },
                  ),
                ],
              ),
              Text('식품 관리 기준을 선택하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              Text('빨리 소진해야할 식품을 알려드려요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '선호 식품 카테고리 수정',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  BasicElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddItem(
                            pageTitle: '선호식품 카테고리에 추가',
                            addButton: '카테고리에 추가',
                            sourcePage: 'preferred_foods_category',
                            onItemAdded: () {
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                    iconTitle: Icons.edit,
                    buttonTitle: '수정',
                  ),
                ],
              ),
              Text('자주 검색하는 식품을 묶음으로 관리해요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    '대표 기록유형 선택',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  DropdownButton<String>(
                    value: _selectedCategory_records,
                    items: _categories_records.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (String? value) async {
                      if (value != null) {
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString(
                            'selectedCategory_records', value); // 값 저장
                        setState(() {
                          _selectedCategory_records = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              Text('가장 자주 보는 기록유형을 대표 유형으로 설정하세요',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
        children: [
          Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: NavbarButton(
                buttonTitle: '저장',
                onPressed: _saveSettings,
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
}
