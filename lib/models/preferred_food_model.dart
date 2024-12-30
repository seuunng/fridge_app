import 'package:cloud_firestore/cloud_firestore.dart';

class PreferredFoodModel {
  final Map<String, List<String>> categoryName;
  final String userId;

  PreferredFoodModel({
    required this.categoryName,
    required this.userId
  });

  factory PreferredFoodModel.fromFirestore(Map<String, dynamic> data) {
    // Firestore 데이터에서 category 필드를 안전하게 변환
    final rawCategory = data['category'] as Map<String, dynamic>? ?? {};
    final categoryName = rawCategory.map((key, value) {
      return MapEntry(
        key,
        (value as List<dynamic>).map((e) => e.toString()).toList(), // 명시적으로 List<String> 변환
      );
    });

    final userId = data['userId'] as String? ?? '';

    return PreferredFoodModel(
      userId: userId,
      categoryName: categoryName,
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'categoryName': categoryName
    };
  }
}
