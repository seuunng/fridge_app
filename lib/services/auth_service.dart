import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> getUserRole() async {
    User? user = _auth.currentUser;

    if (user == null) {
      return "guest"; // 🔹 로그인하지 않은 유저는 guest 처리
    }

    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      return "user"; // 🔹 기본적으로 일반 사용자(user)로 처리
    }

    return userDoc['role'] ?? "user"; // 🔹 Firestore에서 role 가져오기
  }
}
