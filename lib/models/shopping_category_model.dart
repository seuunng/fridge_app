import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingCategory {
  final String id;
  final String categoryName;

  ShoppingCategory({
    required this.id,
    required this.categoryName,
  });

  factory ShoppingCategory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ShoppingCategory(
      id: doc.id, // Firestore 문서 ID
      categoryName: data['CategoryName'], // Firestore 필드명
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'CategoryName': categoryName, // Firestore에 저장될 필드
    };
  }
}

List<ShoppingCategory> generateDefaultCategories() {
  List<String> defaultCategories = [
    '과일/채소',
    '정육/수산',
    '쌀/잡곡',
    '유제품/간편식',
    '생수/음료/커피/차',
    '면류/통조림',
    '양념/오일',
    '과자/간식',
    '기타'
  ];

  // 고유 ID를 생성하기 위해 Firestore의 doc ID 사용
  return defaultCategories.map((categoryName) {
    String categoryId = FirebaseFirestore.instance.collection('shopping_categories').doc().id;
    return ShoppingCategory(
      id: categoryId,
      categoryName: categoryName,
    );
  }).toList();
}

Future<void> saveDefaultCategoriesToFirestore() async {
  List<ShoppingCategory> defaultCategories = generateDefaultCategories();

  for (var category in defaultCategories) {
    await FirebaseFirestore.instance
        .collection('shopping_categories')
        .doc(category.id)
        .set(category.toFirestore());
  }
}
