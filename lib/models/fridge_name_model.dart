import 'package:cloud_firestore/cloud_firestore.dart';

class FridgeName {
  final String id; // Firestore 문서 ID
  final String fridgeName;
  final String userId; // 사용자의 ID

  FridgeName({
    required this.id,
    required this.fridgeName,
    required this.userId,
  });

  // Firestore 데이터를 가져올 때 사용하는 팩토리 메서드
  factory FridgeName.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FridgeName(
      id: doc.id, // Firestore 문서의 ID
      fridgeName: data['FridgeName'], // Firestore 필드명
      userId: data['UserID'], // Firestore 필드명
    );
  }

  // Firestore에 데이터를 저장할 때 사용하는 메서드
  Map<String, dynamic> toFirestore() {
    return {
      'FridgeName': fridgeName, // Firestore에 저장할 필드
      'UserID': userId, // Firestore에 저장할 필드
    };
  }
}
