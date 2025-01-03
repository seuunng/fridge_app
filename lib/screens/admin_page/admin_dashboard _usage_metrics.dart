import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardUsageMetrics extends StatefulWidget {
  @override
  _AdminDashboardUsageMetricsState createState() =>
      _AdminDashboardUsageMetricsState();
}

class _AdminDashboardUsageMetricsState
    extends State<AdminDashboardUsageMetrics> {
  final bool isShowingMainData = true;
  String selectedPeriod = '전체';

  Future<Map<String, int>> fetchMonthlyData(String collectionName) async {
    final collection = FirebaseFirestore.instance.collection(collectionName);
    final querySnapshot = await collection.get();

    final Map<String, int> monthlyCounts = {};

    for (var doc in querySnapshot.docs) {
      // 필드 확인
      final createdAt = (doc.data().containsKey('date'))
          ? (doc['date'] as Timestamp?)?.toDate()
          : null;
      final scrapedAt = (doc.data().containsKey('scrapedAt'))
          ? (doc['scrapedAt'] as Timestamp?)?.toDate()
          : null;

      // 사용할 필드 선택
      final timestamp = createdAt ?? scrapedAt;

      if (timestamp != null) {
        final monthKey =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}';
        monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
      }
    }

    return monthlyCounts;
  }


  List<FlSpot> calculateCumulativeData(Map<String, int> monthlyData) {
    int cumulativeCount = 0;

    return List.generate(12, (monthIndex) {
      final monthKey = '2024-${(monthIndex + 1).toString().padLeft(2, '0')}';
      cumulativeCount += monthlyData[monthKey] ?? 0;

      return FlSpot((monthIndex + 1).toDouble(), cumulativeCount.toDouble());
    });
  }

  Future<Map<String, int>> fetchSharedData() async {
    final collection = FirebaseFirestore.instance.collection('recipe');
    final querySnapshot = await collection.get();

    final Map<String, int> monthlyCounts = {};

    for (var doc in querySnapshot.docs) {
      if (!doc.data().containsKey('sharedCount')) continue; // sharedCount 필드가 없으면 건너뛰기
      final createdAt = (doc['date'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final monthKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        final Map<String, num> monthlyCounts = {};
        monthlyCounts[monthKey] =
            (monthlyCounts[monthKey] ?? 0) + (doc['sharedCount'] ?? 0);
      }
    }
    return monthlyCounts;
  }

  Future<List<LineChartBarData>> buildCumulativeChartData() async {
    final recipeData = await fetchMonthlyData('recipe');
    final recordData = await fetchMonthlyData('record');
    // final sharedData = await fetchSharedData();
    final scrapedData = await fetchMonthlyData('scraped_recipes');

    print('scrapedData $scrapedData');

    final recipeSpots = calculateCumulativeData(recipeData);
    final recordSpots = calculateCumulativeData(recordData);
    // final sharedSpots = calculateCumulativeData(sharedData);
    final scrapSpots = calculateCumulativeData(scrapedData);

    return [
      LineChartBarData(
        isCurved: true,
        color: Colors.green,
        barWidth: 4,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        spots: recipeSpots,
      ),
      LineChartBarData(
        isCurved: true,
        color: Colors.pink,
        barWidth: 4,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        spots: recordSpots,
      ),
      // LineChartBarData(
      //   isCurved: true,
      //   color: Colors.yellow,
      //   barWidth: 4,
      //   isStrokeCapRound: true,
      //   dotData: const FlDotData(show: true),
      //   belowBarData: BarAreaData(show: false),
      //   spots: sharedSpots,
      // ),
      LineChartBarData(
        isCurved: true,
        color: Colors.cyan,
        barWidth: 4,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        spots: scrapSpots,
      ),
    ];
  }

  List<LineChartBarData> lineBarsDataFromFetchedData(Map<String, int> data) {
    final recipeCount = data['recipes']?.toDouble() ?? 0;
    final recordCount = data['records']?.toDouble() ?? 0;
    final scrapedRecipeCount = data['scraped_recipes']?.toDouble() ?? 0;


    return [
      LineChartBarData(
        isCurved: true,
        color: Colors.green,
        barWidth: 8,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        spots: [
          FlSpot(1, recipeCount), // 레시피 갯수를 첫 번째 데이터에 반영
          // FlSpot(3, recipeCount * 0.8), // 예제 데이터 (변경 가능)
          // FlSpot(5, recipeCount * 0.6),
        ],
      ),
      LineChartBarData(
        isCurved: true,
        color: Colors.pink,
        barWidth: 8,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        spots: [
          FlSpot(1, recordCount), // 기록 갯수를 첫 번째 데이터에 반영
          // FlSpot(3, recordCount * 0.7), // 예제 데이터 (변경 가능)
          // FlSpot(5, recordCount * 0.5),
        ],
      ),
      LineChartBarData(
        isCurved: true,
        color: Colors.yellow,
        barWidth: 8,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
        spots: [
          FlSpot(1, scrapedRecipeCount), // 기록 갯수를 첫 번째 데이터에 반영
          // FlSpot(3, recordCount * 0.7), // 예제 데이터 (변경 가능)
          // FlSpot(5, recordCount * 0.5),
        ],
      ),
    ];
  }

  int calculateTotal(Map<String, int> data) {
    return data.values.fold(0, (sum, value) => sum + value);
  }

  Future<Map<String, int>> fetchAllTotals() async {
    final recipeData = await fetchMonthlyData('recipe');
    final recordData = await fetchMonthlyData('record');
    final sharedData = await fetchSharedData();
    final scrapedRecipeData = await fetchMonthlyData('scraped_recipes');

    return {
      'recipe': calculateTotal(recipeData),
      'record': calculateTotal(recordData),
      'shared': calculateTotal(sharedData),
      'scraped': calculateTotal(scrapedRecipeData),
    };
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text('어플 실적 현황'),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
            future: Future.wait([
              fetchAllTotals(), // Map<String, int> 반환
              buildCumulativeChartData(), // List<LineChartBarData> 반환
            ]).then((results) => {
              'totals': results[0] as Map<String, int>, // 명시적 캐스팅
              'chartData': results[1] as List<LineChartBarData>, // 명시적 캐스팅
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
              }

              final data = snapshot.data!;
              final totals = data['totals'] as Map<String, int>;
              final chartData = data['chartData'] as List<LineChartBarData>;

              final recipeTotal = totals['recipe'] ?? 0;
              final recordTotal = totals['record'] ?? 0;
              final scrapedTotal = totals['scraped'] ?? 0;

              return Column(
                children: [
                  // Padding(
                  //     padding: const EdgeInsets.all(8.0),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.spaceAround,
                  //       children: [
                  //         _buildRadioButton('전체'),
                  //         _buildRadioButton('1년'),
                  //         _buildRadioButton('6개월'),
                  //         _buildRadioButton('3개월'),
                  //       ],
                  //     )),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Container(
                      child: Container(
                        margin: const EdgeInsets.all(20.0),
                        padding: const EdgeInsets.all(20.0),
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
                        child: LineChart(
                          LineChartData(
                            lineBarsData: chartData,
                            clipData: FlClipData.none(),
                            // clipData: FlClipData.all(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  // reservedSize: 20,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    // value는 X축의 플롯 위치, 정수값만 처리
                                    if (value % 1 == 0 &&
                                        value >= 1 &&
                                        value <= 12) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text('${value.toInt()}월',
                                            style: TextStyle(fontSize: 12)),
                                      );
                                    }
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(''), // 잘못된 값은 빈 문자열 처리
                                    );
                                  },
                                ),
                              ),
                              topTitles: AxisTitles(
                                sideTitles:
                                    SideTitles(showTitles: false), // 상단 숫자 제거
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // 범례를 표시하는 Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LegendItem(color: Colors.green, text: '레시피', value: recipeTotal),
                        LegendItem(color: Colors.pink, text: '기록', value: recordTotal),
                        LegendItem(color: Colors.cyan, text: '스크랩', value: scrapedTotal),
                      ],
                    ),
                  ),
                ],
              );
            }));
  }

// 라디오 버튼을 생성하는 함수
  Widget _buildRadioButton(String period) {
    return Row(
      children: [
        Radio<String>(
          value: period,
          groupValue: selectedPeriod,
          onChanged: (value) {
            setState(() {
              selectedPeriod = value!;
              // 선택된 기간에 따라 차트 데이터를 변경할 수 있음
              // sampleData1 또는 sampleData2를 조정하는 로직을 여기에 추가
            });
          },
        ),
        Text(period),
      ],
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final int value;

  LegendItem({required this.color, required this.text, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        SizedBox(width: 8),
        Text('$text: $value',
            style: TextStyle(fontSize: 14,
                color: theme.colorScheme.onSurface)),
      ],
    );
  }
}
