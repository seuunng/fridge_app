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

  factory FridgeName.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FridgeName(
      id: doc.id, // Firestore 문서의 ID
      fridgeName: data['FridgeName'], // Firestore 필드명
      userId: data['UserID'], // Firestore 필드명
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'FridgeName': fridgeName, // Firestore에 저장할 필드
      'UserID': userId, // Firestore에 저장할 필드
    };
  }
}
