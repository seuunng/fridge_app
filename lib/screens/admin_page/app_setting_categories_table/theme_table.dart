import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/models/recipe_thema_model.dart';

enum SortState { none, ascending, descending }

class ThemeTable extends StatefulWidget {
  @override
  _ThemeTableState createState() => _ThemeTableState();
}

class _ThemeTableState extends State<ThemeTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '선택', 'state': SortState.none},
    {'name': '연번', 'state': SortState.none},
    {'name': '테마명', 'state': SortState.none},
    {'name': '변동', 'state': SortState.none}
  ];

  List<Map<String, dynamic>> userData = [];
  List<Map<String, dynamic>> originalData = [];

  List<int> selectedRows = [];

  bool isEditing = false;
  int? selectedThemesIndex; // 수정할 아이템의 인덱스

  final TextEditingController _themeNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadThemesData();
  }

  Future<void> _loadThemesData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('recipe_thema_categories')
        .get();

    List<Map<String, dynamic>> themes = [];

    snapshot.docs.forEach((doc) {
      final theme = RecipeThemaModel.fromFirestore(doc);

      themes.add({
        '연번': themes.length + 1, // 연번은 자동으로 증가하도록 설정
        '테마명': theme.categories,
        'documentId': doc.id,
      });
    });

    setState(() {
      userData = themes;
      originalData = List.from(themes);
    });
  }

  void _addThemes(String newCategoryName) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('recipe_thema_categories');

    await snapshot.add({
      'categories': newCategoryName,
    });

    userData.add({
      '테마명': newCategoryName, // 테마명
    });
    _themeNameController.clear();
  }

  void _editTheme(int index) async {
    final selectedThemes = userData[index];

    setState(() {
      _themeNameController.text = selectedThemes['테마명'] ?? '';
    });
    isEditing = true;
    selectedThemesIndex = index;
  }

  void _updateThemes(int index, String updatedCategoryName) async {
    final selectedThemes = userData[index];
    final String? documentId = selectedThemes['documentId'];

    print(updatedCategoryName);
    print(documentId);

    if (documentId != null) {
      try {
        final snapshot = FirebaseFirestore.instance
            .collection('recipe_thema_categories')
            .doc(documentId);

        await snapshot.update({
          'categories': updatedCategoryName,
        });

        setState(() {
          userData[index]['테마명'] = updatedCategoryName;
        });
      } catch (e) {
        print('Firestore에 데이터를 업데이트하는 중 오류가 발생했습니다: $e');
      }
    }
  }

  void _deleteSelectedRows(int index) async {
    final selectedThemes = userData[index];

    bool shouldDelete = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('삭제 확인'),
            content: Text('선택한 항목을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // 취소 선택 시 false 반환
                },
                child: Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // 확인 선택 시 true 반환
                },
                child: Text('확인'),
              ),
            ],
          );
        });
    if (shouldDelete == true) {
      try {
        final String? documentId = selectedThemes['documentId'];

        final snapshot = await FirebaseFirestore.instance
            .collection('recipe_thema_categories')
            .where('categories', isEqualTo: selectedThemes['테마명'])
            .get();

        if (snapshot.docs.isNotEmpty) {
          final docRef = snapshot.docs.first.reference;

          await docRef.delete();

          setState(() {
            userData.removeAt(index); // 로컬 상태에서도 데이터 삭제
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('선택한 항목이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        print('Error deleting food from Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _sortBy(String columnName, SortState currentState) {
    SortState newSortState;
    if (currentState == SortState.none) {
      newSortState = SortState.ascending;
    } else if (currentState == SortState.ascending) {
      newSortState = SortState.descending;
    } else {
      newSortState = SortState.none;
    }
    setState(() {
      // 선택한 열에 대한 상태만 업데이트
      for (var column in columns) {
        if (column['name'] == columnName) {
          column['state'] = newSortState;
        } else {
          column['state'] = SortState.none;
        }
      }

      // 정렬 동작
      if (newSortState == SortState.none) {
        userData = List.from(originalData); // 원본 데이터로 복원
      } else {
        userData.sort((a, b) {
          int result = a[columnName].compareTo(b[columnName]);
          return newSortState == SortState.ascending ? result : -result;
        });
      }
    });
  }

  void _refreshTable() async {
    await _loadThemesData();
    setState(() {}); // 화면을 새로고침
  }

  void _clearFields() {
    _themeNameController.clear();
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
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(100),
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
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(100),
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
                          controller: _themeNameController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '테마명',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            suffixIcon: _themeNameController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _themeNameController
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
                            onPressed: () {
                              // final TextEditingController themesNameController = TextEditingController();

                              if (isEditing) {
                                if (selectedThemesIndex != null) {
                                  _updateThemes(selectedThemesIndex!,
                                      _themeNameController.text);
                                }
                              } else {
                                if (_themeNameController != null)
                                  _addThemes(_themeNameController.text);
                              }

                              setState(() {
                                _clearFields();
                                _refreshTable();
                              });
                            },
                            iconTitle: Icons.add,
                            buttonTitle: '추가',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 데이터가 추가되는 테이블
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(160),
                  3: FixedColumnWidth(100),
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
                          child: Center(child: Text(row['테마명'].toString()))),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                            onPressed: () =>
                                _editTheme(row['연번'] - 1), // 수정 버튼 클릭 시
                            iconTitle: Icons.edit,
                            buttonTitle: '수정',
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              SizedBox(
                height: 20,
              ),
              // 선택한 행 삭제 버튼
              BasicElevatedButton(
                onPressed: selectedRows.isNotEmpty
                    ? () {
                        // 선택된 모든 행 삭제
                        for (int index in selectedRows) {
                          _deleteSelectedRows(index);
                        }
                      }
                    : null,
                iconTitle: Icons.edit,
                buttonTitle: '수정',
              ),
              SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
