import 'package:cloud_firestore/cloud_firestore.dart';

class ItemsInFridge {
  final String id;
  final String fridgeId; // 연결된 Fridge ID
  final String fridgeCategoryId; // 연결된 Fridge ID
  final List<Map<String, String>> items; // 냉장고:카테고리:아이템

  ItemsInFridge({
    required this.id,
    required this.fridgeId,
    required this.fridgeCategoryId,
    required this.items,
  });

  factory ItemsInFridge.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    List<Map<String, String>> parsedItems;

    if (data['items'] is String) {
      parsedItems = [
        {'itemName': data['items'] as String}
      ];
    } else if (data['items'] is List) {
      parsedItems = List<Map<String, String>>.from(data['items'] as List);
    } else {
      parsedItems = [];
    }
    return ItemsInFridge(
      id: doc.id,
      fridgeId: data['FridgeId'] ?? 'Unknown Fridge', // Firestore 필드명
      fridgeCategoryId: data['FridgeCategoryId'] ?? 'Unknown Category',
      items: parsedItems,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'FridgeId': fridgeId, // Firestore에 저장할 필드
      'fridgeCategoryId': fridgeCategoryId,
      'Items': items,
    };
  }
}
