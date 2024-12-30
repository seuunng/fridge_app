import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/trends_table/basicfoods_trend_table.dart';
import 'package:food_for_later_new/screens/admin_page/trends_table/inputkeyword_trend_table.dart';
import 'package:food_for_later_new/screens/admin_page/trends_table/preferredfoods_trend_table.dart';
import 'package:food_for_later_new/screens/admin_page/trends_table/recipe_trend_table.dart';
import 'package:food_for_later_new/screens/admin_page/trends_table/searchkeyword_trend_table.dart';

class AdminDashboardTrends extends StatefulWidget {
  @override
  _AdminDashboardTrendsState createState() => _AdminDashboardTrendsState();
}

class _AdminDashboardTrendsState extends State<AdminDashboardTrends> {
  PageController _pageController = PageController();
  int _currentPage = 0; // 현재 페이지 상태
  final int _totalPages = 5; // 총 페이지 수

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

  String _getPageTitle() {
    // 페이지 번호에 따라 제목을 반환
    switch (_currentPage) {
      case 0:
        return '인기 키워드';
      case 1:
        return '인기 레시피';
      case 2:
        return '기본 식품 추가';
      case 3:
        return '선호 식품 추가';
      case 4:
        return '많이 언급된 키워드';
      default:
        return '트렌드';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('트렌드'),
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _goToPreviousTable,
                icon: Icon(Icons.arrow_back_ios), // <- 이전 버튼
              ),
              Text(
                _getPageTitle(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _goToNextTable,
                icon: Icon(Icons.arrow_forward_ios), // -> 다음 버튼
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
                children: [
                  SearchkeywordTrendTable(), // 첫 번째 페이지: 인기 키워드
                  RecipeTrendTable(),
                  BasicfoodsTrendTable(),
                  PreferredfoodsTrendTable(),
                  InputkeywordTrendTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
