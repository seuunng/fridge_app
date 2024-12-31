import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeMethodModel {
  final String id; // 고유 ID
  final String categories; // 대분류 카테고리 이름
  final List<String> method;

  RecipeMethodModel({
    required this.id,
    required this.categories,
    required this.method,
  });

  factory RecipeMethodModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String categories =
        (data['categories'] != null) ? data['categories'] as String : '';

    List<String> methodList =
        (data['method'] != null) ? List<String>.from(data['method']) : [];

    return RecipeMethodModel(
      id: doc.id,
      categories: categories,
      method: methodList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'categories': categories, 'method': method};
  }
}
