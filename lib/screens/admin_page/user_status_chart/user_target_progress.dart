import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserTargetProgress extends StatefulWidget {
  @override
  _UserTargetProgressState createState() => _UserTargetProgressState();
}

class _UserTargetProgressState extends State<UserTargetProgress> {
  bool isEditingTotalTarget = false; // 총 사용자 목표 수정 상태
  bool isEditingDailyTarget = false; // 하루 사용자 목표 수정 상태
  int totalTarget = 100; // 총 사용자 목표
  int dailyTarget = 100; // 하루 사용자 목표
  int totalUsers = 0; // 총 사용자 현황
  int dailyUsers = 0; // 하루 사용자 현황

  @override
  void initState() {
    super.initState();
    _fetchTargetSettings();
    _fetchUserStatistics(); // Firestore에서 데이터 가져오기
  }
  Future<void> _fetchTargetSettings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('setting')
          .doc('userTargets')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        setState(() {
          totalTarget = data?['totalTarget'] ?? totalTarget; // 기본값 유지
          dailyTarget = data?['dailyTarget'] ?? dailyTarget; // 기본값 유지
        });
      }
    } catch (e) {
      print('❌ Firestore 설정 값 불러오기 실패: $e');
    }
  }

  Future<void> _fetchUserStatistics() async {
    // Firestore에서 총 사용자 수 가져오기
    final totalSnapshot = await FirebaseFirestore.instance.collection('users').get();

    // 하루 이용자 계산을 위한 데이터 처리
    int dailyUserCount = 0;
    DateTime oneDayAgo = DateTime.now().subtract(Duration(days: 1));

    for (var doc in totalSnapshot.docs) {
      final data = doc.data();
      final List<dynamic> openSessions = data['openSessions'] ?? []; // openSessions 배열 가져오기

      // openSessions에서 최신 endTime을 찾아 하루 이용자인지 확인
      DateTime? lastEndTime = openSessions
          .map((session) => session['endTime'] as Timestamp?) // Timestamp로 변환
          .where((timestamp) => timestamp != null) // null 제거
          .map((timestamp) => timestamp!.toDate()) // DateTime으로 변환
          .fold<DateTime?>(null, (latest, current) {
        if (latest == null || current.isAfter(latest)) {
          return current; // 최신 endTime 선택
        }
        return latest;
      });

      // 최신 endTime이 하루 이내라면 dailyUserCount 증가
      if (lastEndTime != null && lastEndTime.isAfter(oneDayAgo)) {
        dailyUserCount++;
      }
    }

    setState(() {
      totalUsers = totalSnapshot.size; // 총 사용자 수
      dailyUsers = dailyUserCount; // 하루 이용자 수
    });
  }

  void _updateTarget(String field, int value) async {
    // Firestore에 목표 업데이트
    await FirebaseFirestore.instance.collection('setting').doc('userTargets').set(
      {field: value},
      SetOptions(merge: true),
    );

    setState(() {
      if (field == 'totalTarget') {
        totalTarget = value;
      } else if (field == 'dailyTarget') {
        dailyTarget = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressRow(
            context: context,
            title: '목표대비 총 사용자',
            isEditing: isEditingTotalTarget,
            target: totalTarget,
            current: totalUsers,
            onDoubleTap: () {
              setState(() {
                isEditingTotalTarget = true;
              });
            },
            onSubmitted: (value) {
              final int newTarget = int.tryParse(value) ?? totalTarget;
              _updateTarget('totalTarget', newTarget);
              setState(() {
                isEditingTotalTarget = false;
              });
            },
          ),
          SizedBox(height: 16),
              _buildProgressRow(
                context: context,
                title: '목표대비 하루 이용자',
                isEditing: isEditingDailyTarget,
                target: dailyTarget,
                current: dailyUsers,
                onDoubleTap: () {
                  setState(() {
                    isEditingDailyTarget = true;
                  });
                },
                onSubmitted: (value) {
                  final int newTarget = int.tryParse(value) ?? dailyTarget;
                  _updateTarget('dailyTarget', newTarget);
                  setState(() {
                    isEditingDailyTarget = false;
                  });
                },
              ),
        ],
      ),
    );
  }
  Widget _buildProgressRow({
    required BuildContext context,
    required String title,
    required bool isEditing,
    required int target,
    required int current,
    required VoidCallback onDoubleTap,
    required ValueChanged<String> onSubmitted,
  }) {
    final theme = Theme.of(context);
    final progress = (target > 0) ? current / target : 0.0; // 목표 대비 진행률 계산
    final percentage = (progress * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ),
            isEditing
                ? Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                onSubmitted: onSubmitted,
                autofocus: true,
                decoration: InputDecoration(hintText: '목표 입력'),
              ),
            )
                : GestureDetector(
              onDoubleTap: onDoubleTap,
              child: Text(
                '$target',
                style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
              ),
            ),
            Text(
              '명/',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
            Text(
              '$current',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
            Text(
              '명 (',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
            Text(
              '$percentage%',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
            Text(
              ')',
              style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        SizedBox(height: 16),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0), // 진행률을 0~1 범위로 제한
          backgroundColor: Colors.grey[300],
          color: progress < 0.5
              ? Colors.green
              : (progress < 0.8 ? Colors.orange : Colors.red), // 진행률에 따라 색상 변경
          minHeight: 16, // 진행 바 높이
        ),
      ],
    );
  }
}
