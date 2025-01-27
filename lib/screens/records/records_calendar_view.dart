import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/screens/records/read_record.dart';
import 'package:intl/intl.dart';
import 'package:food_for_later_new/models/record_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordsCalendarView extends StatefulWidget {
  @override
  _RecordsCalendarViewState createState() => _RecordsCalendarViewState();
}

class _RecordsCalendarViewState extends State<RecordsCalendarView> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

  List<RecordModel> recordsList = [];
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

  List<RecordModel>? getRecordsForDate(DateTime date) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(date);
    return recordsList.where((record) {
      DateTime recordDate;
      if (record.date is Timestamp) {
        recordDate = (record.date as Timestamp).toDate();
      } else {
        recordDate = record.date;
      }
      String formattedRecordDate = DateFormat('yyyy-MM-dd').format(recordDate);
      return formattedRecordDate == formattedDate;
    }).toList();
  }

  // 일주일 범위를 계산하는 함수
  List<DateTime> _getWeekDates(DateTime date) {
    int currentWeekday = date.weekday; // 현재 요일 (1: 월요일 ~ 7: 일요일)
    DateTime sunday =
        date.subtract(Duration(days: currentWeekday % 7)); // 일요일 계산
    List<DateTime> weekDates = List.generate(
        7, (index) => sunday.add(Duration(days: index))); // 일주일 생성
    return weekDates;
  }

  // Firestore 데이터를 RecordModel 리스트로 변환하는 함수
  List<RecordModel> _mapFirestoreToRecordsList(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return RecordModel.fromJson(data, id: doc.id); // RecordModel 생성
    }).toList();
  }

  // 이번 달의 일수를 반환하는 함수
  int _daysInMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(Duration(days: 1)).day;
  }

  int _firstDayOffset(DateTime date) {
    DateTime firstDayOfMonth = DateTime(date.year, date.month, 1);
    return firstDayOfMonth.weekday % 7; // 일요일을 0으로 맞추기 위해 % 7 적용
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Scaffold(
        body: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('데이터를 가져오는 중 오류가 발생했습니다.'),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
              // if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              //   return Center(
              //     child: Text('데이터가 없습니다.'),
              //   );
              // }
              // Firestore 데이터를 recordsList로 변환
              recordsList = _mapFirestoreToRecordsList(snapshot.data!);

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // 월과 년도 표시
                    Padding(
                      padding: const EdgeInsets.all(1.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () {
                              setState(() {
                                _focusedDate = DateTime(_focusedDate.year,
                                    _focusedDate.month - 1, 1);
                              });
                            },
                          ),
                          Text(
                            DateFormat.yMMM().format(_focusedDate),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () {
                              setState(() {
                                _focusedDate = DateTime(_focusedDate.year,
                                    _focusedDate.month + 1, 1);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // 달력 헤더 (요일 표시)
                    GridView.count(
                      crossAxisCount: 7,
                      childAspectRatio: 2, // 7열로 설정 (일~토)
                      shrinkWrap: true, // GridView 높이 조정
                      children: ["일", "월", "화", "수", "목", "금", "토"]
                          .map((day) => Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    // 날짜 그리드
                    GridView.builder(
                      itemCount: _daysInMonth(_focusedDate) +
                          _firstDayOffset(_focusedDate),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7, // 7열로 설정
                          mainAxisSpacing: 4.0,
                          crossAxisSpacing: 1.0,
                          childAspectRatio: 0.6),
                      shrinkWrap: true,
                      // GridView를 스크롤이 아닌 적절한 크기로 축소
                      // physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index < _firstDayOffset(_focusedDate)) {
                          return Container(); // 빈 컨테이너로 처리
                        } else {
                          // 실제 날짜를 렌더링
                          final day = index +
                              1 -
                              _firstDayOffset(
                                  _focusedDate); // 1일이 시작하는 요일만큼 오프셋 적용
                          final date = DateTime(
                              _focusedDate.year, _focusedDate.month, day);
                          bool isSelected = date == _selectedDate;
                          bool isToday = date.year == DateTime.now().year &&
                              date.month == DateTime.now().month &&
                              date.day == DateTime.now().day;
                          // 해당 날짜에 기록이 있는지 확인
                          List<RecordModel>? recordsForDate =
                              getRecordsForDate(date);
                          Color? backgroundColor;
                          String? contents;

                          if (recordsForDate != null &&
                              recordsForDate.isNotEmpty) {
                            // 기록이 있을 경우 첫 번째 기록의 색상과 타이틀을 사용
                            backgroundColor = Color(int.parse(recordsForDate
                                .first.color
                                .replaceFirst('#', '0xff')));
                            if (recordsForDate.isNotEmpty &&
                                recordsForDate.first.records.isNotEmpty) {
                              contents =
                                  recordsForDate.first.records.first.contents ??
                                      '내용이 없습니다';
                            } else {
                              contents = '내용이 없습니다';
                            }
                          }
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                  color:  isToday
                                          ? theme.colorScheme.secondary
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8.0),
                                  // borderColor: isSelected
                                  //     ? theme.colorScheme.secondary
                                  //     : Colors.transparent,
                                  border: isSelected
                                      ? Border.all(
                                          color: theme.colorScheme.secondary,
                                          width: 2.0)
                                      : null),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 날짜
                                      Text(
                                        '$day',
                                        style: TextStyle(
                                          color: isToday
                                                  ? Theme.of(context).colorScheme.onSecondary
                                                  : theme.colorScheme.onSurface,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (recordsForDate != null &&
                                          recordsForDate.isNotEmpty)
                                        Flexible(
                                          child: LimitedBox(
                                            maxHeight: 100.0,
                                            child: Scrollbar(
                                              child: ListView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      ClampingScrollPhysics(),
                                                  itemCount:
                                                      recordsForDate.length,
                                                  itemBuilder:
                                                      (context, recordIndex) {
                                                    final record =
                                                        recordsForDate[
                                                            recordIndex];
                                                    final recordColor = Color(
                                                      int.parse(record.color
                                                          .replaceFirst(
                                                              '#', '0xff')),
                                                    );
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: record.records
                                                          .map<Widget>((rec) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        ReadRecord(
                                                                  recordId:
                                                                      record
                                                                          .id!,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          child: Container(
                                                            // margin: EdgeInsets
                                                            //     .symmetric(
                                                            //         vertical:
                                                            //             2.0),
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                              horizontal: 4.0,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  recordColor, // 개별 record의 색상 적용
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4.0),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    rec.contents ??
                                                                        '내용이 없습니다',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            8,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSecondary),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    maxLines: 1,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    );
                                                  }),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    _buildWeekContainer(),
                  ],
                ),
              );
            }),
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

      ),

    );
  }

// 선택된 날짜 기준으로 일주일을 렌더링하는 함수
  Widget _buildWeekContainer() {
    List<DateTime> weekDates = _getWeekDates(_selectedDate);

    return Container(
      child: ListView.builder(
        shrinkWrap: true, // ListView가 자식에 맞게 크기를 조정
        physics: NeverScrollableScrollPhysics(), // 부모 스크롤에 맞게 비활성화
        itemCount: weekDates.length,
        itemBuilder: (context, index) {
          DateTime date = weekDates[index];
          List<RecordModel>? recordsForDate = getRecordsForDate(date);
          return Container(
              margin: EdgeInsets.symmetric(vertical: 5.0),
              constraints: BoxConstraints(
                minHeight: 100, // 각 컬럼의 최소 높이 설정
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary, // 배경을 흰색으로 설정
                borderRadius: BorderRadius.circular(10), // 둥근 모서리
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5), // 그림자 색상
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // 그림자의 위치
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('E').format(date)}  ${date.day}',
                        // 요일과 날짜 출력
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      if (recordsForDate != null && recordsForDate.isNotEmpty)
                        ...recordsForDate.map((record) {
                          return Column(
                            children: record.records.map<Widget>((rec) {
                              // if (rec is Map<String, dynamic> && rec.containsKey('images')) {
                              //   List<String> images = rec['images'];
                              return GestureDetector(
                                onTap: () {
                                  // if (recordsList.indexOf(record) >= 0 &&
                                  //     recordsList.indexOf(record) <
                                  //         recordsList.length) {
                                  // Map<String, dynamic> recordData = {
                                  //   'record': record, // 상위 레코드
                                  //   'rec': rec, // 개별 레코드
                                  // };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReadRecord(
                                        recordId:
                                            record.id ?? 'default_record_id',
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    _buildImageWidget(rec.images),
                                    SizedBox(width: 15),
                                    Text(
                                      rec.contents ?? '내용이 없습니다',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ));
        },
      ),
    );
  }

  Widget _buildImageWidget(List<String> images) {
    if (images.isEmpty) {
      return Icon(Icons.image,
          size: 55, color: Theme.of(context).colorScheme.onSecondary);
    }
    String imageUrl = images[0];
    if (Uri.parse(imageUrl).isAbsolute) {
      // 네트워크 URL인 경우
      return Image.network(
        imageUrl,
        height: 50,
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image,
              size: 55, color: Theme.of(context).colorScheme.onSecondary);
        },
      );
    } else {
      // 로컬 파일인 경우
      return Image.file(
        File(imageUrl),
        height: 50,
        width: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image,
              size: 55, color: Theme.of(context).colorScheme.onSecondary);
        },
      );
    }
  }
}
