import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class UserTime extends StatefulWidget {
  const UserTime({super.key});

  @override
  State<StatefulWidget> createState() => UserTimeState();
}

class UserTimeState extends State<UserTime> {
  final Duration animDuration = const Duration(milliseconds: 250);

  int touchedIndex = -1;

  Future<Map<int, int>> fetchUsageData() async {
    final usageData = <int, int>{};
    for (int i = 0; i < 24; i++) {
      usageData[i] = 0; // 초기화
    }

    final userCollection = FirebaseFirestore.instance.collection('users');
    final querySnapshot = await userCollection.get();

    for (var doc in querySnapshot.docs) {
      final sessions =
          List<Map<String, dynamic>>.from(doc['openSessions'] ?? []);
      for (var session in sessions) {
        if (session['startTime'] != null) {
          final startTime = (session['startTime'] as Timestamp).toDate();
          final hour = startTime.hour; // 0~23 시간대 추출
          usageData[hour] = usageData[hour]! + 1;
        }
      }
    }
    return usageData;
  }

  Future<List<BarChartGroupData>> buildChartGroups() async {
    final usageData = await fetchUsageData();
    final groupData = <BarChartGroupData>[];

    for (int i = 0; i < 24; i += 3) {
      double sum = 0;
      for (int j = i; j < i + 3 && j < 24; j++) {
        sum += usageData[j]!.toDouble();
      }
      groupData.add(
        makeGroupData(i ~/ 3, sum), // 3시간 단위의 평균 사용량
      );
    }

    return groupData;
  }

  Future<BarChartData> mainBarData() async {
    final groups = await buildChartGroups();
    return BarChartData(
      barTouchData: BarTouchData(),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false), // 상단 제목 제거
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (double value, TitleMeta meta) {
              final hourLabels = [
                '0~3시',
                '3~6시',
                '6~9시',
                '9~12시',
                '12~15시',
                '15~18시',
                '18~21시',
                '21~24시'
              ];
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(hourLabels[value.toInt()]),
              );
            },
            reservedSize: 30,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false), // 오른쪽 제목 제거
        ),
      ),
      borderData: FlBorderData(
        show: false, // 테두리 제거
      ),
      barGroups: groups,
      gridData: const FlGridData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BarChartData>(
      future: mainBarData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
        }
        return Padding(
          padding: const EdgeInsets.only(left: 12.0, right: 12.0),
          child: Container(
              decoration: BoxDecoration(
                color: Colors.white, // 배경색 설정
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3), // 그림자 위치
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12.0), // 내부 여백
              child: BarChart(snapshot.data!)),
        );
      },
    );
  }

  // 차트 그룹 데이터 생성
  BarChartGroupData makeGroupData(
    int x,
    double y, {
    bool isTouched = false,
    Color? barColor,
    double width = 22,
    List<int> showTooltips = const [],
  }) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: isTouched ? y + 1 : y,
          color: isTouched ? Colors.green : barColor ?? Colors.blueAccent,
          width: width,
          borderSide: isTouched
              ? const BorderSide(color: Colors.green)
              : const BorderSide(color: Colors.white, width: 0),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: Colors.grey.withOpacity(0.2), // 배경 설정
          ),
        ),
      ],
      showingTooltipIndicators: showTooltips,
    );
  }

  // 차트 그룹 데이터를 생성하는 함수
  List<BarChartGroupData> showingGroups() => List.generate(7, (i) {
        return makeGroupData(i, 5 + i.toDouble());
      });
}
