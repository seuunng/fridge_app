import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum SortState { none, ascending, descending }

class RecipeTrendTable extends StatefulWidget {
  @override
  _RecipeTrendTableState createState() => _RecipeTrendTableState();
}

class _RecipeTrendTableState extends State<RecipeTrendTable> {
  List<Map<String, dynamic>> userData = [];

  @override
  void initState() {
    super.initState();
    _loadSearchRecipeTrends();
  }

  void _loadSearchRecipeTrends() async {
    final trends = await _fetchSearchTrends();
    setState(() {
      userData = trends;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSearchTrends() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('recipe')
          .orderBy('views', descending: true) // 검색 횟수 기준 내림차순 정렬
          .limit(10) // 상위 10개만 가져옴
          .get();

      int rank = 1; // 순위를 1부터 시작

      List<Map<String, dynamic>> trends = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final recipeId = doc.id;
        final userId = data['userID']; // userId 가져오기
        final stats = await fetchRecipeStats(recipeId);
        final userDetails = await fetchUserDetails(userId); // 닉네임, 이메일 가져오기

        trends.add({
          '순위': rank++,
          '제목': data['recipeName'] ?? 'N/A',
          '작성자': userDetails['nickname'] ?? 'N/A', // users 컬렉션에서 가져옴
          '이메일': userDetails['email'] ?? 'N/A', // users 컬렉션에서 가져옴
          '작성일':
              (data['date'] as Timestamp?)?.toDate().toString().split(' ')[0] ??
                  '알 수 없음',
          '조회수': data['views'] ?? 0,
          '스크랩': stats['scrapedCount'],
          '좋아요': stats['likedCount'],
          '리뷰': stats['reviewCount'],
          '공유': data['shared'] ?? 0,
          '별점': data['rating'] ?? 0,
        });
      }
      return trends;
    } catch (e) {
      print('검색 트렌드 데이터를 가져오는 중 오류 발생: $e');
      return [];
    }
  }

  Future<Map<String, int>> fetchRecipeStats(String recipeId) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    try {
      final scrapedCount = await db
          .collection('scraped_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .get()
          .then((snapshot) => snapshot.size);

      final likedCount = await db
          .collection('liked_recipes')
          .where('recipeId', isEqualTo: recipeId)
          .get()
          .then((snapshot) => snapshot.size);

      final reviewCount = await db
          .collection('recipe_reviews')
          .where('recipeId', isEqualTo: recipeId)
          .get()
          .then((snapshot) => snapshot.size);

      return {
        'scrapedCount': scrapedCount,
        'likedCount': likedCount,
        'reviewCount': reviewCount,
      };
    } catch (e) {
      print('Error fetching recipe stats: $e');
      return {
        'scrapedCount': 0,
        'likedCount': 0,
        'reviewCount': 0,
      };
    }
  }

  Future<Map<String, String>> fetchUserDetails(String userId) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.data()!;
        return {
          'nickname': userData['nickname'] ?? 'N/A',
          'email': userData['email'] ?? 'N/A',
        };
      } else {
        return {'nickname': 'N/A', 'email': 'N/A'};
      }
    } catch (e) {
      print('유저 정보를 가져오는 중 오류 발생: $e');
      return {'nickname': 'N/A', 'email': 'N/A'};
    }
  }

  List<Map<String, dynamic>> columns = [
    {'name': '순위', 'state': SortState.none},
    {'name': '제목', 'state': SortState.none},
    {'name': '조회수', 'state': SortState.none},
    {'name': '스크랩', 'state': SortState.none},
    {'name': '좋아요', 'state': SortState.none},
    {'name': '리뷰', 'state': SortState.none},
    {'name': '공유', 'state': SortState.none},
    {'name': '별점', 'state': SortState.none},
    {'name': '작성일', 'state': SortState.none},
    {'name': '작성자', 'state': SortState.none},
    {'name': '이메일', 'state': SortState.none},
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
        userData.sort((a, b) => a['순위'].compareTo(b['순위']));
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
                          color: theme.colorScheme.onSurface

                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            rows: userData.map((row) {
              return DataRow(cells: [
                DataCell(Text(row['순위'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '순위' 필드 사용
                DataCell(Text(row['제목'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '제목' 필드 사용
                DataCell(Text(row['조회수'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '조회수' 필드 사용
                DataCell(Text(row['스크랩'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '스크랩' 필드 사용
                DataCell(Text(row['좋아요'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '스크랩' 필드 사용
                DataCell(Text(row['리뷰'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '따라하기' 필드 사용
                DataCell(Text(row['공유'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '공유' 필드 사용
                DataCell(Text(row['별점'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '공유' 필드 사용
                DataCell(Text(row['작성일'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '작성일' 필드 사용
                DataCell(Text(row['작성자'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '닉네임' 필드 사용
                DataCell(Text(row['이메일'].toString(),
                    style: TextStyle(color: theme.colorScheme.onSurface))), // '닉네임' 필드 사용
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
