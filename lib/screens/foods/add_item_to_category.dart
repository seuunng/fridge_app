import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
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

  List<String> predefinedCategoryFridge = [
    '채소',
    '과일',
    '육류',
    '수산물',
    '유제품',
    '가공식품',
    '곡류',
    '견과류',
    '양념',
    '음료/주류',
    '즉석식품',
    '디저트/빵류',
  ];
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
      uniqueCategories.sort((a, b) {
        final indexA = predefinedCategoryFridge.indexOf(a.defaultCategory);
        final indexB = predefinedCategoryFridge.indexOf(b.defaultCategory);

        // indexOf가 -1인 경우 리스트의 마지막으로 이동
        return (indexA == -1 ? predefinedCategoryFridge.length : indexA)
            .compareTo(indexB == -1 ? predefinedCategoryFridge.length : indexB);
      });
      setState(() {
        foodsCategories = uniqueCategories;

        // ✅ 사용자가 선택한 카테고리를 자동으로 선택
        if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
          selectedFoodsCategory = foodsCategories.firstWhere(
                (category) => category.defaultCategory == widget.categoryName,
            orElse: () => FoodsModel(
              id: 'unknown',
              foodsName: '',
              defaultCategory: '',
              defaultFridgeCategory: '',
              shoppingListCategory: '',
              shelfLife: 0,
            ),
          );

          // ✅ 기본값을 UI 입력 필드에 채우기
          foodNameController.text = '';
          consumptionDays = selectedFoodsCategory?.shelfLife ?? 1;
        }
      });
    } catch (e) {
      print("Error loading default foods categories: $e");
    }
  }

  Future<void> _loadFridgeCategoriesFromFirestore() async {
    try {
      // 🔹 기본 카테고리 불러오기
      final defaultSnapshot = await FirebaseFirestore.instance
          .collection('default_fridge_categories')
          .get();

      final customSnapshot = await FirebaseFirestore.instance
          .collection('fridge_categories')
          .where('userId', isEqualTo: userId)
          .get();

      // 🔹 기본 카테고리 변환
      final defaultCategories = defaultSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      // 🔹 사용자 커스텀 카테고리 변환
      final customCategories = customSnapshot.docs.map((doc) {
        return FridgeCategory.fromFirestore(doc);
      }).toList();

      // 🔹 기본 + 커스텀 카테고리를 합쳐서 사용
    setState(() {
      fridgeCategories = [
        ...defaultCategories,
        ...customCategories
      ];
    });
    } catch (e) {
      print('카테고리 불러오기 오류: $e');
    }
  }

  Future<void> _loadShoppingListCategoriesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('shopping_categories')
        .orderBy('priority', descending: false)
        .get();

    final categories = snapshot.docs.map((doc) {
      return ShoppingCategory.fromFirestore(doc);
    }).toList();
    setState(() {
      shoppingListCategories = categories;
    });
  }

  void _saveOrUpdateFood() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (foodNameController.text.isNotEmpty &&
        selectedFoodsCategory != null &&
        selectedFridgeCategory != null &&
        selectedShoppingListCategory != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('foods')
            .where('foodsName', isEqualTo: foodNameController.text)
            .where('userId', isEqualTo: userId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docId = querySnapshot.docs.first.id;
          await FirebaseFirestore.instance.collection('foods').doc(docId).update({
            'foodsName': foodNameController.text,
            'defaultCategory': selectedFoodsCategory!.defaultCategory,
            'defaultFridgeCategory': selectedFridgeCategory!.categoryName,
            'shoppingListCategory': selectedShoppingListCategory!.categoryName,
            'shelfLife': consumptionDays,
            'userId': userId,
          });
        } else {
          DocumentReference newDocRef = FirebaseFirestore.instance.collection('foods').doc();

          await newDocRef.set({
            'foodsName': foodNameController.text,
            'defaultCategory': selectedFoodsCategory!.defaultCategory,
            'defaultFridgeCategory': selectedFridgeCategory!.categoryName,
            'shoppingListCategory': selectedShoppingListCategory!.categoryName,
            'shelfLife': consumptionDays,
            'userId': userId,
          });
          // 🔹 생성된 문서의 ID를 다시 업데이트하여 `defaultFoodsDocId` 설정
          // 🔹 `defaultFoodsDocId` 값을 업데이트하여 문서 ID 저장
          await FirebaseFirestore.instance.collection('foods').doc(newDocRef.id).update({
            'defaultFoodsDocId': newDocRef.id, // ✅ 새로 추가한 아이템의 ID를 `defaultFoodsDocId`로 저장
          });
        }

        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('식품 추가/수정 중 오류 발생: $e'),
            duration: Duration(seconds: 2),),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모든 필드를 입력해주세요.'),
          duration: Duration(seconds: 2),),
      );
    }
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
                      hint: Text('카테고리 선택'),
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
                    textAlign: TextAlign.center, // 텍스트를 가운데 정렬
                    decoration: InputDecoration(
                      // border: OutlineInputBorder(),
                      hintText: '식품명을 입력하세요',
                      hintStyle: TextStyle(
                          color: Colors.grey, // 힌트 텍스트 색상
                          fontStyle: FontStyle.italic,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8.0, // 텍스트 필드 내부 좌우 여백 조절
                        vertical: 8.0, // 텍스트 필드 내부 상하 여백 조절
                      ),
                    ),
                    style: TextStyle(color: theme.colorScheme.onSurface),
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
                  hint: Text('카테고리 선택',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  items: fridgeCategories.map((FridgeCategory value) {
                    return DropdownMenuItem<FridgeCategory>(
                      value: value,
                      child: Text(
                        value.categoryName,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface),
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
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  items: shoppingListCategories.map((ShoppingCategory value) {
                    return DropdownMenuItem<ShoppingCategory>(
                      value: value,
                      child: Text(
                        value.categoryName,
                        style: TextStyle(
                            color: theme.colorScheme.onSurface),
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
            onPressed: () => _saveOrUpdateFood(),
          ),
        ),
      ),
    );
  }
}
