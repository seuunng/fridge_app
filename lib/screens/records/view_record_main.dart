import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';
import 'package:food_for_later_new/main.dart';
import 'package:food_for_later_new/screens/records/create_record.dart';
import 'package:food_for_later_new/screens/records/records_album_view.dart';
import 'package:food_for_later_new/screens/records/records_calendar_view.dart';
import 'package:food_for_later_new/screens/records/records_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewRecordMain extends StatefulWidget {
  final String? selectedCategory;

  ViewRecordMain({Key? key, this.selectedCategory}) : super(key: key);

  @override
  _ViewRecordMainState createState() => _ViewRecordMainState();
}

class _ViewRecordMainState extends State<ViewRecordMain> with RouteAware {
  PageController _pageController = PageController();
  String selectedRecordListType = '달력형';
  String selectedCategory = '모두'; // 필드 추가
  int _currentPage = 0; // 현재 페이지 상태
  final int _totalPages = 3; // 총 페이지 수
  bool isTruth = true;

  @override
  void initState() {
    super.initState();
    _loadSelectedCategory();
    _loadSelectedRecordListType(); // 초기화 시 Firestore에서 데이터를 불러옴
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    _loadSelectedRecordListType();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this); // routeObserver 구독 해제
    _loadSelectedRecordListType();
    super.dispose();
  }

  void _loadSelectedCategory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedCategory = prefs.getString('selectedCategory_records') ?? '모두';
    });
  }

  void _loadSelectedRecordListType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return; // 위젯이 여전히 트리에 있는지 확인
    setState(() {
      selectedRecordListType =
          prefs.getString('selectedRecordListType') ?? '달력형';
      int initialPage = _getInitialPage(selectedRecordListType);
      _pageController = PageController(initialPage: initialPage);
      _currentPage = initialPage;
      _getPageTitle();
    });
  }

  int _getInitialPage(String recordListType) {
    switch (recordListType) {
      case '달력형':
        return 0;
      case '목록형':
        return 1;
      case '앨범형':
        return 2;
      default:
        return 0;
    }
  }

  void _goToNextTable() {
    if (_currentPage == _totalPages - 1) {
      _pageController.jumpToPage(0);
      setState(() {
        _currentPage = 0;
      });
    } else {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      setState(() {
        _currentPage++;
      });
    }
  }

  void _goToPreviousTable() {
    if (_currentPage == 0) {
      _pageController.jumpToPage(_totalPages - 1);
      setState(() {
        _currentPage = _totalPages - 1;
      });
    } else {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  List<Widget> _getPageOrder() {
    switch (selectedRecordListType) {
      case '달력형':
        return [RecordsCalendarView(), RecordsListView(), RecordsAlbumView()];
      case '목록형':
        return [RecordsListView(), RecordsAlbumView(), RecordsCalendarView()];
      case '앨범형':
        return [RecordsAlbumView(), RecordsCalendarView(), RecordsListView()];
      default:
        return [RecordsCalendarView(), RecordsListView(), RecordsAlbumView()];
    }
  }

  String _getPageTitle() {
    // 페이지 번호에 따라 제목을 반환
    switch (selectedRecordListType) {
      case '앨범형':
        return ['앨범형', '달력형', '목록형'][_currentPage];
      case '달력형':
        return ['달력형', '목록형', '앨범형' ][_currentPage];
      case '목록형':
        return ['목록형', '앨범형', '달력형'][_currentPage];
      default:
        return ['달력형', '목록형', '앨범형'][_currentPage];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // appBar: AppBar(
      //   title:
      // ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 좌측 '기록하기' 텍스트
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '기록하기',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 20, // 글자 크기 (기본보다 크게 조정)
                    fontWeight: FontWeight.bold, // 글자 굵게 설정
                  ),
                ),
              ),

              // 가운데 페이지 제목과 화살표 버튼
              Row(
                children: [
                  // 왼쪽 화살표 버튼
                  IconButton(
                    onPressed: _goToPreviousTable,
                    icon: Icon(Icons.arrow_left_outlined), // <- 이전 버튼
                  ),

                  // 가운데 페이지 제목
                  Text(
                    _getPageTitle(), // 페이지 제목 함수 호출
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400,
                      color: theme.colorScheme.onSurface,),
                  ),

                  // 오른쪽 화살표 버튼
                  IconButton(
                    onPressed: _goToNextTable,
                    icon: Icon(Icons.arrow_right_outlined), // -> 다음 버튼
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: _getPageOrder(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingAddButton(
        heroTag: 'record_add_button',
        onPressed: () {
          final user = FirebaseAuth.instance.currentUser;

          if (user == null || user.email == 'guest@foodforlater.com') {
            // 🔹 방문자(게스트) 계정이면 접근 차단 및 안내 메시지 표시
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('로그인 후 기록을 작성할 수 있습니다.'),
                duration: Duration(seconds: 2),),
            );
            return; // 🚫 여기서 함수 종료 (페이지 이동 X)
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateRecord(),
              fullscreenDialog: true, // 모달 다이얼로그처럼 보이게 설정
            ),
          );
        },
      ),
    );
  }
}
