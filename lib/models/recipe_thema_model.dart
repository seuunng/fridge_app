import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeThemaModel {
  final String id; // 고유 ID
  final String categories; // 대분류 카테고리 이름

  RecipeThemaModel({
    required this.id,
    required this.categories,
  });

  factory RecipeThemaModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RecipeThemaModel(
      id: doc.id,
      categories: data['categories'] as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categories': categories,
    };
  }
}
