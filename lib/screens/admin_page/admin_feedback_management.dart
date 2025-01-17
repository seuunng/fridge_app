import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/admin_page/feedback_detail_page.dart';
import 'package:intl/intl.dart';

enum SortState { none, ascending, descending }

class AdminFeedbackManagement extends StatefulWidget {
  @override
  _AdminFeedbackManagementState createState() =>
      _AdminFeedbackManagementState();
}

class _AdminFeedbackManagementState extends State<AdminFeedbackManagement> {
  String searchQuery = '';

  SortState _dateSortState = SortState.none;
  SortState _categorySortState = SortState.none;
  SortState _feedbackTypeSortState = SortState.none;
  SortState _authorSortState = SortState.none;
  SortState _confirmationSortState = SortState.none;
  SortState _statusSortState = SortState.none;

  List<Map<String, dynamic>> feedbackData = [];
  late List<Map<String, dynamic>> originalData;

  @override
  void initState() {
    super.initState();
    originalData = List.from(feedbackData); // 초기 데이터 복사
    _loadFeedbackDataFromFirestore();
  }

  Future<void> _loadFeedbackDataFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('feedback').get();
      // 🔹 users 컬렉션에서 모든 사용자 정보 가져오기 (닉네임 조회)
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      Map<String, Map<String, String>> userMap = {
        for (var doc in usersSnapshot.docs)
          doc.id: {
            'nickname': doc.data().containsKey('nickname') ? doc['nickname'] : '사용자 없음',
            'email': doc.data().containsKey('email') ? doc['email'] : '이메일 없음'
          }
      };
      setState(() {
        feedbackData = snapshot.docs.map((doc) {
          String userId = doc.data().containsKey('author') ? doc['author'] : '알 수 없음';
          return {
            'id': doc.id,
            'timestamp': (doc.data().containsKey('timestamp') &&
                    doc['timestamp'] is Timestamp)
                ? (doc['timestamp'] as Timestamp).toDate()
                : DateTime.now(),
            'postNo':
            doc.data().containsKey('postNo') ? doc['postNo'] : '기타',
            'postType':
            doc.data().containsKey('postType') ? doc['postType'] : '기타',
            'category':
                doc.data().containsKey('category') ? doc['category'] : '기타',
            'feedbackType': doc.data().containsKey('feedbackType')
                ? doc['feedbackType']
                : '기타',
            'author': userMap[userId]?['nickname'] ?? '작성자 없음', // 닉네임 조회
            'authorEmail': userMap[userId]?['email'] ?? '이메일 없음', // 이메일 조회
            'confirmationNote': doc.data().containsKey('confirmationNote')
                ? doc['confirmationNote']
                : '확인되지 않음',
            'status': doc.data().containsKey('status') ? doc['status'] : '미처리',
            'content': doc.data().containsKey('content') ? doc['content'] : '내용이 없습니다.',
            'postTitle': doc.data().containsKey('postTitle') ? doc['postTitle'] : '신고대상 없음',
          };
        }).toList();

        originalData = List.from(feedbackData);
      });
    } catch (e) {
      print('Error loading feedback data: $e');
    }
  }

  String _formatDate(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
    return formatter.format(dateTime);
  }

  void _sortByField(String field, SortState sortState) {
    setState(() {
      if (sortState == SortState.none) {
        feedbackData.sort((a, b) => a[field].compareTo(b[field]));
        sortState = SortState.ascending;
      } else if (sortState == SortState.ascending) {
        feedbackData.sort((a, b) => b[field].compareTo(a[field]));
        sortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        sortState = SortState.none;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<Map<String, dynamic>> filteredData = feedbackData
        .where((row) =>
            (row['category']?.toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase()) ||
            (row['author']?.toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('의견 및 신고 처리하기'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '검색어를 입력하세요',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              style:
              TextStyle(color: theme.chipTheme.labelStyle!.color),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, // 가로 스크롤 추가
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: DataTable(
                columns: [
                  _buildSortableColumn('날짜', 'timestamp', _dateSortState),
                  _buildSortableColumn(
                      '구분', 'feedbackType', _feedbackTypeSortState),
                  _buildSortableColumn('항목', 'category', _categorySortState),
                  _buildSortableColumn('작성자', 'author', _authorSortState),
                  _buildSortableColumn(
                      '확인사항', 'confirmationNote', _confirmationSortState),
                  _buildSortableColumn('처리결과', 'status', _statusSortState),
                ],
                rows: filteredData.map((row) {
                  return DataRow(cells: [
                    DataCell(Text(_formatDate(row['timestamp']),
                        style: TextStyle(color: theme.colorScheme.onSurface))),
                    DataCell(Text(row['feedbackType'],
                        style: TextStyle(color: theme.colorScheme.onSurface))),
                    DataCell(Text(row['category'],
                        style: TextStyle(color: theme.colorScheme.onSurface)),
                    ),
                    DataCell(Text(row['author'],
                        style: TextStyle(color: theme.colorScheme.onSurface))),
                    DataCell(
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedbackDetailPage(
                                feedbackId: row['id'] ?? '', // 기본값 처리
                                content: row['content'] ?? '내용 없음', // 기본값 추가
                                author: row['author'] ?? '작성자 없음',
                                authorEmail: row['authorEmail'] ?? '이메일 없음', // 기본값 추가
                                createdDate: row['timestamp'] ?? DateTime.now(),
                                statusOptions: ['미처리', '처리 중', '완료'],
                                confirmationNote: row['confirmationNote'] ?? '확인되지 않음',
                                selectedStatus: row['status'] ?? '미처리',
                                postNo: row['postNo'] ?? '', // 기본값 추가
                                postType: row['postType'] ?? '기타',
                                feedbackType: row['feedbackType'] ?? '기타',
                                category: row['category'] ?? '기타',
                                postTitle: row['postTitle'] ?? '기타',
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadFeedbackDataFromFirestore();
                          }
                        },
                        child: Text(
                          row['confirmationNote'],
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),),
                    DataCell(Text(row['status'],
                        style: TextStyle(color: theme.colorScheme.onSurface))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildSortableColumn(
      String title, String field, SortState sortState) {
    final theme = Theme.of(context);
    return DataColumn(
      label: GestureDetector(
        onTap: () => _sortByField(field, sortState),
        child: Row(
          children: [
            Text(title,
                style: TextStyle(color: theme.colorScheme.onSurface)),
            Icon(
              sortState == SortState.descending
                  ? Icons.arrow_upward
                  : sortState == SortState.ascending
                      ? Icons.arrow_downward
                      : Icons.sort,
              size: 16,
                color: theme.colorScheme.onSurface
            ),
          ],
        ),
      ),
    );
  }
}
