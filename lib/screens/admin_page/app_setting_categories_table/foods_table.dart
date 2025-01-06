import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/shopping_category_model.dart';

enum SortState { none, ascending, descending }

class FoodsTable extends StatefulWidget {
  @override
  _FoodsTableState createState() => _FoodsTableState();
}

class _FoodsTableState extends State<FoodsTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '선택', 'state': SortState.none},
    {'name': '연번', 'state': SortState.none},
    {'name': '카테고리', 'state': SortState.none},
    {'name': '식품명', 'state': SortState.none},
    {'name': '냉장고카테고리', 'state': SortState.none},
    {'name': '소비기한', 'state': SortState.none},
    {'name': '장보기카테고리', 'state': SortState.none},
    {'name': '변동', 'state': SortState.none}
  ];

  bool isEditing = false;
  int? selectedFoodIndex; // 수정할 아이템의 인덱스
  List<Map<String, dynamic>> userData = [];
  List<Map<String, dynamic>> originalData = [];
  List<int> selectedRows = [];

  final List<String> categoryOptions = [];
  final List<String> fridgeCategoryOptions = ['냉장', '냉동', '실온'];
  final List<String> shoppingCategoryOptions = [];
  List<Map<String, dynamic>> _tableData = [];

  String? _selectedCategory;
  String? _selectedFridgeCategory;
  String? _selectedShoppingListCategory;

  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _shelfLifeController = TextEditingController();
  final TextEditingController _expirationDateController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFoodsData();
    _loadDefaultFoodsCategories();
    _loadShoppingCategories();
    // addSampleFood();
  }

  Future<void> _loadFoodsData() async {
    final snapshot = await FirebaseFirestore.instance.collection('default_foods').get();

    List<Map<String, dynamic>> foods = [];

    snapshot.docs.forEach((doc) {
      final food = FoodsModel.fromFirestore(doc);

      foods.add({
        'documentId': doc.id,
        '연번': foods.length + 1, // 연번은 자동으로 증가하도록 설정
        '카테고리': food.defaultCategory, // Firestore의 카테고리를 사용
        '식품명': food.foodsName, // 각 itemName을 출력
        '냉장고카테고리': food.defaultFridgeCategory,
        '장보기카테고리': food.shoppingListCategory,
        '소비기한': food.shelfLife,
      });
      setState(() {
        userData = foods;
        originalData = List.from(foods);
      });
    });
  }

  Future<void> _loadDefaultFoodsCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('default_foods').get();

    final categories = snapshot.docs
        .map((doc) => doc.data()['defaultCategory'] as String?)
        .where((category) =>
            category != null && category.isNotEmpty) // null과 빈 값 필터링
        .cast<String>() // String으로 타입 캐스팅
        .toSet() // 중복 제거
        .toList(); // 리스트로 변환

    setState(() {
      categoryOptions.clear();
      categoryOptions.addAll(categories);
    });
  }

  Future<void> _loadShoppingCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_categories')
        .get();
    final categories = snapshot.docs.map((doc) {
      return ShoppingCategory.fromFirestore(doc);
    }).toList();

    setState(() {
      shoppingCategoryOptions.clear();
      shoppingCategoryOptions
          .addAll(categories.map((category) => category.categoryName).toList());
    });
  }

  void _addFood(String categoryName, Map<String, dynamic> newItem) async {
    final snapshot = FirebaseFirestore.instance.collection('foods');

    try {
      await snapshot.add({
        'foodsName': _foodNameController.text,
        'defaultCategory': _selectedCategory,
        'defaultFridgeCategory': _selectedFridgeCategory,
        'shoppingListCategory': _selectedShoppingListCategory,
        // 'expirationDate': _expirationDateController.text,
        'shelfLife': _shelfLifeController.text,
      });
    } catch (e) {
      print('Firestore에 저장하는 중 오류가 발생했습니다: $e');
    }
  }

  void _editFood(int index) {
    final selectedFood = userData[index];

    setState(() {
      _foodNameController.text = selectedFood['식품명'] ?? '';
      _selectedCategory = selectedFood['카테고리'] ?? '';
      _selectedFridgeCategory = selectedFood['냉장고카테고리'] ?? '';
      _selectedShoppingListCategory = selectedFood['장보기카테고리'] ?? '';
      _shelfLifeController.text = selectedFood['소비기한'].toString();
    });
    isEditing = true;
    selectedFoodIndex = index;
  }

  void _updateFood(int index) async {
    final selectedFood = userData[index];

    final foodName = _foodNameController.text;
    final category = _selectedCategory ?? selectedFood['카테고리'];
    final fridgeCategory = _selectedFridgeCategory ?? selectedFood['냉장고카테고리'];
    final shoppingListCategory =
        _selectedShoppingListCategory ?? selectedFood['장보기카테고리'];
    final shelfLife =
        int.tryParse(_shelfLifeController.text) ?? selectedFood['소비기한'];

    try {
      if (selectedFood.containsKey('documentId')) {
        final docRef = FirebaseFirestore.instance
            .collection('foods')
            .doc(selectedFood['documentId']); // 각 음식의 문서 ID

        await docRef.update({
          'foodsName': foodName,
          'defaultCategory': category,
          'defaultFridgeCategory': fridgeCategory,
          'shoppingListCategory': shoppingListCategory,
          'shelfLife': shelfLife,
          // 'expirationDate': expirationDate,
        });

        setState(() {
          userData[index] = {
            ...selectedFood,
            '식품명': foodName,
            '카테고리': category,
            '냉장고카테고리': fridgeCategory,
            '장보기카테고리': shoppingListCategory,
            '소비기한': shelfLife,
          };
        });
      } else {
        print('문서 ID가 없습니다. 업데이트할 수 없습니다.');
      }
    } catch (e) {
      print('Firestore에 데이터를 업데이트하는 중 오류가 발생했습니다: $e');
    }
  }

  // 체크박스를 사용해 선택한 행 삭제
  void _deleteSelectedRows(int index) async {
    final selectedFood = userData[index];

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
      },
    );

    if (shouldDelete == true) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('foods')
            .doc(selectedFood['documentId']);

        await snapshot.delete(); // 문서 삭제

        setState(() {
          userData.removeAt(index); // 로컬 상태에서도 데이터 삭제
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('선택한 항목이 삭제되었습니다.')),
        );
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
      for (var column in columns) {
        if (column['name'] == columnName) {
          column['state'] = newSortState;
        } else {
          column['state'] = SortState.none;
        }
      }

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
    await _loadFoodsData();
    setState(() {}); // 화면을 새로고침
  }

  void _clearFields() {
    _foodNameController.clear();
    _shelfLifeController.clear();
    // _expirationDateController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedFridgeCategory = null;
      _selectedShoppingListCategory = null;
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
          child: Column(
            children: [
              // 제목이 있는 행
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40), // 체크박스 열 크기
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(120),
                  3: FixedColumnWidth(100),
                  4: FixedColumnWidth(120),
                  5: FixedColumnWidth(80),
                  6: FixedColumnWidth(180),
                  7: FixedColumnWidth(80),
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
                                  child: Text(column['name'],
                                      style: TextStyle(color: theme.colorScheme.onSurface)),
                                )
                              : GestureDetector(
                                  onTap: () =>
                                      _sortBy(column['name'], column['state']),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(column['name'],
                                            style: TextStyle(color: theme.colorScheme.onSurface)),
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

              // 입력 필드들이 들어간 행
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(120),
                  3: FixedColumnWidth(100),
                  4: FixedColumnWidth(120),
                  5: FixedColumnWidth(80),
                  // 6: FixedColumnWidth(80),
                  6: FixedColumnWidth(180),
                  7: FixedColumnWidth(100),
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
                          child: Center(child: Text('no',
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          items: categoryOptions.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            hintText: '카테고리',
                            hintStyle: TextStyle(
                              fontSize: 12, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            contentPadding:
                                EdgeInsets.only(bottom: 13, left: 20),
                          ),
                          style: theme.textTheme.bodyMedium,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      TableCell(
                        child: TextField(
                          controller: _foodNameController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: '식품명',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            suffixIcon: _foodNameController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _foodNameController
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedFridgeCategory,
                          onChanged: (value) {
                            setState(() {
                              _selectedFridgeCategory = value;
                            });
                          },
                          items: fridgeCategoryOptions.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category,
                                  style: TextStyle(color: theme.colorScheme.onSurface)),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            hintText: '냉장고 선택',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            contentPadding:
                                EdgeInsets.only(bottom: 13, left: 20),
                          ),

                          style: theme.textTheme.bodyMedium,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      TableCell(
                        child: TextField(
                          controller: _shelfLifeController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: '소비기한',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            suffixIcon: _shelfLifeController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        _shelfLifeController
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
                        child: DropdownButtonFormField<String>(
                          value: _selectedShoppingListCategory,
                          onChanged: (value) {
                            setState(() {
                              _selectedShoppingListCategory = value;
                            });
                          },
                          items: shoppingCategoryOptions.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category,
                                  style: TextStyle(color: theme.colorScheme.onSurface)),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            hintText: '장보기 선택',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            contentPadding:
                                EdgeInsets.only(bottom: 13, left: 20),
                          ),
                          style: theme.textTheme.bodyMedium,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                              onPressed: () {
                                if (isEditing) {
                                  if (selectedFoodIndex != null) {
                                    _updateFood(selectedFoodIndex!);
                                  }
                                } else {
                                  Map<String, dynamic> newItem = {
                                    'itemName': _foodNameController.text,
                                    'defaultFridgeCategory':
                                        _selectedFridgeCategory,
                                    'shoppingListCategory':
                                        _selectedShoppingListCategory,
                                    'shelfLife': int.tryParse(
                                        _shelfLifeController.text), // 소비기한 추가
                                    // 'expirationDate': int.tryParse(
                                    //     _expirationDateController
                                    //         .text), // 유통기한 추가
                                    'isDisabled': false, // 기본값 설정
                                  };
                                  // _selectedCategory가 null일 수 있으므로 체크 후 호출
                                  if (_selectedCategory != null) {
                                    _addFood(_selectedCategory!, newItem);
                                  } else {
                                    print('카테고리를 선택하세요.');
                                  }
                                }
                                setState(() {
                                  _clearFields();
                                  _refreshTable();
                                });
                              },
                              iconTitle: Icons.add,
                              buttonTitle: '추가'),
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
                  2: FixedColumnWidth(120),
                  3: FixedColumnWidth(100),
                  4: FixedColumnWidth(120),
                  5: FixedColumnWidth(80),
                  // 6: FixedColumnWidth(80),
                  6: FixedColumnWidth(180),
                  7: FixedColumnWidth(100),
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
                                  Center(child: Text(row['연번'].toString(),
                                      style: TextStyle(color: theme.colorScheme.onSurface))))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['카테고리'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['식품명'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['냉장고카테고리'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['소비기한'].toString(),
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      // TableCell(
                      //     verticalAlignment: TableCellVerticalAlignment.middle,
                      //     child: Center(child: Text(row['유통기한'].toString()))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['장보기카테고리'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
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
                iconTitle: Icons.delete,
                buttonTitle: '선택한 항목 삭제',
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
