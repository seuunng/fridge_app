import 'package:cloud_firestore/cloud_firestore.dart';

class DefaultFoodModel {
  // final String id; // 고유 ID
  // final String categories; // 대분류 카테고리 이름
  // final List<Map<String, dynamic>> itemsByCategory; // 소분류 아이템 이름
  //
  // DefaultFoodModel({
  //   required this.id,
  //   required this.categories,
  //   required this.itemsByCategory,
  // });
  //
  // // Firestore에서 데이터를 가져올 때 사용하는 팩토리 메서드
  // factory DefaultFoodModel.fromFirestore(DocumentSnapshot doc) {
  //   var data = doc.data() as Map<String, dynamic>;
  //   var items = data['itemsByCategory'] is Iterable
  //       ? List<Map<String, dynamic>>.from(data['itemsByCategory'])
  //       : [];
  //
  //   return DefaultFoodModel(
  //     id: doc.id,
  //     categories: data['categories'] ?? '', // 카테고리
  //     itemsByCategory: items.map((item) {
  //       return {
  //         'itemId': item['itemId'] ?? '', // 고유 ID
  //         'itemName': item['itemName'] ?? '', // 식품명
  //         'defaultFridgeCategory': item['defaultFridgeCategory'] ?? '', // 냉장고 카테고리
  //         'shoppingListCategory': item['shoppingListCategory'] ?? '', // 장보기 카테고리
  //         'shelfLife': item['shelfLife'] ?? 0, // 소비기한
  //         'expirationDate': item['expirationDate'] ?? 0, // 유통기한
  //       };
  //     }).toList(),
  //   );
  // }
  //
  // // Firestore에 저장할 때 Map 형태로 변환하는 메서드
  // Map<String, dynamic> toFirestore() {
  //   return {
  //     'categories': categories,
  //     'itemsByCategory': itemsByCategory.map((item) {
  //       return {
  //         'itemId': item['itemId'],
  //         'itemName': item['itemName'],
  //         'defaultFridgeCategory': item['defaultFridgeCategory'],
  //         'shoppingListCategory': item['shoppingListCategory'],
  //         'shelfLife': item['shelfLife'],
  //         'expirationDate': item['expirationDate'],
  //       };
  //     }).toList(),
  //   };
  // }
}
