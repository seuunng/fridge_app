import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DefaultFridgeService {
  Future<void> createDefaultFridge(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('fridges')
          .where('FridgeName', isEqualTo: '기본 냉장고')
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        // Firestore에 기본 냉장고 추가
        await FirebaseFirestore.instance.collection('fridges').add({
          'FridgeName': '기본 냉장고',
          'userId': userId,
        });
      } else {
        print('기본 냉장고가 이미 존재합니다.');
      }
    } catch (e) {
      print('Error creating default fridge: $e');
    }
  }
}
