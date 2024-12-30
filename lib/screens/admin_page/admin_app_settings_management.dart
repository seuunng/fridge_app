import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/app_setting_categories_table/foods_table.dart';
import 'package:food_for_later_new/screens/admin_page/app_setting_categories_table/theme_table.dart';
import 'package:food_for_later_new/screens/admin_page/app_setting_categories_table/howtocook_table.dart';
import 'package:food_for_later_new/screens/admin_page/app_setting_categories_table/preferredfoodscategory_table.dart';

class AdminAppSettingsManagement extends StatefulWidget {
  @override
  _AdminAppSettingsManagementState createState() =>
      _AdminAppSettingsManagementState();
}

class _AdminAppSettingsManagementState
    extends State<AdminAppSettingsManagement> {
  final List<Tab> myTabs = <Tab>[
    Tab(text: '식품 목록'),
    Tab(text: '테마별 카테고리'),
    Tab(text: '조리방법별 카테고리'),
    Tab(text: '선호식품 카테고리'),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: myTabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('어플 설정'),
          bottom: TabBar(
            tabs: myTabs,
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(child: FoodsTable()),
            SingleChildScrollView(child: ThemeTable()),
            SingleChildScrollView(child: HowtocookTable()),
            SingleChildScrollView(child: PreferredfoodscategoryTable()),
          ],
        ),
      ),
    );
  }
}
