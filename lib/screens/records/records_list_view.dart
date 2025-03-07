import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/models/record_model.dart';
import 'package:food_for_later_new/screens/records/read_record.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, bool> categoryOptions = {};

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadCategoryOptions();
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

    final startDateString = prefs.getString('startDate');
    final endDateString = prefs.getString('endDate');
    final localSelectedCategories = prefs.getStringList('selectedCategories') ?? [];

    setState(() {
      selectedCategories = localSelectedCategories.isNotEmpty ? localSelectedCategories : ['모두'];

      // 저장된 카테고리가 없거나, 모든 카테고리가 선택된 상태면 "모두" 추가
      if (categoryOptions.isEmpty ||(selectedCategories?.length ?? 0) == categoryOptions.length) {
        selectedCategories = ['모두'];
      }

      startDate = startDateString != null && startDateString.isNotEmpty
          ? DateTime.parse(startDateString)
          : null;
      endDate = endDateString != null && endDateString.isNotEmpty
          ? DateTime.parse(endDateString)
          : null;
      isLoading = false; // 로딩 완료
    });

    print("🟢 SharedPreferences 로드됨: startDate = $startDate, endDate = $endDate, selectedCategories = $selectedCategories");
  }
  /// 🔹 Firestore에서 카테고리 목록을 불러와 `categoryOptions` 초기화
  Future<void> _loadCategoryOptions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('record_categories')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false) // 삭제되지 않은 카테고리만 불러오기
          .orderBy('order')  // 정렬 기준 적용
          .get();

      setState(() {
        categoryOptions = {
          for (var doc in snapshot.docs) doc['zone']: true, // 카테고리 추가
        };

        // 🔹 "모두" 추가 (기본값: 모든 카테고리 선택)
        categoryOptions['모두'] = categoryOptions.isNotEmpty;
      });

      print("🟢 Firestore에서 카테고리 로드 완료: ${categoryOptions.keys.toList()}");
    } catch (e) {
      print("❌ Firestore 카테고리 로드 실패: $e");
    }
  }

  // Query getFilteredQuery() {
  //   print("📢 getFilteredQuery() 실행됨");
  //   Query query = FirebaseFirestore.instance
  //       .collection('record')
  //       .where('userId', isEqualTo: userId)
  //       .orderBy('date', descending: true);
  //
  //   // 검색 기간 필터링
  //   if (startDate != null && endDate != null) {
  //     query = query
  //         .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
  //         .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
  //   }
  //
  //   // selectedCategories가 없거나 비어있는 경우 기본값 설정
  //   if (selectedCategories == null || selectedCategories!.isEmpty) {
  //     selectedCategories = ['모두'];
  //   }
  //
  //   // 카테고리 필터링 (모두가 아닌 경우에만)
  //   if (!selectedCategories!.contains('모두')) {
  //     query = query.where('zone', whereIn: selectedCategories);
  //     print("✅ 카테고리 필터 적용: ${selectedCategories!.join(', ')}");
  //   } else {
  //     print("🟢 '모두' 선택됨 → 전체 데이터 검색");
  //   }
  //
  //   return query;
  // }

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

  Query getFilteredQuery() {
    print("📢 getFilteredQuery() 실행됨");

    Query query = FirebaseFirestore.instance
        .collection('record')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true);

    print("✅ 기본 쿼리 실행: userId = $userId");

    // 검색 기간 필터링
    if (startDate != null && endDate != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
      print("✅ 날짜 필터 적용: $startDate ~ $endDate");
    }

    // selectedCategories가 없거나 비어있는 경우 기본값 설정
    if (selectedCategories == null || selectedCategories!.isEmpty) {
      selectedCategories = ['모두'];
    }

    // 카테고리 필터링 (모두가 아닌 경우에만)
    if (!selectedCategories!.contains('모두')) {
      query = query.where('zone', whereIn: selectedCategories);
      print("✅ 카테고리 필터 적용: ${selectedCategories!.join(', ')}");
    } else {
      print("🟢 '모두' 선택됨 → 전체 데이터 검색");
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    print("📢 build() 실행됨");
    final theme = Theme.of(context);
    // Firestore 쿼리 필터링
    // Query query = FirebaseFirestore.instance
    //     .collection('record')
    //     .where('userId', isEqualTo: userId)
    //     .orderBy('date', descending: true);
    //
    // // 검색 기간에 맞게 필터링
    // if (startDate != null && endDate != null) {
    //   query = query
    //       .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
    //       .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    // }
    //
    // // 카테고리 필터링 (모두가 아닌 경우에만 필터링 적용)
    // if (selectedCategories != null &&
    //     selectedCategories!.isNotEmpty &&
    //     !selectedCategories!.contains('모두')) {
    //   query = query.where('zone', whereIn: selectedCategories);
    // }
    // // 실행될 쿼리 확인
    // print("Firestore Query 실행: userId = $userId, selectedCategories = $selectedCategories, startDate = $startDate, endDate = $endDate");

    return Scaffold(
        body: StreamBuilder<QuerySnapshot>(
        stream: getFilteredQuery().snapshots(),
    builder: (context, snapshot) {
      print("📢 StreamBuilder 실행됨");

      if (snapshot.connectionState == ConnectionState.waiting) {
        print("⏳ 데이터 로딩 중...");
        return Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        print("❌ 오류 발생: ${snapshot.error}");
        return Center(child: Text('데이터를 가져오는 중 오류가 발생했습니다.'));
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('나의 요리생활을 기록해주세요.', style: TextStyle(color: theme.colorScheme.onSurface)),
              Text('리스트 형태로 보여드립니다.', style: TextStyle(color: theme.colorScheme.onSurface)),
            ],
          ),
        );
      }
      if (snapshot.hasError) {
        return Center(child: Text('데이터를 가져오는 중 오류가 발생했습니다.'));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      final recordsList = snapshot.data!.docs.map((doc) {
        return RecordModel.fromJson(
          doc.data() as Map<String, dynamic>,
          id: doc.id,
        );
      }).toList();

      return _buildRecordsSection(recordsList);

    },
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

  Widget _buildRecordsSection(List<RecordModel> recordsList) {
    final theme = Theme.of(context);
    // Firestore 쿼리 필터링
    // Query query = FirebaseFirestore.instance
    //     .collection('record')
    //     .where('userId', isEqualTo: userId)
    //     .orderBy('date', descending: true);
    if (recordsList.isEmpty) {
      return Center(
        child: Text('기록이 없습니다.', style: TextStyle(color: theme.colorScheme.onSurface)),
      );
    }
    List<dynamic> resultsWithAds = [];
    int adFrequency = 5; // 광고를 몇 개마다 넣을지 설정

    for (int i = 0; i < recordsList.length; i++) {
      resultsWithAds.add(recordsList[i]);
      if ((i + 1) % adFrequency == 0) {
        resultsWithAds.add('ad'); // 광고 위치를 표시하는 문자열
      }
    }

    return ListView.builder(
      itemCount: resultsWithAds.length,
      itemBuilder: (context, index) {
        if (resultsWithAds[index] == 'ad') {
          // 광고 위젯
          if (userRole != 'admin' && userRole != 'paid_user') {
            return SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            );
          }
          return SizedBox.shrink(); // 광고 비활성화 시 빈 공간 제거
        }

        final record = resultsWithAds[index] as RecordModel;

        // 🔹 같은 unit을 그룹화
        Map<String, List<RecordDetail>> groupedRecords = {};
        for (var rec in record.records ?? []) {
          if (!groupedRecords.containsKey(rec.unit)) {
            groupedRecords[rec.unit] = [];
          }
          groupedRecords[rec.unit]?.add(rec);
        }
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 8), // 컬러 바와 텍스트 사이 간격

                  Expanded(
                    child: Column(
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
                                        Text('|',
                                          style: TextStyle(
                                              color: theme.colorScheme.onSurface
                                          ),),
                                        SizedBox(width: 4),
                                        Text(
                                          record?.date != null
                                              ? DateFormat('yyyy-MM-dd').format(record!.date!)
                                              : 'Unknown Date',
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
                                              ...records.map((rec) {
                                                return Column(
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
                                                  SizedBox( width: 4),
                                                  Text(
                                                    '|',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: theme.colorScheme.onSurface),
                                                  ),
                                                  SizedBox( width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      rec.contents ?? 'Unknown contents',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: theme.colorScheme.onSurface),
                                                      overflow: TextOverflow.ellipsis, // 👉 텍스트가 길면 "..."으로 표시
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
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
                    ),
                  ),
                ],
              )
        );
      },
    );
  }
}
