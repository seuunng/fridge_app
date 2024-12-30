import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class InputkeywordTrendTable extends StatefulWidget {

  @override
  _InputkeywordTrendTableState createState() =>
      _InputkeywordTrendTableState();
}

class _InputkeywordTrendTableState extends State<InputkeywordTrendTable> {
  List<Map<String, dynamic>> searchTrends = [];

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
          '순위': snapshot.docs.indexOf(doc) + 1,
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

  // 사용자 데이터
  // List<Map<String, dynamic>> userData = [
  //   {
  //     '순위': 1,
  //     '키워드': '탄탄멘',
  //     '입력횟수': 300,
  //   },
  //   {
  //     '순위': 2,
  //     '키워드': '마라',
  //     '입력횟수': 300,
  //   },
  //   {
  //     '순위': 3,
  //     '키워드': '다이어트',
  //     '입력횟수': 300,
  //   },
  // ];

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

      // 정렬 수행
      if (currentState == SortState.none) {
        // 정렬 없으면 원래 데이터 순서 유지
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
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top:1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns.map((column) {
              return DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy(column['name'], column['state']),
                  child: Row(
                    children: [
                      Text(column['name']),
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
            rows: searchTrends.map((row) {
              return DataRow(cells: [
                DataCell(Text(row['순위'].toString())), // '순위' 필드 사용
                DataCell(Text(row['키워드'].toString())), // '키워드' 필드 사용
                DataCell(Text(row['입력횟수'].toString())), //  // '공유' 필드 사용
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
