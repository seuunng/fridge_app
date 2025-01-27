import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/basic_elevated_button.dart';
import 'package:food_for_later_new/components/custom_dropdown.dart';
import 'package:food_for_later_new/models/preferred_food_model.dart';
import 'package:food_for_later_new/services/preferred_foods_service.dart';

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
    {'name': '제외 키워드 카테고리', 'state': SortState.none},
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
  final TextEditingController _categoryController = TextEditingController();

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
                    '제외 키워드 카테고리': category,
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
    await PreferredFoodsService.addDefaultPreferredCategories(
      context,
      _loadFoodsData,
    );
  }

  Future<void> _addCategory(String category) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          .get();

      bool categoryExists = false;

      // 카테고리가 이미 존재하는지 확인
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('category')) {
          Map<String, dynamic> categoryMap =
              Map<String, dynamic>.from(data['category']);
          if (categoryMap.containsKey(category)) {
            categoryExists = true;
            break;
          }
        }
      }

      // 카테고리가 없으면 Firestore에 추가
      if (!categoryExists) {
        await FirebaseFirestore.instance
            .collection('default_prefered_foods_categories')
            .add({
          'category': {category: []},
          'isDefault': true,
        });
        print('✅ 새 카테고리 Firestore에 추가 완료: $category');
      }

      // 로컬 상태 업데이트
      setState(() {
        categoryOptions.add(category);
        _categoryController.clear();
      });
    } catch (e) {
      print('❌ 새 카테고리 추가 중 오류 발생: $e');
    }
  }

  void _editFood(int index) {
    setState(() {
      Map<String, dynamic> selectedFood = userData[index];
      _foodNameController.text = selectedFood['식품명'];
      _selectedCategory = selectedFood['제외 키워드 카테고리'];

      isEditing = true;
      selectedFoodIndex = index;
    });
  }

  Future<void> _addFoodToCategory(String category, String foodName) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('category') &&
            data['category'] is Map<String, dynamic>) {
          Map<String, dynamic> categoryMap =
              Map<String, dynamic>.from(data['category']);
          if (categoryMap.containsKey(category)) {
            List<String> foodList = List<String>.from(categoryMap[category]);

            if (!foodList.contains(foodName)) {
              foodList.add(foodName);

              // Firestore 업데이트
              categoryMap[category] = foodList;
              await doc.reference.update({'category': categoryMap});

              print('✅ $category 카테고리에 $foodName 추가 완료');
              await _loadFoodsData(); // 데이터 다시 불러오기
            } else {
              print('⚠️ 이미 해당 식품이 카테고리에 존재합니다.');
            }
            return; // 작업 완료 후 함수 종료
          }
        }
      }

      print('⚠️ 카테고리를 찾을 수 없습니다.');
    } catch (e) {
      print('❌ 식품 추가 중 오류 발생: $e');
    }
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

        if (data.containsKey('category') &&
            data['category'] is Map<String, dynamic>) {
          Map<String, dynamic> categoryMap =
              Map<String, dynamic>.from(data['category']);
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

          if (data.containsKey('category') &&
              data['category'] is Map<String, dynamic>) {
            Map<String, dynamic> categoryMap =
                Map<String, dynamic>.from(data['category']);

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

  Future<void> _deleteCategory(String category) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('default_prefered_foods_categories')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        if (data.containsKey('category') &&
            data['category'] is Map<String, dynamic>) {
          Map<String, dynamic> categoryMap =
              Map<String, dynamic>.from(data['category']);

          if (categoryMap.containsKey(category)) {
            categoryMap.remove(category); // 카테고리 삭제

            // Firestore 업데이트
            if (categoryMap.isEmpty) {
              await doc.reference.delete(); // 문서 자체를 삭제
            } else {
              await doc.reference.update({'category': categoryMap}); // 문서 업데이트
            }

            print('✅ 카테고리 삭제 완료: $category');
            await _loadFoodsData(); // UI 업데이트
            return;
          }
        }
      }

      print('⚠️ 삭제할 카테고리를 찾을 수 없습니다.');
    } catch (e) {
      print('❌ 카테고리 삭제 중 오류 발생: $e');
    }
  }

  void _sortBy(String columnName, SortState currentState) {
    SortState newSortState;

    // 현재 상태를 기준으로 새 상태 결정
    if (currentState == SortState.none) {
      newSortState = SortState.ascending;
    } else if (currentState == SortState.ascending) {
      newSortState = SortState.descending;
    } else {
      newSortState = SortState.none;
    }

    setState(() {
      // 선택한 열의 정렬 상태 업데이트
      for (var column in columns) {
        if (column['name'] == columnName) {
          column['state'] = newSortState; // 정렬 상태 업데이트
        } else {
          column['state'] = SortState.none; // 다른 열은 정렬 상태 초기화
        }
      }

      // 정렬 로직
      if (newSortState == SortState.none) {
        userData = List.from(originalData); // 원본 데이터로 복원
      } else {
        userData.sort((a, b) {
          var aValue = a[columnName] ?? '';
          var bValue = b[columnName] ?? '';

          int result = aValue.toString().compareTo(bValue.toString());
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
                  horizontalInside:
                      BorderSide(width: 1, color: theme.colorScheme.onSurface),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(250),
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
                                  width: 1,
                                  color: theme
                                      .colorScheme.onSurface), // 셀 아래 테두리 추가
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
                                            column['state'] ==
                                                    SortState.ascending
                                                ? Icons.arrow_upward
                                                : column['state'] ==
                                                        SortState.descending
                                                    ? Icons.arrow_downward
                                                    : Icons.sort,
                                            size: 12,
                                            color: theme.colorScheme.onSurface),
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
                  horizontalInside:
                      BorderSide(width: 1, color: theme.colorScheme.onSurface),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(250),
                  3: FixedColumnWidth(120),
                  4: FixedColumnWidth(100),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            width: 1,
                            color: theme.colorScheme.onSurface), // 셀 아래 테두리 추가
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
                        child: CustomDropdown(
                          title: '제외 키워드 카테고리',
                          items: categoryOptions,
                          selectedItem: _selectedCategory ?? '',
                          onItemChanged: (value) {
                              setState(() {
                                _selectedCategory = value;
                              });
                          },
                          onItemDeleted: (item) async {
                            await _deleteCategory(item); // Function to delete the category
                            setState(() {
                              categoryOptions
                                  .remove(item); // Update UI after deletion
                            });
                          },
                          onAddNewItem: () {
                            _showAddCategoryDialog();
                          },
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
                                _addFoodToCategory(_selectedCategory!,
                                    _foodNameController.text);
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
                  horizontalInside:
                      BorderSide(width: 1, color: theme.colorScheme.onSurface),
                ),
                columnWidths: const {
                  0: FixedColumnWidth(40),
                  1: FixedColumnWidth(40),
                  2: FixedColumnWidth(250),
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
                              child: Text(row['제외 키워드 카테고리'],
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
                    String category = selectedFood['제외 키워드 카테고리'];
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

  void _showAddCategoryDialog() {
    final theme = Theme.of(context);
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '새 카테고리 추가',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(hintText: '카테고리 이름 입력'),
            style: TextStyle(color: theme.chipTheme.labelStyle!.color),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.isNotEmpty) {
                  await _addCategory(categoryController.text);
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                }
              },
              child: Text('추가'),
            ),
          ],
        );
      },
    );
  }
}
