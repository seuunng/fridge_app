import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/fridge_category_model.dart';
import 'package:food_for_later_new/models/shopping_category_model.dart';
import 'package:food_for_later_new/screens/admin_page/admin_main_page.dart';
import 'package:intl/intl.dart';

class FridgeItemDetails extends StatefulWidget {
  final String foodsName;
  final String foodsCategory;
  final String fridgeCategory;
  final String shoppingListCategory;
  final int consumptionDays;
  final String registrationDate;

  FridgeItemDetails({
    required this.foodsName,
    required this.foodsCategory,
    required this.fridgeCategory,
    required this.shoppingListCategory,
    required this.consumptionDays,
    required this.registrationDate,
  });

  @override
  _FridgeItemDetailsState createState() => _FridgeItemDetailsState();
}

class _FridgeItemDetailsState extends State<FridgeItemDetails> {
  List<FoodsModel> foodsCategories = [];
  FoodsModel? selectedFoodsCategory;

  List<FridgeCategory> fridgeCategories = [];
  FridgeCategory? selectedFridgeCategory;

  List<ShoppingCategory> shoppingListCategories = [];
  ShoppingCategory? selectedShoppingListCategory;

  Map<String, List<String>> itemsByCategory = {};

  int expirationDays = 1;
  int consumptionDays = 1;

  TextEditingController foodNameController = TextEditingController();
  TextEditingController dateController = TextEditingController(); // 등록일 컨트롤러

  DateTime currentDate = DateTime.now();
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('yyyy-MM-dd').format(currentDate);
    _loadFoodsCategoriesFromFirestore();
    _loadFridgeCategoriesFromFirestore();
    _loadShoppingListCategoriesFromFirestore();

    // expirationDays = widget.expirationDays;
    consumptionDays = widget.consumptionDays;
    dateController.text = widget.registrationDate;

