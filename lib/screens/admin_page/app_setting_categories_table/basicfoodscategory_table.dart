import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';

enum SortState { none, ascending, descending }

class BasicfoodscategoryTable extends StatefulWidget {
  @override
  _BasicfoodscategoryTableState createState() =>
      _BasicfoodscategoryTableState();
}

class _BasicfoodscategoryTableState extends State<BasicfoodscategoryTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '선택', 'state': SortState.none},
    {'name': '연번', 'state': SortState.none},
    {'name': '기본식품 카테고리', 'state': SortState.none},
    {'name': '변동', 'state': SortState.none}
  ];

  List<Map<String, dynamic>> userData = [];

  List<int> selectedRows = [];

  final TextEditingController _foodCategoryController = TextEditingController();

  void _addFood() {
    setState(() {
      userData.add({
        '연번': userData.length + 1,
        '기본식품 카테고리': _foodCategoryController.text,
      });

      _foodCategoryController.clear();
    });
  }

  void _editFood(int index) {
    setState(() {
      Map<String, dynamic> selectedFood = userData[index];
      _foodCategoryController.text = selectedFood['기본식품 카테고리'];
    });
  }

  void _deleteSelectedRows() {
    setState(() {
      selectedRows.sort((a, b) => b.compareTo(a)); // 역순으로 정렬하여 삭제
      for (var index in selectedRows) {
        userData.removeAt(index);
      }
      selectedRows.clear(); // 삭제 후 선택 초기화
    });
  }

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
        userData.sort((a, b) => a['연번'].compareTo(b['연번']));
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
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              // 제목이 있는 행
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(80),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(80),
                },
                children: [
                  TableRow(
                    children: columns.map((column) {
                      return TableCell(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  width: 1, color: Colors.black), // 셀 아래 테두리 추가
                            ),
                          ),
                          child: column['name'] == '선택' ||
                                  column['name'] == '변동'
                              ? Center(
                                  child: Text(column['name']),
                                )
                              : GestureDetector(
                                  onTap: () =>
                                      _sortBy(column['name'], column['state']),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(column['name']),
                                        Icon(
                                          column['state'] == SortState.ascending
                                              ? Icons.arrow_upward
                                              : column['state'] ==
                                                      SortState.descending
                                                  ? Icons.arrow_downward
                                                  : Icons.sort,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(80),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(80),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            width: 1, color: Colors.black), // 셀 아래 테두리 추가
                      ),
                    ),
                    children: [
                      TableCell(child: SizedBox.shrink()),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text('no'))),
                      TableCell(
                        child: TextField(
                          controller: _foodCategoryController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '식품명',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            suffixIcon: _foodCategoryController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _foodCategoryController
                                            .clear(); // 입력 필드 내용 삭제
                                      });
                                    },
                                  )
                                : null, // 내용이 없을 때는 버튼을 표시하지 않음
                          ),
                          onChanged: (value) {
                            setState(() {}); // 입력 내용이 바뀔 때 상태 업데이트
                          },
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                            onPressed: _addFood,
                            iconTitle: Icons.add,
                            buttonTitle: '추가',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(80),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(80),
                },
                children: userData.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> row = entry.value;
                  return TableRow(
                    children: [
                      TableCell(
                        child: Checkbox(
                          value: selectedRows.contains(index),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedRows.add(index);
                              } else {
                                selectedRows.remove(index);
                              }
                            });
                          },
                        ),
                      ),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Container(
                              height: 40,
                              child:
                                  Center(child: Text(row['연번'].toString())))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['기본식품 카테고리']))),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                            onPressed: () => _editFood(row['연번'] - 1),
                            iconTitle: Icons.edit,
                            buttonTitle: '수정',
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              // 선택한 행 삭제 버튼
              BasicElevatedButton(
                onPressed: selectedRows.isNotEmpty ? _deleteSelectedRows : null,
                iconTitle: Icons.delete,
                buttonTitle: '선택한 항목 삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
