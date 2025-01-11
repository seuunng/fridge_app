import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScrapedRecipeService {
  static Future<bool> toggleScraped(
      BuildContext context, String recipeId, Function updateState) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      // 스크랩 상태 확인을 위한 쿼리
      QuerySnapshot<Map<String, dynamic>> existingScrapedRecipes =
      await FirebaseFirestore.instance
          .collection('scraped_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .where('userId', isEqualTo: userId)
          .get();

      bool isScraped;
      if (existingScrapedRecipes.docs.isEmpty) {
        // 🔹 스크랩이 존재하지 않으면 새로 추가
        await FirebaseFirestore.instance.collection('scraped_recipes').add({
          'userId': userId,
          'recipeId': recipeId,
          'isScraped': true,
          'scrapedGroupName': '기본함',
          'scrapedAt': FieldValue.serverTimestamp(),
        });

        isScraped = true;
      } else {
        // 🔹 스크랩이 존재하면 삭제
        DocumentSnapshot<Map<String, dynamic>> doc =
            existingScrapedRecipes.docs.first;

        await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .doc(doc.id)
            .delete();

        isScraped = false;
      }

      // 🔹 UI 업데이트 (상태 변경 함수 호출)
      updateState(isScraped);

      // 🔹 피드백 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isScraped ? '스크랩이 추가되었습니다.' : '스크랩이 해제되었습니다.'),
        ),
      );

      return isScraped;
    } catch (e) {
      print('Error scraping recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('레시피 스크랩 중 오류가 발생했습니다.'),
      ));
      return false;
    }
  }
}
