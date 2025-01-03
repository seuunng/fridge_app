import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';

enum SortState { none, ascending, descending }

class PreferredfoodscategoryTable extends StatefulWidget {
  @override
  _PreferredfoodscategoryTableState createState() =>
      _PreferredfoodscategoryTableState();
}

class _PreferredfoodscategoryTableState
    extends State<PreferredfoodscategoryTable> {
  List<Map<String, dynamic>> columns = [
    {'name': '선택', 'state': SortState.none},
    {'name': '연번', 'state': SortState.none},
    {'name': '선호식품 카테고리', 'state': SortState.none},
    {'name': '식품명', 'state': SortState.none},
    {'name': '변동', 'state': SortState.none}
  ];

  bool isEditing = false;
  int? selectedFoodIndex; // 수정할 아이템의 인덱스
  List<Map<String, dynamic>> userData = [];
  List<Map<String, dynamic>> originalData = [];
  List<int> selectedRows = [];
  final List<String> categoryOptions = [];
  final Map<String, List<String>> itemsByCategory = {};

  String? _selectedCategory;

  final TextEditingController _foodNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFoodsData();
  }
  final defaultCategories = {
    '알러지': ['우유', '계란', '땅콩'],
    '유제품': ['우유', '치즈', '요거트'],
    '비건': ['육류', '해산물', '유제품', '계란', '꿀'],
    '무오신채': ['마늘', '양파', '부추', '파', '달래'],
    '설밀나튀': ['설탕', '밀가루', '튀김'],
  };
  Future<void> _loadFoodsData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories').get();

      if (snapshot.docs.isEmpty) {
        print('Firestore 데이터가 없습니다.');
        return; // 데이터가 없으면 메서드를 종료
      }

      Map<String, List<String>> tempItemsByCategory = {};
      List<String> tempCategories = [];

      // 문서 하나씩 처리
      snapshot.docs.forEach((doc) {
        final data = PreferredFoodModel.fromFirestore(doc.data());

        data.category.forEach((category, foodList) {
          tempCategories.add(category); // 카테고리 추가
          tempItemsByCategory[category] = foodList;

          for (var food in foodList) {
            userData.add({
              '연번': userData.length + 1, // 연번은 자동으로 증가하도록 설정
              '선호식품 카테고리': category, // Firestore의 카테고리를 사용
              '식품명': food,
            });
          }
        });
      });

      setState(() {
        categoryOptions.addAll(tempCategories.toSet().toList()); // 카테고리 목록 설정
        itemsByCategory.addAll(tempItemsByCategory); // 카테고리별 식품 목록 설정
        originalData = List.from(userData);
      });
    } catch (e) {
      print('Firestore 데이터를 불러오는 중 오류 발생: $e');
    }
  }

  Future<void> _addFood(String foodName) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .doc(); // 이 ID를 실제로 사용 중인 문서 ID로 변경

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<String> existingFoods =
            List<String>.from(data['category'][_selectedCategory] ?? []);

        existingFoods.add(foodName);

        await docRef.update({
          'category.${_selectedCategory}': existingFoods, // 선택된 카테고리 배열 업데이트
        });
      } else {
        await docRef.set({
          'category': {
            _selectedCategory: [foodName], // 새로운 카테고리 생성 후 배열 추가
          },
        });
      }

      // 입력 필드 초기화
      setState(() {
        _foodNameController.clear();
        _selectedCategory = null;
      });
    } catch (e) {
      print('Firestore에 저장하는 중 오류가 발생했습니다: $e');
    }
  }

  void _editFood(int index) {
    setState(() {
      Map<String, dynamic> selectedFood = userData[index];
      _foodNameController.text = selectedFood['식품명'];
      _selectedCategory = selectedFood['선호식품 카테고리'];

      isEditing = true;
      selectedFoodIndex = index;
    });
  }

  Future<void> _updateFoodInCategory(
      String category, String oldFoodName, String updatedFoodName) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .doc(); // 실제 문서 ID로 변경

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        List<String> existingFoods =
            List<String>.from(data['category'][category] ?? []);

        int foodIndex = existingFoods.indexOf(oldFoodName);
        if (foodIndex != -1) {
          existingFoods[foodIndex] = updatedFoodName;

          await docRef.update({
            'category.$category': existingFoods, // 선택된 카테고리 배열 업데이트
          });
        } else {
          print('해당 카테고리에서 식품명을 찾을 수 없습니다.');
        }
      } else {
        print('Firestore 문서를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('Firestore에 데이터를 업데이트하는 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _deleteFoodFromCategory(String category, String foodName) async {
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
        final docRef = FirebaseFirestore.instance
            .collection('preferred_foods_categories')
            .doc(); // 실제 문서 ID로 변경

        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          Map<String, dynamic> data =
              docSnapshot.data() as Map<String, dynamic>;
          List<String> existingFoods =
              List<String>.from(data['category'][category] ?? []);

          existingFoods.remove(foodName);

          await docRef.update({
            'category.$category': existingFoods, // 선택된 카테고리 배열 업데이트
          });
        } else {
          print('Firestore 문서를 찾을 수 없습니다.');
        }
      } catch (e) {
        print('Firestore에서 항목을 삭제하는 중 오류가 발생했습니다: $e');
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
        userData = List.from(originalData);
      } else {
        userData.sort((a, b) {
          int result = a[columnName].compareTo(b[columnName]);
          return newSortState == SortState.ascending ? result : -result;
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
          child: Column(
            children: [
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(180),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(100),
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
              Table(
                border: TableBorder(
                  horizontalInside: BorderSide(width: 1, color: Colors.black),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(180),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(100),
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
                              child: Text(category,
                                  style: TextStyle(color: theme.colorScheme.onSurface)),
                            );
                          }).toList(),
                          decoration: InputDecoration(
                            hintText: '선호식품 카테고리',
                            hintStyle: TextStyle(
                              fontSize: 14, // 글씨 크기 줄이기
                              color: Colors.grey, // 글씨 색상 회색으로
                            ),
                            contentPadding:
                                EdgeInsets.only(bottom: 13, left: 20),
                          ),
                          style: TextStyle(
                            fontSize: 14, // 선택된 값의 글씨 크기
                            color: Colors.black, // 선택된 값의 색상
                          ),
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      TableCell(
                        child: TextField(
                          controller: _foodNameController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
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
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                            onPressed: () {
                              if (isEditing && selectedFoodIndex != null) {
                                Map<String, dynamic> selectedFood =
                                    userData[selectedFoodIndex!];
                                String oldFoodName = selectedFood['식품명'];
                                String updatedFoodName =
                                    _foodNameController.text;

                                _updateFoodInCategory(_selectedCategory!,
                                    oldFoodName, updatedFoodName);
                              } else {
                                // 추가 모드일 때, 새 데이터를 추가
                                _addFood(_foodNameController.text);
                              }

                              // 필드 초기화 및 수정 모드 해제
                              setState(() {
                                _foodNameController.clear();
                                _selectedCategory = null;
                                isEditing = false;
                                selectedFoodIndex = null;
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
                  2: FixedColumnWidth(180),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(100),
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
                                selectedFoodIndex = index;
                              } else {
                                selectedRows.remove(index);
                                selectedFoodIndex = null;
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
                          child: Center(child: Text(row['선호식품 카테고리'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(child: Text(row['식품명'],
                              style: TextStyle(color: theme.colorScheme.onSurface)))),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: SizedBox(
                          width: 60, // 버튼의 너비를 설정
                          height: 30, // 버튼의 높이를 설정
                          child: BasicElevatedButton(
                            onPressed: () =>
                                _editFood(row['연번'] - 1), // 수정 버튼 클릭 시
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
                onPressed: () {
                  if (selectedFoodIndex != null) {
                    // 선택한 데이터를 가져옵니다.
                    Map<String, dynamic> selectedFood =
                        userData[selectedFoodIndex!];
                    String category = selectedFood['선호식품 카테고리'];
                    String foodName = selectedFood['식품명'];

                    // 선택한 카테고리와 식품명을 기반으로 삭제 수행
                    _deleteFoodFromCategory(category, foodName);
                    // UI 업데이트
                    setState(() {
                      userData.removeAt(selectedFoodIndex!);
                      selectedRows.remove(selectedFoodIndex); // 선택한 행 삭제
                      selectedFoodIndex = null; // 선택한 인덱스 초기화
                    });
                  }
                },
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
