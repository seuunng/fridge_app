import 'package:cloud_firestore/cloud_firestore.dart';

class PreferredFoodModel {
  final Map<String, List<String>> category;
  final String userId;

  PreferredFoodModel({required this.category, required this.userId});

  factory PreferredFoodModel.fromFirestore(Map<String, dynamic> data) {
    final rawCategory = data['category'] as Map<String, dynamic>? ?? {};
    final category = rawCategory.map((key, value) {
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
      category: category,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userId': userId, 'category': category};
  }
}
