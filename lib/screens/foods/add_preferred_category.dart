import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class AddPreferredCategory extends StatefulWidget {
  final String? categoryName;
  final String? sourcePage;

  AddPreferredCategory({this.categoryName, this.sourcePage});

  @override
  _AddPreferredCategoryState createState() => _AddPreferredCategoryState();
}

class _AddPreferredCategoryState extends State<AddPreferredCategory> {
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController itemController = TextEditingController();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  List<String> items = [];
  bool isLoading = true;
  int? editingIndex; // 현재 편집 중인 항목의 인덱스

  @override
  void initState() {
    super.initState();

      categoryController.text = widget.categoryName ?? "";
      if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
        categoryController.text = widget.categoryName!;
        _loadCategoryItems(); // Firestore에서 데이터 로드
      } else {
        categoryController.text = "";
        setState(() {
          isLoading = false; // 카테고리 이름이 없을 경우 로딩 상태 해제
        });
      }
  }

  Future<void> _loadCategoryItems() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docData = snapshot.docs.first.data();

        final Map<String, dynamic>? categories =
            docData['category'] as Map<String, dynamic>?;

        if (categories != null && widget.categoryName != null) {
          final List<dynamic>? categoryItems = categories[widget.categoryName];

          if (categoryItems != null) {
            setState(() {
              items = List<String>.from(categoryItems); // 기존 아이템 로드
            });
          }
        }
      }
      setState(() {
        isLoading = false; // 로딩 상태 해제
      });
    } catch (e) {
      print('Error loading items: $e');
    } finally {
      setState(() {
        isLoading = false; // 로딩 상태 해제
      });
    }
  }

  void _addItem() {
    if (itemController.text.trim().isNotEmpty) {
      setState(() {
        items.add(itemController.text.trim());
        itemController.clear();
      });
    }
  }

  void _saveCategory() async {
    final newCategoryName = categoryController.text.trim();

    if (newCategoryName.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 이름과 아이템을 추가해주세요.'),
          duration: Duration(seconds: 2),),
      );
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: newCategoryName) // 카테고리명이 같은 문서 조회
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docRef = snapshot.docs.first.reference;
        final existingItems = List<String>.from(snapshot.docs.first.data()['items'] ?? []);

        // 기존 아이템 리스트에 새 아이템 추가 (중복 방지)
        final updatedItems = {...existingItems, ...items}.toList();

        await docRef.update({'items': updatedItems});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기존 카테고리에 아이템이 추가되었습니다.'),
            duration: Duration(seconds: 2),),
        );
      } else {
        await FirebaseFirestore.instance.collection('preferred_foods_categories').add({
          'userId': userId,
          'category': {newCategoryName: items},
          'isDefault': false,
        });
      }

      Navigator.pop(context, true);
    } catch (e) {
      print('Error saving category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 저장 중 오류 발생.'),
          duration: Duration(seconds: 2),),
      );
    }
  }

  void _deleteCategory() async {
    final categoryName = categoryController.text.trim();

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제할 카테고리를 입력해주세요.'),
          duration: Duration(seconds: 2),),
      );
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .where('category.$categoryName', isNotEqualTo: null)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docRef = snapshot.docs.first.reference;

        // 해당 카테고리를 삭제
        await docRef.update({
          'category.$categoryName': FieldValue.delete(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카테고리가 삭제되었습니다.'),
            duration: Duration(seconds: 2),),
        );

        // 상태 업데이트 및 초기화
        setState(() {
          categoryController.clear();
          items.clear();
        });

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('해당 카테고리가 존재하지 않습니다.')),
        );
      }
    } catch (e) {
      print('Error deleting category: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카테고리 삭제 중 오류가 발생했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('카테고리 추가'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteCategory, // 삭제 함수 연결
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // 로딩 상태 표시
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: '카테고리 이름',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: itemController,
                    decoration: InputDecoration(
                      labelText: '아이템 추가',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    onSubmitted: (_) => _addItem(),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        // 편집 모드인지 확인
                        if (editingIndex == index) {
                          final TextEditingController editController =
                              TextEditingController(text: items[index]);
                          return ListTile(
                            title: TextField(
                              controller: editController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                                style: TextStyle(color: theme.colorScheme.onSurface),
                              onSubmitted: (newValue) {
                                setState(() {
                                  if (newValue.trim().isNotEmpty) {
                                    items[index] = newValue.trim();
                                  }
                                  editingIndex = null; // 편집 모드 해제
                                });
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.check),
                              onPressed: () {
                                setState(() {
                                  if (editController.text.trim().isNotEmpty) {
                                    items[index] = editController.text.trim();
                                  }
                                  editingIndex = null; // 편집 모드 해제
                                });
                              },
                            ),
                          );
                        } else {
                          // 보기 모드
                          return ListTile(
                            title: Text(items[index]),
                            onTap: () {
                              setState(() {
                                editingIndex = index; // 편집 모드로 전환
                              });
                            },
                            trailing: IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  items.removeAt(index);
                                });
                              },
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: NavbarButton(
                buttonTitle: '제외 키워드에 저장',
                onPressed: _saveCategory,
              ),
            )
          ],
        ),
      ),
    );
  }
}
