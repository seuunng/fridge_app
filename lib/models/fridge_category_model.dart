import 'package:cloud_firestore/cloud_firestore.dart';

class FridgeCategory {
  final String id;
  final String categoryName;

  FridgeCategory({
    required this.id,
    required this.categoryName,
  });

  // Firestore 데이터를 가져올 때 사용하는 팩토리 메서드
  factory FridgeCategory.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FridgeCategory(
      id: doc.id,
      categoryName: data['CategoryName'],
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'CategoryName': categoryName, // Firestore에 저장할 필드
    };
  }
}

List<FridgeCategory> generateDefaultCategories() {
  // 기본 카테고리 목록
  List<String> defaultCategories = [
    '냉장',
    '냉동',
    '상온',
  ];

  // 고유 ID를 생성하기 위해 Firestore의 doc ID 사용
  return defaultCategories.map((categoryName) {
    String categoryId = FirebaseFirestore.instance.collection('fridge_categories').doc().id;
    return FridgeCategory(
      id: categoryId,
      categoryName: categoryName,
    );
  }).toList();
}

Future<void> saveDefaultCategoriesToFirestore() async {
  List<FridgeCategory> defaultCategories = generateDefaultCategories();

  for (var category in defaultCategories) {
    await FirebaseFirestore.instance
        .collection('fridge_categories')
        .doc(category.id)
        .set(category.toFirestore());
  }
}
