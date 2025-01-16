import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class InputkeywordTrendTable extends StatefulWidget {
  @override
  _InputkeywordTrendTableState createState() => _InputkeywordTrendTableState();
}

class _InputkeywordTrendTableState extends State<InputkeywordTrendTable> {
  List<Map<String, dynamic>> searchTrends = [];

  int rank = 1; // 순위를 1부터 시작
  @override
  void initState() {
    super.initState();
    _loadSearchTrends();
  }

  void _loadSearchTrends() async {
    final trends = await _fetchSearchTrends();
    setState(() {
      searchTrends = trends;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSearchTrends() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('search_keywords')
          .orderBy('count', descending: true) // 검색 횟수 기준 내림차순 정렬
          .limit(10) // 상위 10개만 가져옴
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          '순위': rank++,
          '키워드': data['keyword'],
          '입력횟수': data['count'],
        };
      }).toList();
    } catch (e) {
      print('검색 트렌드 데이터를 가져오는 중 오류 발생: $e');
      return [];
    }
  }

  // 각 열에 대한 정렬 상태를 관리하는 리스트
  List<Map<String, dynamic>> columns = [
    {'name': '순위', 'state': SortState.none},
    {'name': '키워드', 'state': SortState.none},
    {'name': '입력횟수', 'state': SortState.none},
  ];

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
        searchTrends.sort((a, b) => a['순위'].compareTo(b['순위']));
      } else {
        searchTrends.sort((a, b) {
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
                          color: theme.colorScheme.onSurface

                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            rows: searchTrends.map((row) {
              return DataRow(cells: [
                DataCell(Text(row['순위'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '순위' 필드 사용
                DataCell(Text(row['키워드'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '키워드' 필드 사용
                DataCell(Text(row['입력횟수'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), //  // '공유' 필드 사용
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
