import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum SortState { none, ascending, descending }

class UserTable extends StatefulWidget {
  @override
  _UserTableState createState() => _UserTableState();
}

class _UserTableState extends State<UserTable> {
  // 초기 사용자 데이터 빈 리스트로 설정
  List<Map<String, dynamic>> userData = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // Firestore에서 사용자 데이터를 가져오는 함수
  Future<void> fetchUserData() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    // 모든 비동기 작업을 리스트로 저장
    final futures = snapshot.docs.asMap().entries.map((entry) async {
      final index = entry.key + 1; // 1부터 시작하는 연번
      final data = entry.value.data();
      final signUpDateRaw = data['signupdate'];
      final signUpDate = signUpDateRaw is Timestamp
          ? signUpDateRaw.toDate()
          : DateTime.parse(signUpDateRaw.toString());
      final formattedDate = DateFormat('yyyy-MM-dd').format(signUpDate);
      final userId = entry.value.id;

      // 각 컬렉션에서 사용자의 데이터 개수 세기
      final recipeCount = await FirebaseFirestore.instance
          .collection('recipe')
          .where('userID', isEqualTo: userId)
          .get()
          .then((snapshot) => snapshot.size);

      final recordCount = await FirebaseFirestore.instance
          .collection('record')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) => snapshot.size);

      final scrapCount = await FirebaseFirestore.instance
          .collection('scraped_recipes')
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) => snapshot.size);

      // 앱 접속 횟수 및 사용 시간 데이터 (가정된 필드명 예시)
      final List<dynamic> openSessions = data['openSessions'] ?? [];
      final openCount = openSessions.length; // 접속 횟수는 세션의 개수로 계산
      final totalUsageTime = openSessions.fold<int>(0, (sum, session) {
        final startTime = session['startTime'] as Timestamp;
        final endTime = session['endTime'] as Timestamp;
        if (startTime is! Timestamp || endTime is! Timestamp) {
          return sum; // 잘못된 데이터는 건너뜀
        }
        return sum + endTime.toDate().difference(startTime.toDate()).inMinutes;
      });

      return {
        '연번': index,
        '이메일': data['email'] ?? '',
        '닉네임': data['nickname'] ?? '',
        '가입일': formattedDate,
        '접속횟수': openCount,
        '사용시간(분)': totalUsageTime,
        '레시피': recipeCount,
        '기록': recordCount,
        '스크랩': scrapCount,
      };
    }).toList();

    // 모든 비동기 작업이 완료될 때까지 기다린 후 userData에 할당
    userData = await Future.wait(futures);

    // UI 갱신을 위해 setState 호출
    setState(() {});
  }

  // 각 열에 대한 정렬 상태를 관리하는 리스트
  List<Map<String, dynamic>> columns = [
    {'name': '연번', 'state': SortState.none},
    {'name': '이메일', 'state': SortState.none},
    {'name': '닉네임', 'state': SortState.none},
    {'name': '가입일', 'state': SortState.none},
    // {'name': '성별', 'state': SortState.none},
    // {'name': '생년월일', 'state': SortState.none},
    {'name': '접속횟수', 'state': SortState.none},
    {'name': '사용시간(분)', 'state': SortState.none},
    {'name': '레시피', 'state': SortState.none},
    {'name': '기록', 'state': SortState.none},
    {'name': '스크랩', 'state': SortState.none},
  ];

  void _sortBy(String columnName, SortState currentState) {
    setState(() {
      // 열의 정렬 상태를 업데이트
      for (var column in columns) {
        if (column['name'] == columnName) {
          column['state'] = currentState == SortState.none
              ? SortState.ascending
              : (currentState == SortState.ascending
                  ? SortState.descending
                  : SortState.none);
        } else {
          column['state'] = SortState.none;
        }
      }

      // 정렬 수행
      if (currentState == SortState.none) {
        // 정렬 없으면 원래 데이터 순서 유지
        userData.sort((a, b) => a['연번'].compareTo(b['연번']));
      } else {
        userData.sort((a, b) {
          int result;
          result = a[columnName].compareTo(b[columnName]);
          return currentState == SortState.ascending ? result : -result;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((column) {
          return DataColumn(
            label: GestureDetector(
              onTap: () => _sortBy(column['name'], column['state']),
              child: Row(
                children: [
                  Text(column['name']),
                  Icon(
                    column['state'] == SortState.ascending
                        ? Icons.arrow_upward
                        : column['state'] == SortState.descending
                            ? Icons.arrow_downward
                            : Icons.sort,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        rows: userData.map((row) {
          return DataRow(
              cells: columns.map((column) {
            return DataCell(Text(row[column['name']].toString()));
          }).toList());
        }).toList(),
      ),
    );
  }
}
