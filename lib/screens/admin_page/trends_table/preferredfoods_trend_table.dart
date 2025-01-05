import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class PreferredfoodsTrendTable extends StatefulWidget {
  @override
  _PreferredfoodsTrendTableState createState() =>
      _PreferredfoodsTrendTableState();
}

class _PreferredfoodsTrendTableState extends State<PreferredfoodsTrendTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '순위', 'state': SortState.none},
    {'name': '카테고리', 'state': SortState.none},
    {'name': '식품명', 'state': SortState.none},
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
        .collection('preferred_foods_categories')
        .where('isDefault', isEqualTo: false) // 기본 카테고리 제외
        .get();

    List<Map<String, dynamic>> foods = [];

    for (var doc in snapshot.docs) {
      final data = doc.data(); // Firestore 문서 데이터를 가져옴

      if (data.containsKey('category') && data['category'] is Map<String, dynamic>) {
        Map<String, dynamic> categoryMap = data['category']; // 카테고리 필드 가져오기

        categoryMap.forEach((categoryName, foodItems) {
          if (foodItems is List<dynamic>) {
            for (var food in foodItems) {
              foods.add({
                '순위': rank++, // Firestore 문서 ID
                '카테고리': categoryName, // 카테고리명 (예: "채소")
                '식품명': food.toString(), // 각 식품명 (예: "당근")
                '생성횟수': data['생성횟수'] ?? 0, // 기본값 0
              });
            }
          }
        });
      }
    }

    setState(() {
      userData = foods;
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
                DataCell(Text(row['식품명'].toString(),
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