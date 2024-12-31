import 'package:cloud_firestore/cloud_firestore.dart';

class FoodsModel {
  final String id;
  final String foodsName;
  final String defaultCategory;
  final String defaultFridgeCategory;
  final String shoppingListCategory;
  final int shelfLife;

  FoodsModel({
    required this.id,
    required this.foodsName,
    required this.defaultCategory,
    required this.defaultFridgeCategory,
    required this.shoppingListCategory,
    required this.shelfLife,
  });

  // Firestore에서 데이터를 가져오는 생성자
  factory FoodsModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return FoodsModel(
      id: doc.id,
      foodsName:data['foodsName'] ?? '',
      defaultCategory: data['defaultCategory'] ?? '',
      defaultFridgeCategory: data['defaultFridgeCategory'] ?? '',
      shoppingListCategory: data['shoppingListCategory'] ?? '',
      shelfLife: data['shelfLife'] != null ? int.tryParse(data['shelfLife'].toString()) ?? 0 : 0, // 숫자 변환
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'FoodsName': foodsName,
      'DefaultCategory': defaultCategory,
      'DefaultFridgeCategory': defaultFridgeCategory,
      'ShoppingListCategory': shoppingListCategory,
      'ShelfLife': shelfLife,
    };
  }
}