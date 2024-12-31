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

  SortState _numberSortState = SortState.none;
  SortState _titleSortState = SortState.none;
  SortState _authorSortState = SortState.none;
  SortState _resultSortState = SortState.none;
  SortState _dateSortState = SortState.none;

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

      setState(() {
        feedbackData = snapshot.docs.asMap().entries.map((entry) {
          final index = entry.key; // 인덱스를 사용하여 연번 설정
          final doc = entry.value;

          return {
            'id': doc.id,
            '연번': (index + 1).toString(), // 연번 추가
            'title': doc.data().containsKey('title') ? doc['title'] : '제목 없음',
            'content':
                doc.data().containsKey('content') ? doc['content'] : '내용 없음',
            'author':
                doc.data().containsKey('author') ? doc['author'] : '작성자 없음',
            'authorEmail': doc.data().containsKey('authorEmail')
                ? doc['authorEmail']
                : '이메일 없음',
            'status': doc.data().containsKey('status') ? doc['status'] : 'NEW',
            'timestamp': (doc.data().containsKey('timestamp') &&
                    doc['timestamp'] is Timestamp)
                ? (doc['timestamp'] as Timestamp).toDate()
                : DateTime.now(), // timestamp 처리
            'postType':
                doc.data().containsKey('postType') ? doc['postType'] : '내용 없음',
            'postNo':
                doc.data().containsKey('postNo') ? doc['postNo'] : '내용 없음',
            'confirmationNote':
            doc.data().containsKey('confirmationNote') ? doc['confirmationNote'] : '',

          };
          
        }).toList();

        originalData = List.from(feedbackData); // 원본 데이터 복사
      });
    } catch (e) {
      print('Error loading fridge items: $e');
    }
  }

  String _formatDate(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
    return formatter.format(dateTime);
  }

  void _sortByTitle() {
    setState(() {
      if (_titleSortState == SortState.none) {
        feedbackData.sort((a, b) => a['title']!.compareTo(b['title']!));
        _titleSortState = SortState.ascending;
      } else if (_titleSortState == SortState.ascending) {
        feedbackData.sort((a, b) => b['title']!.compareTo(a['title']!));
        _titleSortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        _titleSortState = SortState.none;
      }
    });
  }

  void _sortByNumber() {
    setState(() {
      if (_numberSortState == SortState.none) {
        feedbackData.sort((a, b) => a['연번']!.compareTo(b['연번']!));
        _numberSortState = SortState.ascending;
      } else if (_numberSortState == SortState.ascending) {
        feedbackData.sort((a, b) => b['연번']!.compareTo(a['연번']!));
        _numberSortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        _numberSortState = SortState.none;
      }
    });
  }

  void _sortByAuthor() {
    setState(() {
      if (_authorSortState == SortState.none) {
        feedbackData.sort((a, b) => a['author']!.compareTo(b['author']!));
        _authorSortState = SortState.ascending;
      } else if (_authorSortState == SortState.ascending) {
        feedbackData.sort((a, b) => b['author']!.compareTo(a['author']!));
        _authorSortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        _authorSortState = SortState.none;
      }
    });
  }

  void _sortByResult() {
    setState(() {
      if (_resultSortState == SortState.none) {
        feedbackData.sort((a, b) => a['status']!.compareTo(b['status']!));
        _resultSortState = SortState.ascending;
      } else if (_resultSortState == SortState.ascending) {
        feedbackData.sort((a, b) => b['status']!.compareTo(a['status']!));
        _resultSortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        _resultSortState = SortState.none;
      }
    });
  }

  void _sortByDate() {
    setState(() {
      if (_dateSortState == SortState.none) {
        feedbackData.sort((a, b) {
          DateTime? dateA = a['timestamp'];
          DateTime? dateB = b['timestamp'];

          if (dateA == null && dateB == null) return 0; // 둘 다 null이면 같음
          if (dateA == null) return 1; // dateA가 null이면 뒤로 보냄
          if (dateB == null) return -1; // dateB가 null이면 앞으로 보냄
          return dateA.compareTo(dateB); // 날짜 비교
        });
        _dateSortState = SortState.ascending;
      } else if (_dateSortState == SortState.ascending) {
        feedbackData.sort((a, b) {
          DateTime? dateA = a['timestamp'];
          DateTime? dateB = b['timestamp'];

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // 내림차순 정렬
        });
        _dateSortState = SortState.descending;
      } else {
        feedbackData = List.from(originalData);
        _dateSortState = SortState.none;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredData = feedbackData
        .where((row) =>
            (row['title']?.toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase()) ||
            (row['author']?.toLowerCase() ?? '')
                .contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('의견 및 신고 처리하기'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '검색어를 입력하세요',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (query) {
              setState(() {
                searchQuery = query;
              });
            },
          ),
        ),
        Expanded(
            child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, // 가로 스크롤 가능하게 설정
          child: DataTable(
              columns: [
                DataColumn(
                  label: GestureDetector(
                    onTap: _sortByNumber, // 제목을 누르면 정렬 상태 변경
                    child: Row(
                      children: [
                        Text('연번'),
                        Icon(
                          _numberSortState == SortState.descending
                              ? Icons.arrow_upward
                              : _numberSortState == SortState.ascending
                                  ? Icons.arrow_downward
                                  : Icons.sort,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: GestureDetector(
                    onTap: _sortByDate, // 제목을 누르면 정렬 상태 변경
                    child: Row(
                      children: [
                        Text('날짜'),
                        Icon(
                          _dateSortState == SortState.descending
                              ? Icons.arrow_upward
                              : _dateSortState == SortState.ascending
                                  ? Icons.arrow_downward
                                  : Icons.sort,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: GestureDetector(
                    onTap: _sortByTitle, // 제목을 누르면 정렬 상태 변경
                    child: Row(
                      children: [
                        Text('제목'),
                        Icon(
                          _titleSortState == SortState.descending
                              ? Icons.arrow_upward
                              : _titleSortState == SortState.ascending
                                  ? Icons.arrow_downward
                                  : Icons.sort,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: GestureDetector(
                    onTap: _sortByAuthor, // 제목을 누르면 정렬 상태 변경
                    child: Row(
                      children: [
                        Text('작성자'),
                        Icon(
                          _authorSortState == SortState.descending
                              ? Icons.arrow_upward
                              : _authorSortState == SortState.ascending
                                  ? Icons.arrow_downward
                                  : Icons.sort,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                DataColumn(
                  label: GestureDetector(
                    onTap: _sortByResult, // 제목을 누르면 정렬 상태 변경
                    child: Row(
                      children: [
                        Text('처리결과'),
                        Icon(
                          _resultSortState == SortState.descending
                              ? Icons.arrow_upward
                              : _resultSortState == SortState.ascending
                                  ? Icons.arrow_downward
                                  : Icons.sort,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              rows: feedbackData.map((row) {
                return DataRow(cells: [
                  DataCell(
                    Container(
                      width: 10,
                      child: Text(row['연번'].toString() ?? 'N/A'),
                    ),
                  ),
                  DataCell(Text(_formatDate(row['timestamp']) ?? 'N/A')),
                  DataCell(
                    GestureDetector(
                      onTap: () async {
                        if (row['title'] != null) {
                          final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => FeedbackDetailPage(
                                        feedbackId: row['id'], // 피드백 문서의 ID 전달
                                        title: row['title'] ?? '제목 없음',
                                        content: row['content'] ?? '내용 없음',
                                        author: row['author'] ?? '작성자 없음',
                                        authorEmail:
                                            row['authorEmail'] ?? '이메일 없음',
                                        createdDate: row['timestamp'] ??
                                            DateTime
                                                .now(),
                                        statusOptions: ['처리 중', '완료', '보류'],
                                        postType: row['postType'] ?? '내용 없음',
                                        postNo: row['postNo'] ?? '내용 없음',
                                        selectedStatus:
                                            row['status'] ?? '내용 없음',
                                        confirmationNote:
                                            row['confirmationNote'] ??
                                                '내용 없음', // 확인사항
                                      )));
                          if (result == true) {
                            _loadFeedbackDataFromFirestore();
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('제목 또는 내용이 없습니다.')),
                          );
                        }
                      },
                      child: Text(
                        row['title'] ?? '제목 없음',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(row['author'].toString() ?? 'N/A')),
                  DataCell(Text(row['status'].toString() ?? 'NEW')),
                ]);
              }).toList()),
        ))
      ]),
    );
  }
}
