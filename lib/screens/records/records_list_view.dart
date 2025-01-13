import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/models/record_model.dart';
import 'package:food_for_later_new/screens/records/create_record.dart';
import 'package:food_for_later_new/screens/records/read_record.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class RecordsListView extends StatefulWidget {
  @override
  _RecordsListViewState createState() => _RecordsListViewState();
}

class _RecordsListViewState extends State<RecordsListView> {
  DateTime? startDate;
  DateTime? endDate;
  List<String>? selectedCategories;
  bool isLoading = true; // 데이터를 불러오는 중 상태 표시
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadSearchSettingsFromLocal(); // SharedPreferences에서 검색 조건 불러오기
  }
  void _loadUserRole() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? 'user'; // 기본값은 'user'
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
    }
  }
  Future<void> _loadSearchSettingsFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final startDateString = prefs.getString('startDate');
      startDate = startDateString != null && startDateString.isNotEmpty
          ? DateTime.parse(startDateString)
          : null;
      final endDateString = prefs.getString('endDate');
      endDate = endDateString != null && endDateString.isNotEmpty
          ? DateTime.parse(endDateString)
          : null;
      selectedCategories = prefs.getStringList('selectedCategories') ?? ['모두'];
      isLoading = false; // 로딩 완료
    });
  }

  Color _convertColor(String colorString) {
    try {
      if (colorString.startsWith('#') && colorString.length == 9) {
        // '#AARRGGBB' 형식인 경우
        return Color(int.parse(colorString.replaceFirst('#', '0x')));
      } else if (colorString.startsWith('#') && colorString.length == 7) {
        // '#RRGGBB' 형식인 경우
        return Color(int.parse(colorString.replaceFirst('#', '0xff')));
      } else {
        return Colors.grey; // 잘못된 형식일 때 기본 색상 반환
      }
    } catch (e) {
      return Colors.grey; // 오류 발생 시 기본 색상 반환
    }
  }

