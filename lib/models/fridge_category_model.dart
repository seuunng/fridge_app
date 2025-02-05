import 'package:cloud_firestore/cloud_firestore.dart';

class FridgeCategory {
  String id;
  String categoryName;
  String? userId; // 사용자 ID 추가

  FridgeCategory({
    required this.id,
    required this.categoryName,
    this.userId,
  });

  factory FridgeCategory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FridgeCategory(
      id: data['id'] ?? 'unknown_id',  // 기본값 설정
      categoryName: data['categoryName'] ?? 'Unknown Category',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryName': categoryName, // Firestore에 저장할 필드
    };
  }
}

List<FridgeCategory> generateDefaultCategories() {
  List<String> defaultCategories = [
    '냉장',
    '냉동',
    '상온',
  ];

  return defaultCategories.map((categoryName) {
    String categoryId =
        FirebaseFirestore.instance.collection('default_fridge_categories').doc().id;
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
        .collection('default_fridge_categories')
        .doc(category.id)
        .set(category.toFirestore());
  }
}
