import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/foods_model.dart';
import 'package:food_for_later_new/models/fridge_category_model.dart';
import 'package:food_for_later_new/models/shopping_category_model.dart';
import 'package:intl/intl.dart';

class AddItemToCategory extends StatefulWidget {
  final String? categoryName; // 선택된 카테고리명을 받을 변수

  AddItemToCategory({this.categoryName}); // 생성자에서 카테고리명 받기

  @override
  _AddItemToCategoryState createState() => _AddItemToCategoryState();
}

class _AddItemToCategoryState extends State<AddItemToCategory> {
  List<FoodsModel> foodsCategories = [];
  FoodsModel? selectedFoodsCategory;

  List<FridgeCategory> fridgeCategories = [];
  FridgeCategory? selectedFridgeCategory;

  List<ShoppingCategory> shoppingListCategories = [];
  ShoppingCategory? selectedShoppingListCategory;

  int consumptionDays = 1; // 품질유지기한 기본값

  TextEditingController foodNameController = TextEditingController();
  TextEditingController dateController = TextEditingController(); // 등록일 컨트롤러

  DateTime currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('yyyy-MM-dd').format(currentDate);
    _loadFoodsCategoriesFromFirestore();
    _loadFridgeCategoriesFromFirestore();
    _loadShoppingListCategoriesFromFirestore();
  }

  void _loadFoodsCategoriesFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('foods').get();
      final categories = snapshot.docs.map((doc) {
        return FoodsModel.fromFirestore(doc);
      }).toList();

      final Map<String, FoodsModel> uniqueCategoriesMap = {};
      for (var category in categories) {
        if (!uniqueCategoriesMap.containsKey(category.defaultCategory)) {
          uniqueCategoriesMap[category.defaultCategory] = category;
        }
      }

      final uniqueCategories = uniqueCategoriesMap.values.toList();

      setState(() {
        foodsCategories = uniqueCategories;
        if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
          selectedFoodsCategory = foodsCategories.firstWhere(
            (category) => category.defaultCategory == widget.categoryName,
            orElse: () => FoodsModel(
              // 기본값을 설정
              id: 'unknown',
              foodsName: '',
              defaultCategory: '',
              defaultFridgeCategory: '',
              shoppingListCategory: '',
              // registrationDate: DateTime.now(),
              // expirationDate: 0,
              shelfLife: 0,
            ),
          );
        }
      });
    } catch (e) {
      print("Error loading foods categories: $e");
    }
  }

  Future<void> _loadFridgeCategoriesFromFirestore() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('fridge_categories').get();

    final categories = snapshot.docs.map((doc) {
      return FridgeCategory.fromFirestore(doc);
    }).toList();
    setState(() {
      fridgeCategories = categories;
    });
  }

  Future<void> _loadShoppingListCategoriesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_categories')
        .get();

    final categories = snapshot.docs.map((doc) {
      return ShoppingCategory.fromFirestore(doc);
    }).toList();
    setState(() {
      shoppingListCategories = categories;
    });
  }

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
        title: Text('기본 식품 카테고리에 추가하기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('카테고리명   ',
                        style: TextStyle(
                            fontSize: 18, color: theme.colorScheme.onSurface)),
                    Spacer(),
                    DropdownButton<FoodsModel>(
                      value: foodsCategories.contains(selectedFoodsCategory)
                          ? selectedFoodsCategory
                          : null,
                      hint: Text(
                        '카테고리 선택',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface, // 레이블 텍스트 스타일
                        ),
                      ),
                      items: foodsCategories.map((FoodsModel value) {
                        return DropdownMenuItem<FoodsModel>(
                          value: value,
                          child: Text(
                            value.defaultCategory,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface, // 레이블 텍스트 스타일
                            ),
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
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text('식품명',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurface, // 레이블 텍스트 스타일
                    )),
                Spacer(),
                SizedBox(
                  width: 200, // 원하는 크기로 설정
                  child: TextField(
                    controller: foodNameController,
                    decoration: InputDecoration(
                      // border: OutlineInputBorder(),
                      hintText: '식품명을 입력하세요',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6), // 힌트 텍스트 스타일
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
                        vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
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
                  value: selectedFridgeCategory,
                  hint: Text(
                    '카테고리 선택',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  items: fridgeCategories.map((FridgeCategory value) {
                    return DropdownMenuItem<FridgeCategory>(
                      value: value,
                      child: Text(
                        value.categoryName,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    );
                  }).toList(),
                  onChanged: (FridgeCategory? newValue) {
                    setState(() {
                      selectedFridgeCategory = newValue;
                    });
                  },
                ),
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
                  value: selectedShoppingListCategory,
                  hint: Text('카테고리 선택',
                      style: TextStyle(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  items: shoppingListCategories.map((ShoppingCategory value) {
                    return DropdownMenuItem<ShoppingCategory>(
                      value: value,
                      child: Text(
                        value.categoryName,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    );
                  }).toList(),
                  onChanged: (ShoppingCategory? newValue) {
                    setState(() {
                      selectedShoppingListCategory = newValue;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
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
                            fontSize: 18, color: theme.colorScheme.onSurface)),
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
            //           // border: OutlineInputBorder(),
            //         ),
            //         readOnly: true,
            //         onTap: () => _selectDate(context), // 날짜 선택 다이얼로그 호출
            //       ),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
      // 하단에 추가 버튼 추가
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: NavbarButton(
            buttonTitle: '추가하기',
            onPressed: () async {
              if (foodNameController.text.isNotEmpty &&
                  selectedFoodsCategory != null &&
                  selectedFridgeCategory != null &&
                  selectedShoppingListCategory != null) {
                try {
                  await FirebaseFirestore.instance.collection('foods').add({
                    'foodsName': foodNameController.text, // 식품명
                    'defaultCategory': selectedFoodsCategory?.defaultCategory ??
                        '', // 선택된 카테고리
                    'defaultFridgeCategory':
                        selectedFridgeCategory?.categoryName ?? '', // 냉장고 카테고리
                    'shoppingListCategory':
                        selectedShoppingListCategory?.categoryName ??
                            '', // 쇼핑 리스트 카테고리
                    // 'expirationDate': expirationDays, // 유통기한
                    'shelfLife': consumptionDays, // 품질유지기한
                  });

                  Navigator.pop(context, true);
                } catch (e) {
                  // 저장 중 에러 발생 시 알림 메시지 표시
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('식품 추가 중 오류가 발생했습니다: $e')),
                  );
                }
              } else {
                // 필수 입력 항목이 누락된 경우 경고 메시지 표시
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('모든 필드를 입력해주세요.')),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
