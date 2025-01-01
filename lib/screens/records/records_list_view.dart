import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSearchSettingsFromLocal(); // SharedPreferences에서 검색 조건 불러오기
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
    ));
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
              return Column(
                  children:
                      List.generate(record?.records.length ?? 0, (recIndex) {
                final rec = record?.records[recIndex];
                return Dismissible(
                  key: Key('${record?.id}_$recIndex'),
                  // 고유한 키
                  direction: DismissDirection.horizontal,
                  // 좌우 스와이프 가능
                  background: Container(
                    color: Colors.green, // 왼쪽 스와이프 시 수정 표시
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white),
                        Text(' 수정', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  secondaryBackground: Container(
                    color: Colors.red, // 오른쪽 스와이프 시 삭제 표시
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(' 삭제', style: TextStyle(color: Colors.white)),
                        Icon(Icons.delete, color: Colors.white),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // 왼쪽 스와이프 시 수정 확인 창
                      _editRecord(record?.id ?? 'default_record_id', rec!);
                      return false; // true로 설정하면 수정 기능 후에도 항목이 사라짐
                    } else if (direction == DismissDirection.endToStart) {
                      // 오른쪽 스와이프 시 삭제 확인 창
                      final bool? result = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('삭제 확인'),
                            content: Text('정말 삭제하시겠습니까?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                                child: Text('취소'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                                child: Text('삭제'),
                              ),
                            ],
                          );
                        },
                      );
                      return result;
                    }
                    return false;
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      // 레코드가 2개 이상일 때, 해당 레코드만 삭제
                      if ((record?.records.length ?? 0) > 1) {
                        _deleteIndividualRecord(record!, rec!).then((_) {
                          setState(() {
                            record.records.remove(rec); // 삭제 후 로컬 데이터 즉시 갱신
                          });
                        });
                      } else {
                        // 레코드가 1개일 때, 전체 레코드 삭제
                        _deleteRecord(record?.id ?? 'default_record_id', rec!);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('레코드가 삭제되었습니다.')),
                      );
                      setState(() {
                        // 리스트에서 레코드를 제거
                        record?.records.removeAt(recIndex);

                        // recordsList에서 항목이 비어 있는 경우 제거
                        if (record?.records.isEmpty ?? false) {
                          FirebaseFirestore.instance
                              .collection('record')
                              .doc(record.id)
                              .delete();
                          recordsList.removeAt(index);
                        }
                      });
                    }
                  },
                  child: InkWell(
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 컬러 바 추가
                          Container(
                            width: 4,
                            height: 50, // 컬러 바의 높이 설정
                            color: _convertColor(record?.color ?? '#FFFFFF'),
                          ),
                          SizedBox(width: 8), // 컬러 바와 텍스트 사이 간격

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      DateFormat('yyyy-MM-dd')
                                              .format(record!.date!) ??
                                          'Unknown Date',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      rec?.unit ?? 'Unknown Unit',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                    SizedBox(width: 4),
                                    Text('|',
                                        style: TextStyle(
                                            color:
                                                theme.colorScheme.onSurface)),
                                    SizedBox(width: 4),
                                    Text(
                                      rec?.contents ?? 'Unknown contents',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: rec?.images?.map((imageUrl) {
                                        if (imageUrl.startsWith('https://') ||
                                            imageUrl.startsWith('http://')) {
                                          // Firebase Storage URL이면 NetworkImage 사용
                                          return Image.network(
                                            imageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Text(
                                                  'Error loading image');
                                            },
                                          );
                                        } else {
                                          // 로컬 파일 경로이면 FileImage 사용
                                          return Image.file(
                                            File(imageUrl),
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Text(
                                                  'Error loading image');
                                            },
                                          );
                                        }
                                      }).toList() ??
                                      [], //s가 null일 경우 빈 컨테이너를 표시
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }));
            },
          );
        },
      ),
    );
  }
}