    _focusNode.addListener(() {
      setState(() {}); // FocusNode 상태가 바뀔 때 화면을 다시 그리도록 설정
    });
  }

  @override
  void dispose() {
    _focusNode.dispose(); // FocusNode 해제
    super.dispose();
  }

  void _loadFoodsCategoriesFromFirestore() async {
    try {
      final foodsSnapshot = await FirebaseFirestore.instance.collection('foods').get();
      final userFoods = foodsSnapshot.docs.map((doc) {
        return FoodsModel.fromFirestore(doc);
      }).toList();

      final defaultFoodsSnapshot = await FirebaseFirestore.instance.collection('default_foods').get();
      final defaultFoods = defaultFoodsSnapshot.docs.map((doc) {
        return FoodsModel.fromFirestore(doc);
      }).toList();

      final Map<String, FoodsModel> uniqueCategoriesMap = {};
      for (var category in userFoods) {
        uniqueCategoriesMap[category.defaultCategory] = category;
      }

      // 2️⃣ 기본 default_foods 데이터 추가 (사용자 데이터에 없는 경우만)
      for (var category in defaultFoods) {
        if (!uniqueCategoriesMap.containsKey(category.defaultCategory)) {
          uniqueCategoriesMap[category.defaultCategory] = category;
        }
      }

      // 🔹 중복 제거된 리스트 변환
      final uniqueCategories = uniqueCategoriesMap.values.toList();

      setState(() {
        foodsCategories = uniqueCategories;
        if (widget.foodsCategory.isNotEmpty) {
          selectedFoodsCategory = foodsCategories.firstWhere(
            (category) => category.defaultCategory == widget.foodsCategory,
            orElse: () => FoodsModel(
              // 기본값을 설정
              id: 'unknown',
              foodsName: '',
              defaultCategory: '',
              defaultFridgeCategory: '',
              shoppingListCategory: '',
              // expirationDate: 0,
              // registrationDate: DateTime.now(),
              shelfLife: 0,
            ),
          );
        }
      });
    } catch (e) {
      print("Error loading foods categories: $e");
    }
  }

  // 냉장고 카테고리
  Future<void> _loadFridgeCategoriesFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('fridge_categories').get();

    final categories = snapshot.docs.map((doc) {
      return FridgeCategory.fromFirestore(doc);
    }).toList();
    setState(() {
      fridgeCategories = categories;

      selectedFridgeCategory = fridgeCategories.firstWhere(
        (category) => category.categoryName == widget.fridgeCategory,
        orElse: () => FridgeCategory(
          id: 'unknown',
          categoryName: '',
        ),
      );
    });
  }

  // 쇼핑리스트 카테고리
  Future<void> _loadShoppingListCategoriesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_categories')
        .get();

    final categories = snapshot.docs.map((doc) {
      return ShoppingCategory.fromFirestore(doc);
    }).toList();
    setState(() {
      shoppingListCategories = categories;

      selectedShoppingListCategory = shoppingListCategories.firstWhere(
        (category) => category.categoryName == widget.shoppingListCategory,
        orElse: () => ShoppingCategory(
          // 기본 ShoppingCategory 반환
          id: 'unknown',
          categoryName: '',
        ),
      );
    });
  }

  // 날짜 선택 함수
  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null && pickedDate != currentDate) {
      setState(() {
        currentDate = pickedDate;
        dateController.text = DateFormat('yyyy-MM-dd').format(currentDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('상세보기'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('카테고리명',
                      style: TextStyle(
                          fontSize: 18, color: theme.colorScheme.onSurface)),
                  Spacer(),
                  DropdownButton<FoodsModel>(
                    value: foodsCategories.contains(selectedFoodsCategory)
                        ? selectedFoodsCategory
                        : null,
                    hint: Text('카테고리 선택'),
                    items: foodsCategories.map((FoodsModel value) {
                      return DropdownMenuItem<FoodsModel>(
                        value: value,
                        child: Text(
                          value.defaultCategory,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                    onChanged: (FoodsModel? newValue) {
                      setState(() {
                        selectedFoodsCategory = newValue;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '식품명',
                    style: TextStyle(
                        fontSize: 18, color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  SizedBox(
                    width: 200,
                    // 원하는 크기로 설정
                    child: TextField(
                      controller: foodNameController
                        ..text = widget.foodsName ?? '',
                      // textAlign: TextAlign.,
                      focusNode: _focusNode,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface, // 입력 글자의 색상
                      ),
                      decoration: InputDecoration(
                        border: _focusNode.hasFocus
                            ? OutlineInputBorder() // 포커스가 있을 때만 테두리 표시
                            : InputBorder.none,
                        hintText: '식품명을 입력하세요',
                        hintStyle: TextStyle(
                          color: Colors.grey, // 힌트 텍스트 색상
                          fontStyle: FontStyle.italic, // 힌트 텍스트 스타일 (기울임꼴)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Text('냉장고 카테고리',
                      style: TextStyle(
                          fontSize: 18, color: theme.colorScheme.onSurface)),
                  Spacer(),
                  DropdownButton<FridgeCategory>(
                    value: fridgeCategories.contains(selectedFridgeCategory)
                        ? selectedFridgeCategory
                        : null,
                    hint: Text('카테고리 선택'),
                    items: fridgeCategories.map((FridgeCategory value) {
                      return DropdownMenuItem<FridgeCategory>(
                        value: value,
                        child: Text(value.categoryName,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (FridgeCategory? newValue) {
                      setState(() {
                        selectedFridgeCategory = newValue;
                      });
                    },
                  ),
                  SizedBox(width: 20),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Text('장보기 카테고리',
                      style: TextStyle(
                          fontSize: 18, color: theme.colorScheme.onSurface)),
                  Spacer(),
                  DropdownButton<ShoppingCategory>(
                    value: shoppingListCategories
                            .contains(selectedShoppingListCategory)
                        ? selectedShoppingListCategory
                        : null,
                    hint: Text('카테고리 선택',
                        style: TextStyle(color: theme.colorScheme.onSurface)),
                    items: shoppingListCategories.map((ShoppingCategory value) {
                      return DropdownMenuItem<ShoppingCategory>(
                        value: value,
                        child: Text(value.categoryName,
                            style:
                                TextStyle(color: theme.colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (ShoppingCategory? newValue) {
                      setState(() {
                        selectedShoppingListCategory = newValue;
                      });
                    },
                  ),
                  SizedBox(width: 20),
                ],
              ),
              // Row(
              //   children: [
              //     Text('유통기한', style: TextStyle(fontSize: 18)),
              //     Spacer(),
              //     Row(
              //       children: [
              //         IconButton(
              //           icon: Icon(Icons.remove),
              //           onPressed: () {
              //             setState(() {
              //               if (expirationDays > 1) expirationDays--;
              //             });
              //           },
              //         ),
              //         Text('$expirationDays 일', style: TextStyle(fontSize: 18)),
              //         IconButton(
              //           icon: Icon(Icons.add),
              //           onPressed: () {
              //             setState(() {
              //               expirationDays++;
              //             });
              //           },
              //         ),
              //       ],
              //     ),
              //   ],
              // ),
              SizedBox(height: 20),
              // 소비기한 선택 드롭다운
              Row(
                children: [
                  Text('품질유지기한',
                      style: TextStyle(
                          fontSize: 18, color: theme.colorScheme.onSurface)),
                  Spacer(),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (consumptionDays > 1) consumptionDays--;
                          });
                        },
                      ),
                      Text('$consumptionDays 일',
                          style: TextStyle(
                              fontSize: 18,
                              color: theme.colorScheme.onSurface)),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            consumptionDays++;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              // SizedBox(height: 20),
              // Row(
              //   children: [
              //     Text('등록일', style: TextStyle(fontSize: 18)),
              //     Spacer(),
              //     SizedBox(
              //       width: 150, // 필드 크기
              //       child: TextField(
              //         controller: dateController,
              //         textAlign: TextAlign.center,
              //         decoration: InputDecoration(
              //           hintText: '날짜 선택',
              //           border: OutlineInputBorder(),
              //         ),
              //         readOnly: true,
              //         onTap: () => _selectDate(context), // 날짜 선택 다이얼로그 호출
              //       ),
              //     ),
              //     SizedBox(height: 20),
              //   ],
              // ),
            ],
          ),
        ),
      ),
      // 하단에 추가 버튼 추가
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: NavbarButton(
            buttonTitle: '저장하기',
            onPressed: () async {
              // 식품 데이터 수집
              final updatedData = {
                'foodsName': foodNameController.text, // 사용자가 입력한 식품명
                'defaultCategory': selectedFoodsCategory?.defaultCategory ?? '',
                'defaultFridgeCategory':
                    selectedFridgeCategory?.categoryName ?? '',
                'shoppingListCategory':
                    selectedShoppingListCategory?.categoryName ?? '',
                // 'expirationDate': expirationDays,
                'shelfLife': consumptionDays,
              };

              try {
                final snapshot = await FirebaseFirestore.instance
                    .collection('foods')
                    .where('foodsName', isEqualTo: widget.foodsName)
                    .get();

                if (snapshot.docs.isNotEmpty) {
                  final docId = snapshot.docs.first.id; // 첫 번째 문서의 ID를 가져옴

                  await FirebaseFirestore.instance
                      .collection('foods')
                      .doc(docId)
                      .update(updatedData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('해당 데이터를 찾을 수 없습니다.')),
                  );
                }
                Navigator.pop(context);
              } catch (e) {
                print('Error updating data: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('데이터 저장 중 오류가 발생했습니다.')),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
