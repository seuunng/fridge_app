import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScrapedRecipeService {
  static Future<bool> toggleScraped(
      BuildContext context, String recipeId, String? link) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == 'guest@foodforlater.com') {
      // 🔹 방문자(게스트) 계정이면 스크랩 차단 및 안내 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후 레시피를 스크랩할 수 있습니다.')),
      );
      return false; // 🚫 여기서 함수 종료 (스크랩 기능 실행 안 함)
    }

    final userId = user.uid;
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (link != null) {
        // 🔹 웹 레시피의 경우 link로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('link', isEqualTo: link)
            .get();
      } else {
        // 🔹 Firestore 레시피의 경우 recipeId로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('recipeId', isEqualTo: recipeId)
            .get();
      }
      // 스크랩 상태 확인을 위한 쿼리

      bool isScraped;
      if (snapshot.docs.isEmpty) {
        // 🔹 스크랩이 존재하지 않으면 새로 추가
        await FirebaseFirestore.instance.collection('scraped_recipes').add({
          'userId': userId,
          'recipeId': recipeId ?? '',
          'isScraped': true,
          'scrapedGroupName': '기본함',
          'scrapedAt': FieldValue.serverTimestamp(),
          'link': link ?? ''
        });

        isScraped = true;
      } else {
        // 🔹 스크랩이 존재하면 삭제
        DocumentSnapshot<Map<String, dynamic>> doc =
            snapshot.docs.first;

        await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .doc(doc.id)
            .delete();

        isScraped = false;
      }


      // 🔹 피드백 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isScraped ? '스크랩이 추가되었습니다.' : '스크랩이 해제되었습니다.'),
        ),
      );

      print('최종 스크랩 상태: $isScraped');
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
