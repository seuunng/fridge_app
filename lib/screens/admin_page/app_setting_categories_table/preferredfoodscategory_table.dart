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

  Future<void> _loadFoodsData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          .get();

      Map<String, List<String>> tempItemsByCategory = {};
      List<String> tempCategories = [];
      List<Map<String, dynamic>> tempUserData = [];

      // 🔹 Firestore에서 가져온 기본 카테고리 데이터 추가
      snapshot.docs.forEach((doc) {
        final data = doc.data();

        if (data.containsKey('category')) {
          Map<String, dynamic> categoryData = data['category'];

          categoryData.forEach((category, items) {
            if (items is List<dynamic>) {
              if (!tempCategories.contains(category)) {
                tempCategories.add(category);
              }
              if (!tempItemsByCategory.containsKey(category)) {
                tempItemsByCategory[category] = [];
              }

              for (var item in items) {
                if (!tempItemsByCategory[category]!.contains(item)) {
                  tempItemsByCategory[category]!.add(item);
                  tempUserData.add({
                    '연번': tempUserData.length + 1, // 연번 자동 증가
                    '선호식품 카테고리': category,
                    '식품명': item,
                  });
                }
              }
            }
          });
        }
      });

      setState(() {
        categoryOptions.clear();
        categoryOptions.addAll(tempCategories.toSet().toList());
        itemsByCategory.clear();
        itemsByCategory.addAll(tempItemsByCategory);
        userData = tempUserData;
        originalData = List.from(userData);
      });
    } catch (e) {
      print('❌ Firestore 데이터를 불러오는 중 오류 발생: $e');
    }
  }

  Future<void> _addDefaultPreferredCategories() async {
    print('_addDefaultPreferredCategories 실행');
    final newCategory = _selectedCategory;
    final newFood = _foodNameController.text.trim();

    if (newCategory == null || newCategory.isEmpty || newFood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리와 식품명을 입력해주세요.')),
      );
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          // .where('category', isEqualTo: newCategory)
          .get();

      bool categoryExists = false;
      DocumentReference? existingDocRef;

      print(querySnapshot.docs);

      for (var doc in querySnapshot.docs) {
        final docData = doc.data();

        print('categoryMap $docData');
        
        if (docData.containsKey('category')) {
          Map<String, dynamic> categoryMap =
              Map<String, dynamic>.from(docData['category']);

          print('categoryMap $categoryMap.containsKey(newCategory)');
          
          // 🔹 Firestore에서 newCategory가 존재하는지 확인
          if (categoryMap.containsKey(newCategory)) {
            categoryExists = true;
            existingDocRef = doc.reference;

            // 🔹 기존 카테고리 내부 리스트 가져오기
            List<String> existingFoods =
                List<String>.from(categoryMap[newCategory] ?? []);

            if (!existingFoods.contains(newFood)) {
              existingFoods.add(newFood);

              // 🔹 Firestore 업데이트 (기존 문서 내 리스트 업데이트)
              await existingDocRef
                  .update({'category.$newCategory': existingFoods});
            }

            break; // 🔹 카테고리를 찾으면 더 이상 반복하지 않음
          }
        }
      }

      if (!categoryExists) {
        // 🔹 Firestore에 새로운 카테고리 추가 (존재하지 않는 경우)
        await FirebaseFirestore.instance
            .collection('default_preferred_foods_categories')
            .add({
          'category': {
            newCategory: [newFood]
          },
          'isDefault': true,
        });
      }
      await _loadFoodsData();
      setState(() {});
      _foodNameController.clear();
      _selectedCategory = null;
    } catch (e) {
      print('❌ Firestore 저장 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다. 다시 시도해주세요.')),
      );
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
      final querySnapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          .get();

      bool found = false;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('category') && data['category'] is Map<String, dynamic>) {
          Map<String, dynamic> categoryMap = Map<String, dynamic>.from(data['category']);
          if (categoryMap.containsKey(category)) {
            found = true;

            List<String> foodList = List<String>.from(categoryMap[category]);

            if (foodList.contains(oldFoodName)) {
              // 🔹 기존 아이템(oldFoodName)을 업데이트
              int index = foodList.indexOf(oldFoodName);
              foodList[index] = updatedFoodName;

              // 🔹 Firestore 업데이트
              categoryMap[category] = foodList;
              await doc.reference.update({'category': categoryMap});
            }
          }
        }
      }

      await _loadFoodsData();

      setState(() {});
      if (!found) {
        print('⚠️ Firestore에서 해당 카테고리를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('❌ Firestore 아이템 삭제 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터 삭제 중 오류가 발생했습니다. 다시 시도해주세요.')),
      );
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
    if (shouldDelete) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('default_prefered_foods_categories')
            .get();

        bool found = false;

        for (var doc in querySnapshot.docs) {
          final data = doc.data();

          if (data.containsKey('category') && data['category'] is Map<String, dynamic>) {
            Map<String, dynamic> categoryMap = Map<String, dynamic>.from(data['category']);

            if (categoryMap.containsKey(category)) {
              found = true;

              List<String> foodList = List<String>.from(categoryMap[category]);

              if (foodList.contains(foodName)) {
                foodList.remove(foodName);

                if (foodList.isEmpty) {
                  categoryMap.remove(category);
                } else {
                  categoryMap[category] = foodList;
                }

                if (categoryMap.isEmpty) {
                  await doc.reference.delete();
                } else {
                  await doc.reference.update({'category': categoryMap});
                  print('✅ Firestore 문서 업데이트 완료 (아이템 삭제): ${doc.id}');
                }
              }
            }
          }
        }
        await _loadFoodsData();
        setState(() {});
        if (!found) {
          print('⚠️ Firestore에서 해당 카테고리를 찾을 수 없습니다.');
        }
      } catch (e) {
        print('❌ Firestore 아이템 삭제 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 삭제 중 오류가 발생했습니다. 다시 시도해주세요.')),
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
          column['name'] = newSortState;
        } else {
          column['name'] = SortState.none;
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
                                      style: TextStyle(
                                          color: theme.colorScheme.onSurface)),
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
                                            style: TextStyle(
                                                color: theme
                                                    .colorScheme.onSurface)),
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
                          child: Center(
                              child: Text('no',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)))),
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
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)),
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
                                _addDefaultPreferredCategories();
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
                              child: Center(
                                  child: Text(row['연번'].toString(),
                                      style: TextStyle(
                                          color:
                                              theme.colorScheme.onSurface))))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(
                              child: Text(row['선호식품 카테고리'],
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)))),
                      TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Center(
                              child: Text(row['식품명'],
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)))),
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
