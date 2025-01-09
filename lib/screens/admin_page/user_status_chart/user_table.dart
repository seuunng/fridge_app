import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum SortState { none, ascending, descending }

class UserTable extends StatefulWidget {
  @override
  _UserTableState createState() => _UserTableState();
}

class _UserTableState extends State<UserTable> {
  List<Map<String, dynamic>> userData = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final now = DateTime.now(); // 현재 시간

    final futures = snapshot.docs.asMap().entries.map((entry) async {
      final index = entry.key + 1; // 1부터 시작하는 연번
      final data = entry.value.data();
      final signUpDateRaw = data['signupdate'];
      final signUpDate = signUpDateRaw is Timestamp
          ? signUpDateRaw.toDate()
          : DateTime.parse(signUpDateRaw.toString());
      final formattedDate = DateFormat('yyyy-MM-dd').format(signUpDate);
      final userId = entry.value.id;
      // 🔹 마지막 접속 날짜 가져오기
      final List<dynamic> openSessions = data['openSessions'] ?? [];
      DateTime? lastAccessDate;

      if (openSessions.isNotEmpty) {
        lastAccessDate = openSessions
            .map((session) => session['endTime'] as Timestamp?)
            .where((timestamp) => timestamp != null) // null 제거
            .map((timestamp) => timestamp!.toDate()) // DateTime 변환
            .reduce((a, b) => a.isAfter(b) ? a : b); // 최신 날짜 찾기
      }

      // 🔥 3개월(90일) 이상 미접속 → 휴면 계정으로 분류
      final bool isDormant = lastAccessDate == null ||
          now.difference(lastAccessDate).inDays > 90;

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
      final openCount = openSessions.length; // 접속 횟수는 세션의 개수로 계산
      final totalUsageTime = openSessions.fold<int>(0, (sum, session) {
        if (session['startTime'] == null || session['endTime'] == null) {
          return sum; // 잘못된 데이터는 건너뜀
        }
        final startTime = session['startTime'] as Timestamp;
        final endTime = session['endTime'] as Timestamp;
        return sum + endTime.toDate().difference(startTime.toDate()).inMinutes;
      });

      final totalUsageHours = (totalUsageTime / 60).toStringAsFixed(1);

      return {
        '연번': index,
        '이메일': data['email'] ?? '',
        '닉네임': data['nickname'] ?? '',
        '성별': data['gender'] ?? '',
        '출생연도': data['birthYear'] ?? '',
        '가입일': formattedDate,
        '접속횟수': openCount,
        '사용시간(h)': totalUsageHours,
        '레시피': recipeCount,
        '기록': recordCount,
        '스크랩': scrapCount,
        '계정상태': isDormant ? '휴면 계정' : '활성',
      };
    }).toList();

    userData = await Future.wait(futures);

    setState(() {});
  }

  // 각 열에 대한 정렬 상태를 관리하는 리스트
  List<Map<String, dynamic>> columns = [
    {'name': '연번', 'state': SortState.none},
    {'name': '이메일', 'state': SortState.none},
    {'name': '닉네임', 'state': SortState.none},
    {'name': '가입일', 'state': SortState.none},
    {'name': '성별', 'state': SortState.none},
    {'name': '생년월일', 'state': SortState.none},
    {'name': '접속횟수', 'state': SortState.none},
    {'name': '사용시간(h)', 'state': SortState.none},
    {'name': '레시피', 'state': SortState.none},
    {'name': '기록', 'state': SortState.none},
    {'name': '스크랩', 'state': SortState.none},
    {'name': '계정상태', 'state': SortState.none}, // 🔥 계정 상태 추가
  ];

  void _sortBy(String columnName, SortState currentState) {
    setState(() {
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

      if (currentState == SortState.none) {
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
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: columns.map((column) {
              return DataColumn(
                label: GestureDetector(
                  onTap: () => _sortBy(column['name'], column['state']),
                  child: Row(
                    children: [
                      Text(column['name'],
                          style: TextStyle(color: theme.colorScheme.onSurface)),
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
                return DataCell(Text(row[column['name']].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface)));
              }).toList());
            }).toList(),
          ),
        ),
      ),
    );
  }
}
