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

  // Firestore 데이터를 가져올 때 사용하는 팩토리 메서드
  factory ItemsInFridge.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    List<Map<String, String>> parsedItems;

    if (data['items'] is String) {
      // String을 Map<String, String>으로 변환하여 List에 넣음
      parsedItems = [
        {'itemName': data['items'] as String}
      ];
    } else if (data['items'] is List) {
      // 이미 List<Map<String, String>> 형태라면 그대로 사용
      parsedItems = List<Map<String, String>>.from(data['items'] as List);
    } else {
      // 예상치 못한 데이터 형식인 경우 빈 리스트 처리
      parsedItems = [];
    }
    return ItemsInFridge(
      id: doc.id,
      fridgeId: data['FridgeId']?? 'Unknown Fridge', // Firestore 필드명
      fridgeCategoryId: data['FridgeCategoryId'] ?? 'Unknown Category',
      items: parsedItems,
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'FridgeId': fridgeId, // Firestore에 저장할 필드
      'fridgeCategoryId': fridgeCategoryId,
      'Items': items,
    };
  }
}