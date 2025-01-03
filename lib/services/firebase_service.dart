import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class FirebaseService with WidgetsBindingObserver {

  static Future<void> recordSessionStart() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final sessionStart = Timestamp.now();

      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final userSnapshot = await transaction.get(userDoc);
          final sessions = List<Map<String, dynamic>>.from(
              userSnapshot.data()?['openSessions'] ?? []);

          sessions.add({'startTime': sessionStart});

          transaction.update(userDoc, {'openSessions': sessions});
        });

      } catch (e) {
        print('Error recording session start: $e');
      }
    }
  }

  static Future<void> recordSessionEnd() async {
    // final user = FirebaseAuth.instance.currentUser;
    //
    // if (user != null) {
    //   final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    //   final sessionEnd = Timestamp.now();
    //
    //   final userSnapshot = await userDoc.get();
    //   final sessions = List<Map<String, dynamic>>.from(
    //       userSnapshot.data()?['openSessions'] ?? []);
    //
    //   if (sessions.isNotEmpty) {
    //     final lastSession = sessions.last;
    //
    //     if (!lastSession.containsKey('endTime')) {
    //       lastSession['endTime'] = sessionEnd;
    //
    //       await userDoc.update({'openSessions': sessions});
    //     } else {
    //       print('Session already has an endTime.');
    //     }
    //   } else {
    //     print("No open sessions found.");
    //   }
    // }
  }
}