// 레코드 수정 함수
  void _editRecord(String recordId, RecordDetail rec) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateRecord(
          recordId: recordId, // 초기 데이터 전달
          isEditing: true, // 수정 모드로 설정
        ),
      ),
    );
  }

  // 레코드 삭제 함수
  void _deleteRecord(String recordId, RecordDetail rec) async {
    try {
      await FirebaseFirestore.instance
          .collection('record')
          .doc(recordId)
          .update({
        'records': FieldValue.arrayRemove([rec.toMap()]),
      });
    } catch (e) {
      print('Error deleting sub-record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('레코드 삭제에 실패했습니다. 다시 시도해주세요.'),
        ),
      );
    }
  }

  Future<void> _deleteIndividualRecord(
      RecordModel record, RecordDetail rec) async {
    try {
      if (record.records.length == 1) {
        // 레코드에 하나의 콘텐츠만 있는 경우: 전체 레코드 삭제
        await FirebaseFirestore.instance
            .collection('record')
            .doc(record.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전체 레코드가 삭제되었습니다.')),
        );
      } else {
        // 레코드에 두 개 이상의 콘텐츠가 있는 경우: 해당 콘텐츠만 삭제
        record.records.remove(rec);

        // 업데이트된 기록을 Firestore에 저장
        await FirebaseFirestore.instance
            .collection('record')
            .doc(record.id)
            .update(record.toMap());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('개별 기록이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      print('Error deleting individual record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록 삭제에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(3.0),
            child: _buildRecordsSection(),
          ),
        ],
      ),
    ),
      bottomNavigationBar:
      Column(
      mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
      mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
      children: [
        if (userRole != 'admin' && userRole != 'paid_user')
          SafeArea(
            child: BannerAdWidget(),
          ),
      ],

    ),);
  }

  Widget _buildRecordsSection() {
    final theme = Theme.of(context);
    // Firestore 쿼리 필터링
    Query query = FirebaseFirestore.instance
        .collection('record')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true);

    // 검색 기간에 맞게 필터링
    if (startDate != null && endDate != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    // 카테고리 필터링 (모두가 아닌 경우에만 필터링 적용)
    if (selectedCategories != null &&
        selectedCategories!.isNotEmpty &&
        !selectedCategories!.contains('모두')) {
      query = query.where('zone', whereIn: selectedCategories);
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
          if (snapshot.hasError) {
            print('StreamBuilder Error: ${snapshot.error}');
            return Center(
              child: Text('일정 정보를 가져오지 못했습니다.',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('StreamBuilder: No data found');
            return Center(
              child: CircularProgressIndicator(), // 로딩 상태
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('StreamBuilder: No data found');
            return Center(
              child: Text('조건에 맞는 기록이 없습니다.',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }

          final recordsList = snapshot.data!.docs
              .map(
                (QueryDocumentSnapshot e) {
                  try {
                    return RecordModel.fromJson(
                      e.data() as Map<String, dynamic>,
                      id: e.id,
                    );
                  } catch (e) {
                    print('Error parsing record: $e');
                    return null; // 오류 발생 시 null 반환
                  }
                },
              )
              .where((record) => record != null)
              .toList();

          return ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: recordsList.length,
            itemBuilder: (context, index) {
              final record = recordsList[index];
              // 🔹 같은 unit을 그룹화
              Map<String, List<RecordDetail>> groupedRecords = {};
              for (var rec in record?.records ?? []) {
                if (!groupedRecords.containsKey(rec.unit)) {
                  groupedRecords[rec.unit] = [];
                }
                groupedRecords[rec.unit]?.add(rec);
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 컬러 바 추가
                        Container(
                          width: 4,
                          height: 50, // 컬러 바 높이
                          color: _convertColor(record?.color ?? '#FFFFFF'),
                        ),
                        SizedBox(width: 8), // 컬러 바와 텍스트 사이 간격

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔹 zone | 날짜 표시
                              Row(
                                children: [
                                  Text(
                                    record?.zone ?? 'Unknown zone',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface),
                                  ),
                                  SizedBox(width: 4),
                                  Text('|'),
                                  SizedBox(width: 4),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(record!.date!) ??
                                        'Unknown Date',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface),
                                  ),
                                ],
                              ),
                              SizedBox(height: 5),

                              // 🔹 unit | contents | 사진 묶어서 출력
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: groupedRecords.entries.map((entry) {
                                  final unit = entry.key; // 구분 (아침, 점심 등)
                                  final records = entry.value; // 같은 unit을 가진 기록들

                                  return InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReadRecord(
                                            recordId: record?.id ?? 'unknown',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 🔹 unit (아침, 점심 등) 제목
                                        Row(
                                          children: [
                                            Text(
                                              unit,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.colorScheme.onSurface),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                    
                                        // 🔹 같은 unit에 속하는 여러 개의 내용 출력
                                        ...records.map((rec) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                rec.contents ?? 'Unknown contents',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.onSurface),
                                              ),
                                              // 🔹 이미지 목록 출력
                                              if (rec.images != null && rec.images!.isNotEmpty)
                                                Wrap(
                                                  spacing: 8.0,
                                                  runSpacing: 4.0,
                                                  children: rec.images!.map((imageUrl) {
                                                    if (imageUrl.startsWith('https://') ||
                                                        imageUrl.startsWith('http://')) {
                                                      return Image.network(
                                                        imageUrl,
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return SizedBox(); // 🔹 오류 발생 시 아무것도 표시하지 않음
                                                        },
                                                      );
                                                    } else {
                                                      return Image.file(
                                                        File(imageUrl),
                                                        width: 50,
                                                        height: 50,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return SizedBox(); // 🔹 오류 발생 시 빈 컨테이너 반환
                                                        },
                                                      );
                                                    }
                                                  }).toList(),
                                                ),
                                              SizedBox(height: 5),
                                            ],
                                          );
                                        }).toList(),
                                        SizedBox(height: 10),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
