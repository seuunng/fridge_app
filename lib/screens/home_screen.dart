import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/admin_login.dart';
import 'package:food_for_later_new/screens/auth/purchase_page.dart';
import 'package:food_for_later_new/screens/foods/add_item.dart';
import 'package:food_for_later_new/screens/fridge/fridge_main_page.dart';
import 'package:food_for_later_new/screens/recipe/recipe_main_page.dart';
import 'package:food_for_later_new/screens/recipe/recipe_search_settings.dart';
import 'package:food_for_later_new/screens/records/edit_record_categories.dart';
import 'package:food_for_later_new/screens/records/record_search_settings.dart';
import 'package:food_for_later_new/screens/records/view_record_main.dart';
import 'package:food_for_later_new/screens/settings/account_information.dart';
import 'package:food_for_later_new/screens/settings/app_info_page.dart';
import 'package:food_for_later_new/screens/settings/app_usage_settings.dart';
import 'package:food_for_later_new/screens/settings/feedback_submission.dart';
import 'package:food_for_later_new/screens/settings/notice_page.dart';
import 'package:food_for_later_new/screens/shpping_list/shopping_list_main_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

//StatefulWidget: 상태가 있는 위젯
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late String _selectedCategory;
  String _selectedCategory_records = '앨범형';
  final GlobalKey<FridgeMainPageState> _fridgeMainPageKey =
      GlobalKey<FridgeMainPageState>();
  final GlobalKey<ShoppingListMainPageState> _shoppingListMainPageKey =
      GlobalKey<ShoppingListMainPageState>();
  late List<Widget> _pages;
  String selectedRecordListType = '앨범형';

  String? selectedCategory;
  bool isAdmin = false;
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isCondimentsHidden = false;

  // 각 페이지를 저장하는 리스트
  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _loadSelectedRecordListType(); // 초기화 시 Firestore에서 데이터를 불러옴
    // initState에서 _pages 리스트 초기화
    _pages = [
      FridgeMainPage(key: _fridgeMainPageKey), // 냉장고 페이지
      ShoppingListMainPage(key: _shoppingListMainPageKey),
      RecipeMainPage(category: []),
      ViewRecordMain(selectedCategory: selectedRecordListType),
    ];
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

  void _loadSelectedRecordListType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedRecordListType =
          prefs.getString('selectedRecordListType') ?? '앨범형';
    });
  }

  void _onItemTapped(int index) {
    if (index < _pages.length) {
      setState(() {
        _fridgeMainPageKey.currentState?.stopDeleteMode();
        _shoppingListMainPageKey.currentState?.stopShoppingListDeleteMode();
        _selectedIndex = index;
      });
    }
  }

  List<PopupMenuEntry<String>> _getPopupMenuItems() {
    final theme = Theme.of(context);
    switch (_selectedIndex) {
      case 0: // 냉장고 페이지
        return [
          PopupMenuItem<String>(
            value: 'basic_foods_categories_setting',
            child: Text('기본 식품 카테고리 관리',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
          // PopupMenuItem<String>(
          //   value: 'preferred_foods_categories_setting',
          //   child: Text('제외 키워드 카테고리 관리'),
          // ),
          PopupMenuItem<String>(
            value: 'sort_dialog',
            child: Text('정렬',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
          PopupMenuItem<String>(
            child: InkWell(
              onTap: () {
                // 텍스트를 클릭해도 동일한 동작 실행
                bool newValue = !isCondimentsHidden;
                Navigator.pop(context); // ✅ 팝업 메뉴 닫기
                _updateCondimentsHiddenStatus(newValue);
              },
              child: Row(
                children: [
                  Checkbox(
                    value: isCondimentsHidden,
                    onChanged: (bool? newValue) {
                      if (newValue != null) {
                        Navigator.pop(context); // ✅ 팝업 메뉴 닫기
                        _updateCondimentsHiddenStatus(newValue);
                      }
                    },
                  ),
                  Text('조미료 숨기기',
    style: TextStyle(
    color: theme.colorScheme.onSurface
    ),),
                ],
              ),
            ),
          ),
        ];
      case 1: // 장보기 페이지
        return [
          PopupMenuItem<String>(
            value: 'basic_foods_categories_setting',
            child: Text('기본 식품 카테고리 관리',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
          // PopupMenuItem<String>(
          //   value: 'preferred_foods_categories_setting',
          //   child: Text('제외 키워드 카테고리 관리'),
          // ),
        ];
      case 2: // 레시피 페이지
        return [
          PopupMenuItem<String>(
            value: 'recipe_search_detail_setting',
            child: Text('검색 상세 설정',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
        ];
      case 3: // 기록 페이지
        return [
          PopupMenuItem<String>(
            value: 'record_search_detail_setting',
            child: Text('검색 상세 설정',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
          PopupMenuItem<String>(
            value: 'record_categories_setting',
            child: Text('기록 카테고리 관리',
              style: TextStyle(
                  color: theme.colorScheme.onSurface
              ),),
          ),
        ];
      default:
        return [];
    }
  }

  void _onPopupMenuSelected(String value) {
    // 팝업 메뉴 항목 선택 시 동작 정의
    switch (value) {
      case 'basic_foods_categories_setting':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddItem(
              pageTitle: '기본 식품 카테고리에 추가',
              addButton: '',
              sourcePage: 'update_foods_category',
              onItemAdded: () {
                setState(() {});
              },
            ),
          ),
        );
        break;
      // case 'preferred_foods_categories_setting':
      //   Navigator.push(
      //     context,
      //     MaterialPageRoute(
      //       builder: (context) => AddItem(
      //         pageTitle: '제외 키워드 카테고리에 추가',
      //         addButton: '',
      //         sourcePage: 'preferred_foods_category',
      //         onItemAdded: () {
      //           setState(() {});
      //         },
      //       ),
      //     ),
      //   );
      //
      //   break;
      case 'sort_dialog':
        _showSortDialog(); // 정렬 다이얼로그 표시
        break;
      case 'recipe_search_detail_setting':
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => RecipeSearchSettings()));
        break;

      case 'record_search_detail_setting':
        if (userRole != 'admin' && userRole != 'paid_user') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프리미엄 서비스를 이용하면 나의 요리기록을 스마트하게 할 수 있어요!'),
              duration: Duration(seconds: 3),
            ),
          );
          return; // 🚨 페이지 이동 차단!
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecordSearchSettings()),
        );
        break; // ✅ `break` 추가

      case 'record_categories_setting':
        if (userRole != 'admin' && userRole != 'paid_user') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프리미엄 서비스를 이용하면 나의 요리기록을 스마트하게 할 수 있어요!'),
              duration: Duration(seconds: 3),
            ),
          );
          return; // 🚨 페이지 이동 차단!
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => EditRecordCategories()));
        break;

      default:
        break;
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('정렬 기준 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.access_time),
                title: Text('소비기한 임박순'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFridgeSort('expiration');
                },
              ),
              ListTile(
                leading: Icon(Icons.category),
                title: Text('카테고리순'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFridgeSort('category');
                },
              ),
              ListTile(
                leading: Icon(Icons.date_range),
                title: Text('입고일 순'),
                onTap: () {
                  Navigator.pop(context);
                  _handleFridgeSort('registration');
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _handleFridgeSort(String selectedOption) {
    final fridgePage = _fridgeMainPageKey.currentState;
    if (fridgePage != null) {
      switch (selectedOption) {
        case 'expiration':
          fridgePage.sortItemsByExpiration();
          break;
        case 'category':
          fridgePage.sortItemsByCategory();
          break;
        case 'registration':
          fridgePage.sortItemsByRegistrationDate();
          break;
      }
    }
  }
  void _updateCondimentsHiddenStatus(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCondimentsHidden', value);

    setState(() {
      isCondimentsHidden = value;  // 상태 즉시 반영
    });

    setState(() {
      // ✅ 상태를 저장한 후 냉장고 페이지를 다시 빌드하도록 함
      _pages[0] = FridgeMainPage(key: GlobalKey());
    });
    // isCondimentsHiddenNotifier.value = value;
    print('isCondimentsHidden 상태 업데이트 및 저장됨: $isCondimentsHidden');
  }

  Future<String?> _getUserRole() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['role'] as String?;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  Future<void> _checkAdminRole() async {
    String? role = await _getUserRole();
    if (role == 'admin') {
      setState(() {
        isAdmin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('이따뭐먹지'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _onPopupMenuSelected,
            itemBuilder: (BuildContext context) => _getPopupMenuItems(),
          ),
        ],
      ),
      drawer: Drawer(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: <Widget>[
              DrawerHeader(
                decoration: BoxDecoration(
                    color: Theme.of(context).drawerTheme.backgroundColor),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('설정',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 24,
                      )),
                ),
              ),
              ListTile(
                leading: Icon(Icons.person,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('계정 정보',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AccountInformation()), // 계정 정보 페이지로 이동
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.system_security_update_good,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('어플 사용 설정',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AppUsageSettings()), // 계정 정보 페이지로 이동
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.send,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('문의하기',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user == null || user.email == 'guest@foodforlater.com') {
                    // 🔹 방문자(게스트) 계정이면 접근 차단 및 안내 메시지 표시
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('로그인 후에 의견을 보내주세요.')),
                    );
                    return; // 🚫 여기서 함수 종료 (페이지 이동 X)
                  }
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            FeedbackSubmission()), // 계정 정보 페이지로 이동
                  );
                },
              ),
              Spacer(),
              ListTile(
                leading: Icon(Icons.campaign,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('공지사항',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoticePage(),), // 계정 정보 페이지로 이동
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('프리미엄 전환',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            PurchasePage()), // 계정 정보 페이지로 이동
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.apartment,
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text('어플 소개',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                  ),),
                onTap: () {
                  Navigator.pop(context); // 사이드바 닫기
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AppInfoPage()), // 계정 정보 페이지로 이동
                  );
                },
              ),
              if (isAdmin)
                ListTile(
                  leading: Icon(Icons.verified_user,
                      color: Theme.of(context).colorScheme.onSurface),
                  title: Text('관리자 페이지',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                    ),),
                  onTap: () {
                    Navigator.pop(context); // 사이드바 닫기
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AdminLogin()), // 계정 정보 페이지로 이동
                    );
                  },
                ),
            ],
          )),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages, // _pages 리스트에서 선택된 인덱스의 페이지를 표시
      ),

      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            label: '냉장고',
          ),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: '장보기'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '레시피'),
          BottomNavigationBarItem(
              icon: Icon(Icons.drive_file_rename_outline_rounded), label: '기록'),
        ],
        currentIndex: _selectedIndex, // 현재 선택된 탭
        onTap: _onItemTapped, // 탭 선택시 호출될 함수
      ),
    );
  }
}
