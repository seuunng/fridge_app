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
  Future<Map<String, Map<String, int>>> fetchMonthlyData() async {
    final collections = [
      'recipe',
      'record',
      'scraped_recipes',
      'recipe_reviews'
    ];
    final Map<String, Map<String, int>> allData = {};

    for (var collectionName in collections) {
      final collection = FirebaseFirestore.instance.collection(collectionName);
      final querySnapshot = await collection.get();

      final Map<String, int> monthlyCounts = {};

      for (var doc in querySnapshot.docs) {
        DateTime? timestamp;

        // 🔥 Firestore에서 timestamp 필드 가져오기
        if (collectionName == 'recipe_reviews' &&
            doc.data().containsKey('timestamp')) {
          final timestampRaw = doc['timestamp'];
          if (timestampRaw is Timestamp) {
            timestamp = timestampRaw.toDate();
          }
        } else {
          final createdAt = doc.data().containsKey('date')
              ? (doc['date'] as Timestamp?)?.toDate()
              : null;
          final scrapedAt = doc.data().containsKey('scrapedAt')
              ? (doc['scrapedAt'] as Timestamp?)?.toDate()
              : null;
          timestamp = createdAt ?? scrapedAt;
        }

        // 🔥 timestamp가 null이 아닌 경우만 처리
        if (timestamp != null) {
          final monthKey =
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}';
          monthlyCounts[monthKey] = (monthlyCounts[monthKey] ?? 0) + 1;
        }
      }

      allData[collectionName] = monthlyCounts;
    }

    return allData;
  }

  Future<List<LineChartBarData>> buildCumulativeChartData(
      Map<String, Map<String, int>> allData) async {
    List<FlSpot> calculateCumulativeData(Map<String, int> monthlyData) {
      int cumulativeCount = 0;
      return List.generate(12, (monthIndex) {
        final monthKey = '2024-${(monthIndex + 1).toString().padLeft(2, '0')}';
        cumulativeCount += monthlyData[monthKey] ?? 0;
        return FlSpot((monthIndex + 1).toDouble(), cumulativeCount.toDouble());
      });
    }

    final recipeSpots = calculateCumulativeData(allData['recipe'] ?? {});
    final recordSpots = calculateCumulativeData(allData['record'] ?? {});
    final scrapSpots =
        calculateCumulativeData(allData['scraped_recipes'] ?? {});
    final reviewSpots =
        calculateCumulativeData(allData['recipe_reviews'] ?? {});

    return [
      LineChartBarData(
          isCurved: true,
          color: Colors.green,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
          spots: recipeSpots),
      LineChartBarData(
          isCurved: true,
          color: Colors.pink,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
          spots: recordSpots),
      LineChartBarData(
          isCurved: true,
          color: Colors.yellow,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
          spots: reviewSpots),
      LineChartBarData(
          isCurved: true,
          color: Colors.cyan,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
          spots: scrapSpots),
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
    final allData = await fetchMonthlyData(); // ✅ 전체 데이터를 한 번에 가져옴

    return {
      'recipe': calculateTotal(allData['recipe'] ?? {}),
      'record': calculateTotal(allData['record'] ?? {}),
      'scraped': calculateTotal(allData['scraped_recipes'] ?? {}),
      'review': calculateTotal(allData['recipe_reviews'] ?? {}),
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
            future: fetchMonthlyData().then((allData) => {
                  'allData': allData,
                  'totals': {
                    'recipe': calculateTotal(allData['recipe'] ?? {}),
                    'record': calculateTotal(allData['record'] ?? {}),
                    'scraped': calculateTotal(allData['scraped_recipes'] ?? {}),
                    'review': calculateTotal(allData['recipe_reviews'] ?? {}),
                  }
                }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
              }

              final allData =
                  snapshot.data!['allData'] as Map<String, Map<String, int>>;
              final totals = {
                'recipe': calculateTotal(allData['recipe'] ?? {}),
                'record': calculateTotal(allData['record'] ?? {}),
                'scraped': calculateTotal(allData['scraped_recipes'] ?? {}),
                'review': calculateTotal(allData['recipe_reviews'] ?? {}),
              };

              return ListView(children: [
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
                  padding: const EdgeInsets.all(0.0),
                  child: FutureBuilder<List<LineChartBarData>>(
                    future: buildCumulativeChartData(allData), // ✅ 데이터 전달
                    builder: (context, chartSnapshot) {
                      if (chartSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (chartSnapshot.hasError) {
                        return Center(
                            child: Text('그래프 데이터를 불러오는 중 오류가 발생했습니다.'));
                      }

                      final chartData = chartSnapshot.data!;
                      return Container(
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
                        child: LineChart(LineChartData(
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
                                    return Text('${value.toInt()}월',
                                          style: TextStyle(fontSize: 12)
                                    ); // ios 수정
                                  }
                                  return Text('');// ios 수정
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
                        )),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                // 범례를 표시하는 Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        LegendItem(
                            color: Colors.green,
                            text: '레시피',
                            value: totals['recipe'] ?? 0),
                        SizedBox(width: 8,),
                        LegendItem(
                            color: Colors.cyan,
                            text: '스크랩',
                            value: totals['scraped'] ?? 0),
                        SizedBox(width: 8,),
                        LegendItem(
                            color: Colors.yellow,
                            text: '리뷰',
                            value: totals['review'] ?? 0),
                        SizedBox(width: 8,),
                        LegendItem(
                            color: Colors.pink,
                            text: '기록',
                            value: totals['record'] ?? 0),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // 가로 스크롤 추가
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('항목', style: TextStyle(color: theme.colorScheme.onSurface))),
                      ...List.generate(12, (index) =>
                          DataColumn(label: Text('${index + 1}월', style: TextStyle(color: theme.colorScheme.onSurface)))),
                      DataColumn(label: Text('합계', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                    ],
                    rows: [
                      DataRow(cells: [
                        DataCell(Text('레시피', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))] +
                          List.generate(12, (index) {
                            String monthKey = '2024-${(index + 1).toString().padLeft(2, '0')}';
                            return DataCell(Text('${allData['recipe']?[monthKey] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface)));
                          }) +
                          [DataCell(Text('${totals['recipe']}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))]
                      ),
                      DataRow(cells: [
                        DataCell(Text('스크랩', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))] +
                          List.generate(12, (index) {
                            String monthKey = '2024-${(index + 1).toString().padLeft(2, '0')}';
                            return DataCell(Text('${allData['scraped_recipes']?[monthKey] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface)));
                          }) +
                          [DataCell(Text('${totals['scraped']}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))]
                      ),
                      DataRow(cells: [
                        DataCell(Text('리뷰', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))] +
                          List.generate(12, (index) {
                            String monthKey = '2024-${(index + 1).toString().padLeft(2, '0')}';
                            return DataCell(Text('${allData['recipe_reviews']?[monthKey] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface)));
                          }) +
                          [DataCell(Text('${totals['review']}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))]
                      ),
                      DataRow(cells: [
                        DataCell(Text('기록', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))] +
                          List.generate(12, (index) {
                            String monthKey = '2024-${(index + 1).toString().padLeft(2, '0')}';
                            return DataCell(Text('${allData['record']?[monthKey] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface)));
                          }) +
                          [DataCell(Text('${totals['record']}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))]
                      ),
                      // 📌 **합계 행 추가**
                      DataRow(cells: [
                        DataCell(Text('합계', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)))] +
                          List.generate(12, (index) {
                            String monthKey = '2024-${(index + 1).toString().padLeft(2, '0')}';
                            return DataCell(Text(
                              '${(allData['recipe']?[monthKey] ?? 0) + (allData['record']?[monthKey] ?? 0) +
                                  (allData['recipe_reviews']?[monthKey] ?? 0) + (allData['scraped_recipes']?[monthKey] ?? 0)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ));
                          }) +
                          [DataCell(Text(
                            '${totals.values.reduce((a, b) => a + b)}', // ✅ 모든 총합
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ))]
                      ),
                    ],
                  ),
                ),
              ]);
            }));
  }
}

// 라디오 버튼을 생성하는 함수
//   Widget _buildRadioButton(String period) {
//     return Row(
//       children: [
//         Radio<String>(
//           value: period,
//           groupValue: selectedPeriod,
//           onChanged: (value) {
//             setState(() {
//               selectedPeriod = value!;
//               // 선택된 기간에 따라 차트 데이터를 변경할 수 있음
//               // sampleData1 또는 sampleData2를 조정하는 로직을 여기에 추가
//             });
//           },
//         ),
//         Text(period),
//       ],
//     );
//   }

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
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
      ],
    );
  }
}
