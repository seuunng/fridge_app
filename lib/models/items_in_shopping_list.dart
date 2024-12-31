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

  factory ItemsInShoppingList.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ItemsInShoppingList(
      id: doc.id,
      items: data['Items'] ?? '',
      userId: data['UserID'] ?? 'Unknown User', // Firestore 필드명
      isChecked: data['IsChecked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'Items': items,
      'UserID': userId,
      'IsChecked': isChecked, // Firestore에 저장할 필드
    };
  }
}
