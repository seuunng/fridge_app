import 'package:cloud_firestore/cloud_firestore.dart';

class ItemsInShoppingList {
  final String id;
  final String items;
  final String userId;
  final bool isChecked;


  ItemsInShoppingList({
    required this.id,
    required this.items,
    required this.userId,
    required this.isChecked,
  });

  // Firestore 데이터를 가져올 때 사용하는 팩토리 메서드
  factory ItemsInShoppingList.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ItemsInShoppingList(
      id: doc.id,
      items: data['Items'] ?? '',
      userId: data['UserID'] ?? 'Unknown User', // Firestore 필드명
      isChecked: data['IsChecked'] ?? false,
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'Items': items,
      'UserID': userId,
      'IsChecked': isChecked, // Firestore에 저장할 필드
    };
  }
}