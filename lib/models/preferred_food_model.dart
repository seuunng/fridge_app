import 'package:cloud_firestore/cloud_firestore.dart';

class PreferredFoodModel {
  final Map<String, List<String>> categoryName;
  final String userId;

  PreferredFoodModel({required this.categoryName, required this.userId});

  factory PreferredFoodModel.fromFirestore(Map<String, dynamic> data) {
    final rawCategory = data['category'] as Map<String, dynamic>? ?? {};
    final categoryName = rawCategory.map((key, value) {
      return MapEntry(
        key,
        (value as List<dynamic>)
            .map((e) => e.toString())
            .toList(), // 명시적으로 List<String> 변환
      );
    });

    final userId = data['userId'] as String? ?? '';

    return PreferredFoodModel(
      userId: userId,
      categoryName: categoryName,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userId': userId, 'categoryName': categoryName};
  }
}
