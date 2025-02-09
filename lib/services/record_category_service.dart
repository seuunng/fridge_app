import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecordCategoryService {
  static Future<void> createDefaultCategories(String userId, BuildContext context, Function reloadCategories) async {
    try {
      final defaultCategories = [
        {
          'zone': '식사',
          'units': ['아침', '점심', '저녁'],
          'color': '#BBDEFB', // 스카이 블루
          'order': 0,
          'isDeleted': false
        },
        {
          'zone': '외식',
          'units': ['배달','외식','간식'],
          'color': '#FFC1CC', // 핑크 블러쉬
          'order': 1,
          'isDeleted': false
        },
      ];

      for (var category in defaultCategories) {
        await FirebaseFirestore.instance.collection('record_categories').add({
          'zone': category['zone'],
          'units': category['units'],
          'color': category['color'],
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(), // 생성 시간 추가
          'isDeleted': category['isDeleted'],
          'isDefault': true
        });
      }

      reloadCategories(); // 🔹 새로 생성한 기본 카테고리 로드
    } catch (e) {
      print('기본 카테고리 생성 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 카테고리 생성 중 오류가 발생했습니다.')),
      );
    }
  }
}