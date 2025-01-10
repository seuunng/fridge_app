import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class RecordCategoriesTrendTable extends StatefulWidget {
  @override
  _RecordCategoriesTrendTableState createState() =>
      _RecordCategoriesTrendTableState();
}

class _RecordCategoriesTrendTableState extends State<RecordCategoriesTrendTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '순위', 'state': SortState.none},
    {'name': '카테고리', 'state': SortState.none},
    {'name': '항목', 'state': SortState.none},
    {'name': '생성횟수', 'state': SortState.none},
  ];

  List<Map<String, dynamic>> userData = [];

  int rank = 1;

  @override
  void initState() {
    super.initState();
    _loadFoodsData();
  }

  Future<void> _loadFoodsData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('record_categories')
        .where('isDefault', isEqualTo: false) // 기본 카테고리 제외
        .get();

    Map<String, Map<String, dynamic>> unitMap = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();

      if (data.containsKey('zone') && data.containsKey('units')) {
        String category = data['zone']; // `zone` 값을 가져옴 (카테고리)
        List<dynamic> units = data['units']; // `units` 리스트

        for (var unit in units) {
          String unitName = unit.toString();

          if (unitMap.containsKey(unitName)) {
            // 동일한 `unit`이 이미 있으면 생성횟수 증가
            unitMap[unitName]!['생성횟수'] += 1;
          } else {
            // 새로운 `unit` 추가
            unitMap[unitName] = {
              '순위': 0, // 나중에 순위 재설정
              '카테고리': category, // `zone` 값을 저장
              '항목': unitName, // `unit` 값을 저장
              '생성횟수': 1, // 최초 생성 시 1부터 시작
            };
              }
            }
          }
      }


    // 리스트 변환 및 정렬 (생성횟수 기준 내림차순)
    List<Map<String, dynamic>> unitsList = unitMap.values.toList();
    unitsList.sort((a, b) => b['생성횟수'].compareTo(a['생성횟수']));

    // 순위 재설정
    for (int i = 0; i < unitsList.length; i++) {
      unitsList[i]['순위'] = i + 1;
    }

    setState(() {
      userData = unitsList;
    });
  }

  void _sortBy(String columnName, SortState currentState) {
    setState(() {
      // 열의 정렬 상태를 업데이트
      for (var column in columns) {
        if (column['name'] == columnName) {
          column['state'] = currentState == SortState.none
              ? SortState.ascending
              : (currentState == SortState.ascending
              ? SortState.descending
              : SortState.none);
        } else {
          column['state'] = SortState.none;
        }
      }

      if (currentState == SortState.none) {
        userData.sort((a, b) => a['생성횟수'].compareTo(b['생성횟수']));
      } else {
        userData.sort((a, b) {
          int result;
          result = a[columnName].compareTo(b[columnName]);
          return currentState == SortState.ascending ? result : -result;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns.map((column) {
              return DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy(column['name'], column['state']),
                  child: Row(
                    children: [
                      Text(column['name'],
                          style: TextStyle(color: theme.colorScheme.onSurface)),
                      Icon(
                        column['state'] == SortState.ascending
                            ? Icons.arrow_upward
                            : column['state'] == SortState.descending
                            ? Icons.arrow_downward
                            : Icons.sort,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            rows: userData.map((row) {
              return DataRow(cells: [
                DataCell(Text(row['순위'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '순위' 필드 사용
                DataCell(Text(row['카테고리'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '순위' 필드 사용
                DataCell(Text(row['항목'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '키워드' 필드 사용
                DataCell(Text(row['생성횟수'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), //  // '공유' 필드 사용
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}