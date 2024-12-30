import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeThemaModel {
  final String id; // 고유 ID
  final String categories; // 대분류 카테고리 이름

  RecipeThemaModel({
    required this.id,
    required this.categories,
  });

  // Firestore에서 데이터를 가져올 때 사용하는 팩토리 메서드
  factory RecipeThemaModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecipeThemaModel(
      id: doc.id,
      categories: data['categories'] as String,
    );
  }

  // Firestore에 저장할 때 Map 형태로 변환하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'categories': categories,
    };
  }
}
