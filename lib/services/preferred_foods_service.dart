import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PreferredFoodsService {
  static Future<void> addDefaultPreferredCategories(BuildContext context, Function reloadCategories) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      // 🔹 Firestore에서 해당 유저의 기본 카테고리가 존재하는지 먼저 확인
      final existingCategories = await FirebaseFirestore.instance
          .collection('preferred_foods_categories')
          .where('userId', isEqualTo: userId)
          .get();

      // 🔹 기존 카테고리가 있으면 추가하지 않음 (중복 방지)
      if (existingCategories.docs.isNotEmpty) {
        print('기본 선호 카테고리가 이미 존재합니다. 추가하지 않습니다.');
        return;
      }

      final defaultCategories = {
        '알러지': ['우유', '계란', '땅콩'],
        '유제품': ['우유', '치즈', '요거트'],
        '비건': ['육류', '해산물', '유제품', '계란', '꿀'],
        '무오신채': ['마늘', '양파', '부추', '파', '달래'],
        '설밀나튀': ['설탕', '밀가루', '튀김'],
      };

      for (var entry in defaultCategories.entries) {
        final category = entry.key;
        final items = entry.value;

        // Firestore에 기본 데이터 추가
        await FirebaseFirestore.instance
            .collection('preferred_foods_categories')
            .add({
          'userId': userId,
          'category': {category: items},
          'isDefault': true,
        });
      }

      // 데이터 다시 로드
      reloadCategories();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 선호 카테고리가 추가되었습니다.')),
      );
    } catch (e) {
      print('Error adding default preferred categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기본 선호 카테고리를 추가하는 중 오류가 발생했습니다.')),
      );
    }
  }
}
