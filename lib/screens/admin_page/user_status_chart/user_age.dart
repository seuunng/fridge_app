import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class UserAge extends StatefulWidget {

  UserAge({super.key});

  @override
  State<StatefulWidget> createState() => UserAgeState();
}

class UserAgeState extends State<UserAge> {
  final double width = 7;
  List<BarChartGroupData> showingBarGroups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    final data = await fetchUserAgeGenderData();
    setState(() {
      showingBarGroups = convertToChartData(data);
      isLoading = false;
    });
  }

  Future<Map<String, Map<String, int>>> fetchUserAgeGenderData() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final int currentYear = DateTime.now().year;

      Map<String, Map<String, int>> ageGenderData = {
        "10대 이하": {"M": 0, "F": 0},
        "20대": {"M": 0, "F": 0},
        "30대": {"M": 0, "F": 0},
        "40대": {"M": 0, "F": 0},
        "50대": {"M": 0, "F": 0},
        "60대": {"M": 0, "F": 0},
        "70대 이상": {"M": 0, "F": 0},
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data.containsKey('birthYear') && data.containsKey('gender')) {
          final dynamic birthYearRaw = data['birthYear'];
          int birthYear;
          if (birthYearRaw is int) {
            birthYear = birthYearRaw; // 이미 int인 경우
          } else if (birthYearRaw is String) {
            birthYear = int.tryParse(birthYearRaw) ?? currentYear; // String을 int로 변환
          } else {
            birthYear = currentYear; // 잘못된 데이터는 현재 연도로 처리
          }
          String gender = data['gender'];
          int age = currentYear - birthYear;

          String ageGroup;
          if (age < 20) {
            ageGroup = "10대 이하";
          } else if (age < 30) {
            ageGroup = "20대";
          } else if (age < 40) {
            ageGroup = "30대";
          } else if (age < 50) {
            ageGroup = "40대";
          } else if (age < 60) {
            ageGroup = "50대";
          } else if (age < 70) {
            ageGroup = "60대";
          } else {
            ageGroup = "70대 이상";
          }

          if (ageGenderData.containsKey(ageGroup) &&
              (gender == "M" || gender == "F")) {
            ageGenderData[ageGroup]![gender] = ageGenderData[ageGroup]![gender]! + 1;
          }
        }
      }

      return ageGenderData;
    } catch (e) {
      print("❌ Firestore 데이터 가져오기 오류: $e");
      return {};
    }
  }

  List<BarChartGroupData> convertToChartData(Map<String, Map<String, int>> data) {
    List<BarChartGroupData> barGroups = [];
    int index = 0;

    data.forEach((ageGroup, genderData) {
      double maleCount = genderData["M"]?.toDouble() ?? 0;
      double femaleCount = genderData["F"]?.toDouble() ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: index,
          barsSpace: 16,
          barRods: [
            BarChartRodData(toY: maleCount, color: Colors.blue, width: 7),
            BarChartRodData(toY: femaleCount, color: Colors.red, width: 7),
          ],
        ),
      );
      index++;
    });

    return barGroups;
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0),
      child: Container(
        constraints: BoxConstraints(maxWidth: double.infinity, maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.only(top: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: 20,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 5,
                        getTitlesWidget: leftTitles,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: bottomTitles,
                        reservedSize: 42,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // ✅ 상단 범례 제거
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false), // ✅ 오른쪽 범례 제거
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: showingBarGroups,
                  gridData: const FlGridData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    final titles = <String>["10대 이하", "20대", "30대", "40대", "50대", "60대", "70대 이상"];

    return Text(
        titles[value.toInt()],
        style: const TextStyle(
          color: Color(0xff7589a2),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
    );
  }

  Widget leftTitles(double value, TitleMeta meta) {
    return Text("${value.toInt()}", style: TextStyle(fontSize: 12)
    );
  }
}
