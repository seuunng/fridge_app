import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserStatistics extends StatefulWidget {
  const UserStatistics({super.key});

  @override
  State<UserStatistics> createState() => _UserStatisticsState();
}

class _UserStatisticsState extends State<UserStatistics> {
  final String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<FlSpot> _userStats = [];
  List<Color> gradientColors = [
    Colors.cyan,
    Colors.blue,
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserStats(); // Firestore에서 데이터 가져오기
  }

  Future<void> _fetchUserStats() async {
    // Firestore에서 데이터 가져오기
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    Map<String, int> dateCount = {};

    // 1년 전 날짜 계산
    DateTime now = DateTime.now();
    DateTime oneYearAgo = DateTime(now.year - 1, now.month);

    // 날짜별로 사용자 수 집계
    for (var doc in snapshot.docs) {
      final signUpDateRaw = doc.data()['signupdate'];
      final signUpDate = signUpDateRaw is Timestamp
          ? signUpDateRaw.toDate()
          : DateTime.parse(signUpDateRaw.toString());

      if (signUpDate.isAfter(oneYearAgo) && signUpDate.isBefore(now)) {
        final dateKey = DateFormat('yyyy-MM').format(signUpDate);

        // 해당 날짜의 사용자 수를 증가
        if (dateCount.containsKey(dateKey)) {
          dateCount[dateKey] = dateCount[dateKey]! + 1;
        } else {
          dateCount[dateKey] = 1;
        }
      }
    }
// 누락된 달을 0으로 초기화하여 12개월 데이터를 유지
    Map<String, int> completeDateCount = {};
    for (int i = 11; i >= 0; i--) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      String dateKey = DateFormat('yyyy-MM').format(month);
      completeDateCount[dateKey] = dateCount[dateKey] ?? 0;
    }
    // 누적 합계로 변환
    List<FlSpot> spots = [];
    int cumulativeCount = 0;
    // int dayIndex = 0;

    completeDateCount.entries.toList().asMap().forEach((index, entry) {
      cumulativeCount += entry.value; // 누적 합계 계산
      spots.add(FlSpot(index.toDouble(), cumulativeCount.toDouble()));
    });

    setState(() {
      _userStats = spots;
    });
  }
  // bool showAvg = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: double.infinity, // 부모 컨테이너의 가로를 채움
          maxHeight: 300, // 최대 세로 크기
        ),
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
        padding: const EdgeInsets.all(12.0),
        child: Center(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: _userStats.isNotEmpty ? _userStats.length.toDouble() : 12,
              minY: 0,
              maxY:  (_userStats.isNotEmpty
                  ? _userStats.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 5
                  : 10),
              gridData: FlGridData(
                show: false,
              ),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // 상단 숫자 제거
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                  ), // 왼쪽 숫자 제거
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: bottomTitleWidgets,
                    reservedSize: 40,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _userStats,
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: gradientColors,
                  ),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: gradientColors
                          .map((color) => color.withOpacity(0.3))
                          .toList(),
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  // tooltipBgColor: Colors.blueAccent.withOpacity(0.7),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((touchedSpot) {
                      final date = DateFormat('MM/dd').format(
                        DateTime.now().subtract(Duration(
                            days: _userStats.length - touchedSpot.spotIndex)),
                      );
                      return LineTooltipItem(
                        'Date: $date\nUsers: ${touchedSpot.y.toInt()}',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    int index = value.toInt();
    if (index >= 0 && index < 12) {
      DateTime now = DateTime.now();
      DateTime month = DateTime(now.year, now.month - (11 - index), 1);
      String monthLabel =
          DateFormat('MMM').format(month); // 월 표시 (예: Jan, Feb 등)

      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(monthLabel, style: const TextStyle(fontSize: 16)),
      );
    }
    return Container();
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      '${value.toInt()}',
      style: const TextStyle(fontSize: 10),
    );
  }
}
