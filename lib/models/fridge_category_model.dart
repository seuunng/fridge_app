import 'package:cloud_firestore/cloud_firestore.dart';

class FridgeCategory {
  final String id;
  final String categoryName;

  FridgeCategory({
    required this.id,
    required this.categoryName,
  });

  factory FridgeCategory.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FridgeCategory(
      id: doc.id,
      categoryName: data['CategoryName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'CategoryName': categoryName, // Firestore에 저장할 필드
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
        FirebaseFirestore.instance.collection('fridge_categories').doc().id;
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
