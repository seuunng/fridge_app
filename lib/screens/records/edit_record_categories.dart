import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/services/record_category_service.dart';

class EditRecordCategories extends StatefulWidget {
  @override
  _EditRecordCategoriesState createState() => _EditRecordCategoriesState();
}

class _EditRecordCategoriesState extends State<EditRecordCategories> {
  List<Map<String, dynamic>> userData = [];
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final TextEditingController _recordCategoryController =
      TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  Color _selectedColor = Colors.grey[300]!; // 기본 색상
  List<String> units = [];
  String userRole = '';
  List<Map<String, dynamic>> recentlyDeletedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories(); // 카테고리 데이터를 로
    _loadUserRole();
  }

  void _loadUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? 'user'; // 기본값은 'user'
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }

  // Firestore에서 카테고리 데이터를 로드하는 함수
  void _loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('record_categories')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('order')  // 순서대로 정렬
          .get();

      if (snapshot.docs.isEmpty) {
        // 카테고리가 없으면 기본 카테고리 생성
        await _createDefaultCategories();
      } else {
        // Firestore에서 데이터 가져오기
        final categories = snapshot.docs.map((doc) {
          final data = doc.data();
          final colorString = data['color'] ?? '#BDBDBD'; // 기본 회색으로 설정
          return {
            'id': doc.id, // Firestore 문서 ID 저장
            '기록 카테고리': data['zone'],
            '분류': List<String>.from(data['units']),
            '색상': Color(int.tryParse(colorString.replaceFirst('#', '0xff')) ??
                0xFFBDBDBD),
          };
        }).toList();

        setState(() {
          userData = categories;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 데이터를 로드하는데 실패했습니다.')),
      );
    }
  }

  Future<void> _createDefaultCategories() async {
    await RecordCategoryService.createDefaultCategories(
        userId, context, _loadCategories);
  }

  // 데이터 추가 함수
  void _addOrEditCategory({int? index}) {
    if (index != null) {
      // 수정 모드
      _recordCategoryController.text = userData[index]['기록 카테고리'];
      units = List<String>.from(userData[index]['분류']);
      _selectedColor = userData[index]['색상'] ?? Colors.grey[300];
    } else {
      // 추가 모드 초기화
      _recordCategoryController.clear();
      units = [];
      _selectedColor = Colors.grey[300]!; // 초기 색상
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                index == null ? '카테고리 추가' : '카테고리 수정',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _recordCategoryController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: '기록 카테고리',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
                        vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 8.0,
                    children: [
                      for (var color in [
                        Color(0xFFFFC1CC), // 핑크 블러쉬
                        Color(0xFFFFE0B2), // 피치 오렌지
                        Color(0xFFFFF9C4), // 바닐라 옐로우
                        Color(0xFFDCEDC8), // 라이트 그린
                        Color(0xFFB2EBF2), // 민트 블루
                        Color(0xFFBBDEFB), // 스카이 블루
                        Color(0xFFD1C4E9), // 라벤더 퍼플
                      ])
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == color
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          _showColorPickerDialog(context, (color) {
                            setState(() {
                              _selectedColor = color; // 선택된 색상으로 업데이트
                            });
                          });
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                            // border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: Icon(Icons.add,
                              size: 16, color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 0.0,
                    children: units.map((unit) {
                      return Chip(
                        label: Text(
                          unit,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12, // 강조를 위해 굵게 설정
                          ),
                        ),
                        labelPadding: EdgeInsets.symmetric(
                          horizontal: 4.0, // 라벨(텍스트)과 좌우 경계 사이의 여백
                          vertical: 0.0, // 라벨(텍스트)과 상하 경계 사이의 여백
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 1.0, vertical: 5.0),
                        deleteIcon: Transform.translate(
                          offset: Offset(-4, 0), // x, y 좌표로 이동, x는 좌우, y는 상하
                          child: Icon(Icons.close,
                              size: 16.0, // 삭제 아이콘 크기
                              color: theme.colorScheme.onSurface),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          side: BorderSide(
                            color: theme.chipTheme.labelStyle?.color ??
                                Colors.white, // 테두리 색상 빨간색으로 변경
                            width: 1, // 테두리 두께 조절
                          ),
                        ),
                        onDeleted: () {
                          setState(() {
                            units.remove(unit);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  Container(
                    child: TextField(
                      controller: _unitController,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: '분류 추가',
                        labelStyle:
                            TextStyle(color: theme.colorScheme.onSurface),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
                          vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            String newUnit = _unitController.text.trim();
                            if (newUnit.isEmpty) {
                              // 빈 문자열인 경우 추가하지 않음
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('빈 분류는 추가할 수 없습니다.'),
                                ),
                              );
                            } else if (units.contains(newUnit)) {
                              // 중복된 이름인 경우 추가하지 않음
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('이미 존재하는 분류입니다.'),
                                ),
                              );
                            } else if (units.length >= 5) {
                              // 분류의 개수가 5개 이상인 경우 추가하지 않음
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('최대 5개의 분류만 추가할 수 있습니다.'),
                                ),
                              );
                            } else {
                              // 새로운 분류 추가
                              units.add(newUnit);
                              _unitController.clear();
                            } // 입력 후 텍스트필드 초기화
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _unitController.clear(); // 텍스트 필드 초기화
                    Navigator.of(context).pop(); // 팝업 닫기
                  },
                  child: Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    if (_recordCategoryController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('카테고리 이름을 입력해주세요.')),
                      );
                    } else if (units.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('최소 하나의 분류를 추가해주세요.')),
                      );
                    } else {
                      await _saveCategory(index: index);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(index == null ? '추가' : '수정'),
                  // onPressed: () {
                  //   setState(() {
                  //     if (index == null) {
                  //       // 추가 모드
                  //       userData.add({
                  //         '연번': userData.length + 1,
                  //         '기록 카테고리': _recordCategoryController.text,
                  //         '분류': List.from(units),
                  //         '색상': _selectedColor,
                  //       });
                  //     } else {
                  //       // 수정 모드
                  //       userData[index] = {
                  //         '연번': userData[index]['연번'],
                  //         '기록 카테고리': _recordCategoryController.text,
                  //         '분류': List.from(units),
                  //         '색상': _selectedColor,
                  //       };
                  //     }
                  //   });
                  //   _recordCategoryController.clear();
                  //   _unitController.clear();
                  //   Navigator.of(context).pop();
                  // },
                  // child: Text(index == null ? '추가' : '수정'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showColorPickerDialog(
      BuildContext context, Function(Color) onColorPicked) {
    final theme = Theme.of(context);
    Color pickedColor = _selectedColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '색상을 선택해주세요!',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickedColor,
              onColorChanged: (Color color) {
                pickedColor = color;
              },
              paletteType: PaletteType.hsv, // 기본 팔레트
              showLabel: false,
              pickerAreaHeightPercent: 0.8,
              labelTextStyle: TextStyle(
                color: theme.colorScheme.onSurface, // 레이블 텍스트 색상 적용
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  onColorPicked(pickedColor); // 선택된 색상 콜백 호출
                  Navigator.of(context).pop();
                });
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // Firestore에 카테고리를 저장하거나 수정하는 함수
  Future<void> _saveCategory({int? index}) async {
    final order = index != null ? userData[index]['order'] : userData.length;
    // 입력 검증: 카테고리 이름과 분류 리스트가 비어있으면 저장 중단
    if (_recordCategoryController.text.isEmpty) {
      return; // 저장 중단
    }

    if (units.isEmpty) {
      return; // 저장 중단
    }

    final category = {
      'zone': _recordCategoryController.text,
      'units': units,
      'color': '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
      'userId': userId,
      'order': order,  // 순서 정보 추가
      'createdAt': FieldValue.serverTimestamp(), // 생성 시간 추가
      'isDeleted': false,
      'isDefault': false
    };

    String? previousZone;
    List<String>? previousUnits;

    try {
      if (index == null) {
        // 새로운 카테고리를 Firestore에 추가
        await FirebaseFirestore.instance
            .collection('record_categories')
            .add(category);
      } else {
        // 기존 카테고리를 Firestore에서 수정
        previousZone = userData[index]['기록 카테고리'];
        previousUnits = List<String>.from(userData[index]['분류']);

        // 기존 카테고리를 Firestore에서 수정
        await FirebaseFirestore.instance
            .collection('record_categories')
            .doc(userData[index]['id'])
            .update(category);

        await _updateRecordsWithNewCategory(previousZone, previousUnits);
      }

      _loadCategories(); // 업데이트된 카테고리 목록을 다시 로드
      Navigator.of(context).pop(); // 다이얼로그 닫기
    } catch (e) {
      print('Error saving category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 저장에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _updateRecordsWithNewCategory(
      String? previousZone, List<String>? previousUnits) async {
    if (previousZone == null || previousUnits == null) return;

    try {
      QuerySnapshot recordsSnapshot = await FirebaseFirestore.instance
          .collection('record')
          .where('zone', isEqualTo: previousZone)
          .get();

      for (var recordDoc in recordsSnapshot.docs) {
        Map<String, dynamic> recordData =
            recordDoc.data() as Map<String, dynamic>;

        // 기록의 records 배열에서 이전 unit을 사용하고 있는지 확인
        List<dynamic> updatedRecords =
            (recordData['records'] as List<dynamic>).map((record) {
          if (previousUnits.contains(record['unit'])) {
            // unit을 새로운 값으로 변경할 수 있는 로직 필요
            // 예시로 이전 unit을 새로운 값으로 변경
            record['unit'] = record['unit']; // 여기에 수정된 unit 로직을 추가할 수 있음
          }
          return record;
        }).toList();

        // Firestore에 업데이트된 데이터 반영
        await FirebaseFirestore.instance
            .collection('record')
            .doc(recordDoc.id)
            .update({
          'zone': _recordCategoryController.text, // 수정된 카테고리로 변경
          'records': updatedRecords,
        });
      }
    } catch (e) {
      print('Error updating records: $e');
    }
  }

  Future<void> _deleteCategoryById(String categoryId) async {
    try {
      await FirebaseFirestore.instance
          .collection('record_categories')
          .doc(categoryId)
          .update({'isDeleted': true});
    } catch (e) {
      print('Error deleting category: $e');
      throw e; // 삭제 중 문제가 발생하면 예외 던짐
    }
  }

  void _restoreDeletedCategory() async {
    if (recentlyDeletedCategories.isNotEmpty) {
      final lastDeletedCategory =
          recentlyDeletedCategories.last; // 마지막 삭제된 카테고리 가져오기
      try {
        await FirebaseFirestore.instance
            .collection('record_categories')
            .doc(lastDeletedCategory['id'])
            .update({'isDeleted': false}); // Firestore에서 복원

        // 로컬 상태에 복원된 카테고리 추가
        setState(() {
          // final colorString = lastDeletedCategory['색상'] ?? '#BDBDBD';
          userData.add({
            'id': lastDeletedCategory['id'],
            '기록 카테고리': lastDeletedCategory['기록 카테고리'],
            '분류': lastDeletedCategory['분류'],
            '색상': lastDeletedCategory['색상'],
            'isDeleted': false,
          });
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${lastDeletedCategory['기록 카테고리']} 카테고리가 복원되었습니다.')),
        );
      } catch (e) {
        print('Error restoring category: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카테고리 복원에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }
  Future<void> _updateCategoryOrderInFirestore() async {
    for (int i = 0; i < userData.length; i++) {
      final categoryId = userData[i]['id'];
      final newOrder = i;

      await FirebaseFirestore.instance.collection('record_categories').doc(categoryId).update({
        'order': newOrder,
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('기록 카테고리 관리'),
      ),
      body: ReorderableListView(
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) {
              newIndex -= 1; // 드래그된 아이템의 올바른 위치를 맞춤
            }
            final movedItem = userData.removeAt(oldIndex);
            userData.insert(newIndex, movedItem);
          });
          _updateCategoryOrderInFirestore();
        },
        children: [
          for (int index = 0; index < userData.length; index++)
            // Dismissible(
            //       key: ValueKey(userData[index]['id']),  // 각 항목에 고유한 키를 부여
            //       direction: DismissDirection.endToStart, // 오른쪽에서 왼쪽으로만 스와이프 가능
            //       onDismissed: (direction) async {
            //         final categoryToDelete = userData[index];
            //
            //         recentlyDeletedCategories.add(categoryToDelete);
            //         print('recentlyDeletedCategories $recentlyDeletedCategories');
            //         setState(() {
            //           userData.removeAt(index);
            //         });
            //
            //         try {
            //           await _deleteCategoryById(categoryToDelete['id']);
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(
            //               content: Text('${categoryToDelete['기록 카테고리']}가 삭제되었습니다.'),
            //               action: SnackBarAction(
            //                 label: '복원',
            //                 onPressed: _restoreDeletedCategory,
            //               ),
            //             ),
            //           );
            //         } catch (e) {
            //           // 에러 발생 시 삭제를 취소하고 다시 로컬 상태에 항목 추가
            //           setState(() {
            //             userData.insert(index, categoryToDelete);
            //           });
            //           ScaffoldMessenger.of(context).showSnackBar(
            //             SnackBar(content: Text('카테고리 삭제에 실패했습니다. 다시 시도해주세요.')),
            //           );
            //         }
            //       },
            //       background: Container(
            //         color: Colors.redAccent,
            //         alignment: Alignment.centerRight,
            //         padding: EdgeInsets.symmetric(horizontal: 20),
            //         child: Icon(Icons.delete, color: Colors.white),
            //       ),
            //       child:
            Card(
              key: ValueKey(userData[index]['id']),
              color: userData[index]['색상'] ?? Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: Colors.grey),
                ),
                title: Text(
                  userData[index]['기록 카테고리'],
                  style: TextStyle(
                    fontSize: 18.0, // 제목 글씨 크기 키우기
                    fontWeight: FontWeight.bold, // 제목 글씨 굵게
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
                subtitle: Text(
                  '${userData[index]['분류'].join(', ')}',
                  style: TextStyle(
                    fontSize: 18.0, // 분류 글씨 크기 키우기
                    color: theme.colorScheme.onSecondary,
                  ),
                ),
                trailing: userData[index]['isDeleted'] == true
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: theme.colorScheme.onSecondary,
                            ),
                            onPressed: () => _addOrEditCategory(index: index),
                          ),
                          IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: theme.colorScheme.onSecondary,
                              ),
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(index)),
                        ],
                      ),
              ),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'record_category_add_button',
        onPressed: () => _addOrEditCategory(),
        child: Icon(Icons.add),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // 버튼의 모서리를 둥글게
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
        children: [
          if (userRole != 'admin' && userRole != 'paid_user')
            SafeArea(
              child: BannerAdWidget(),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(int index) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '삭제 확인',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            '${userData[index]['기록 카테고리']}를 삭제하시겠습니까?',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                final categoryToDelete = userData[index];
                recentlyDeletedCategories.add(categoryToDelete);
                setState(() {
                  userData.removeAt(index);
                });

                await _deleteCategoryById(categoryToDelete['id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${categoryToDelete['기록 카테고리']}가 삭제되었습니다.'),
                    action: SnackBarAction(
                      label: '복원',
                      onPressed: _restoreDeletedCategory,
                    ),
                  ),
                );
              },
              child: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// 정렬 상태 enum
enum SortState { none, ascending, descending }
