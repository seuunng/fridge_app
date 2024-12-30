import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class AppLifecycleHandler with WidgetsBindingObserver {
  AppLifecycleHandler() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // 앱이 백그라운드로 전환되거나 종료될 때 호출
      recordSessionEnd();
    }
  }
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
/// 사용자의 세션 시작 시간을 기록하는 함수
Future<void> recordSessionStart() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    final sessionStart = Timestamp.now();

    try {
      // openSessions에 새로운 세션 추가
      await userDoc.update({
        'openSessions': FieldValue.arrayUnion([
          {'startTime': sessionStart} // 새로운 세션의 시작 시간 추가
        ])
      });
    } catch (e) {
      print('Error recording session start: $e');
    }
  }
}
  Future<void> recordSessionEnd() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final sessionEnd = Timestamp.now();
      // 가장 최근의 세션에 endTime 추가
      final userSnapshot = await userDoc.get();
      final sessions = List<Map<String, dynamic>>.from(userSnapshot.data()?['openSessions'] ?? []);

      // final List<dynamic> openSessions = userSnapshot.data()?['openSessions'] ?? [];

      if (sessions.isNotEmpty) {
        // 마지막 세션에 endTime을 추가
        sessions.last['endTime'] = sessionEnd;

        await userDoc.update({
          'openSessions': sessions,
        });
      } else {
        print("No open session found to add endTime.");
      }
    }
  }
