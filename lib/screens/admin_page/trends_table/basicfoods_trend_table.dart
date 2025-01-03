import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class BasicfoodsTrendTable extends StatefulWidget {
  @override
  _BasicfoodsTrendTableState createState() => _BasicfoodsTrendTableState();
}

class _BasicfoodsTrendTableState extends State<BasicfoodsTrendTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '순위', 'state': SortState.none},
    {'name': '식품명', 'state': SortState.none},
    {'name': '생성횟수', 'state': SortState.none},
  ];

  List<Map<String, dynamic>> userData = [
    {
      '순위': 1,
      '식품명': '아보카도',
      '생성횟수': 10,
    },
    {
      '순위': 2,
      '식품명': '리치',
      '생성횟수': 6,
    },
    {
      '순위': 3,
      '식품명': '쌀국수',
      '생성횟수': 2,
    },
  ];

  void _sortBy(String columnName, SortState currentState) {
    setState(() {
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
        userData.sort((a, b) => a['순위'].compareTo(b['순위']));
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
