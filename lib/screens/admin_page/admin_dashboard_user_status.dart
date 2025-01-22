import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/user_status_chart/user_age.dart';
import 'package:food_for_later_new/screens/admin_page/user_status_chart/user_statistics.dart';
import 'package:food_for_later_new/screens/admin_page/user_status_chart/user_table.dart';
import 'package:food_for_later_new/screens/admin_page/user_status_chart/user_time.dart';

class AdminDashboardUserStatus extends StatefulWidget {
  @override
  _AdminDashboardUserStatusState createState() =>
      _AdminDashboardUserStatusState();
}

class _AdminDashboardUserStatusState extends State<AdminDashboardUserStatus> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('사용자 현황'),
      ),
      body: ListView(
        children: [
          Row(
            children: [
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  '목표 총 사용자',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
              ),
                SizedBox(width: 10,),
      Text(
        '1000명',
        style: TextStyle(fontSize: 18,
            color: theme.colorScheme.onSurface),
      ),SizedBox(width: 10,),
              Expanded(
                child: Text(
                  '현재까지 등록 사용자',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
              ),
              SizedBox(width: 10,),
              Text(
                '120명(12% 달성)',
                style: TextStyle(fontSize: 18,
                    color: theme.colorScheme.onSurface),
              ),//
               //
            ],
          ),

          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '목표 하루 이용자',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ), // 텍스트와 드롭다운 사이 간격
              Text(
                '1000명',
                style: TextStyle(fontSize: 18,
                    color: theme.colorScheme.onSurface),
              ), //
              Text(
                '어제 하루 사용자',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ), //
              Text(
                '100명(10%)',
                style: TextStyle(fontSize: 18,
                    color: theme.colorScheme.onSurface),
              ), //
            ],
          ),
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '사용자 수 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            height: 200,
            child: UserStatistics(),
          ),
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '사용자 연령 및 성별 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            height: 200,
            child: UserAge(),
          ),
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '사용자 사용시간 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            height: 200,
            child: UserTime(),
          ),
          Row(
            children: [
              SizedBox(width: 16),
              Text(
                '회원목록',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Spacer(), // 텍스트와 드롭다운 사이 간격
            ],
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 20),
            child: UserTable(),
          ),
        ],
      ),
    );
  }
}
