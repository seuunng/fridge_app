import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/screens/records/create_record.dart';
import 'package:intl/intl.dart';
import '../../models/record_model.dart';

class ReadRecord extends StatefulWidget {
  final String recordId; // recordId를 전달받도록 수정

  ReadRecord({required this.recordId});

  @override
  _ReadRecordState createState() => _ReadRecordState();
}

class _ReadRecordState extends State<ReadRecord> {
  Map<String, List<String>> categoryMap = {};

  Future<void> _fetchRecordCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('record_categories')
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          categoryMap = {
            for (var doc in snapshot.docs)
              doc.data()['zone']: List<String>.from(doc.data()['units']),
          };
        });
      }
    } catch (e) {
      print('Error loading record categories: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRecordCategories(); // 초기화 시 record_categories 불러오기
  }

  // Firestore에서 해당 기록을 삭제하는 함수
  Future<void> _deleteRecord(String recordId) async {
    try {
      await FirebaseFirestore.instance
          .collection('record')
          .doc(recordId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록이 삭제되었습니다.')),
      );
      Navigator.pop(context); // 기록 삭제 후 이전 화면으로 돌아가기
    } catch (e) {
      print('Error deleting record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록 삭제에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('기록 보기'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete,
            ),
            onPressed: () {
              // 삭제 버튼을 누르면 다이얼로그 표시
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    '기록 삭제',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  content: Text(
                    '이 기록을 삭제하시겠습니까?',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('취소'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteRecord(widget.recordId); // 삭제 함수 호출
                      },
                      child: Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(
            width: 20,
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('record')
            .doc(widget.recordId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('데이터를 가져오는 중 오류가 발생했습니다.',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }
          // Firestore 데이터를 RecordModel로 변환
          final recordData =
              snapshot.data?.data() as Map<String, dynamic>? ?? {};

          final record = RecordModel.fromJson(recordData,
              id: snapshot.data?.id ?? 'unknown');

          if (record.records.isEmpty) {
            print('레코드가 비어 있습니다.');
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text('데이터가 없습니다.',
                  style: TextStyle(color: theme.colorScheme.onSurface)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(record.date) ??
                          'Unknown Date',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      ' | ',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                    Text(
                      '${record.zone} 기록',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: record.records.length,
                  itemBuilder: (context, index) {
                    final rec = record.records[index];
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rec.unit ?? 'Unknown Field',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface),
                              ),
                              Text(
                                ' | ',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface),
                              ),
                              Text(
                                rec.contents ?? 'No description',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: rec.images.map((imagePath) {
                              if (Uri.parse(imagePath).isAbsolute) {
                                // 원격 이미지 URL일 경우
                                return Image.network(
                                  imagePath,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.broken_image, size: 60);
                                  },
                                );
                              } else if (!kIsWeb &&
                                  File(imagePath).existsSync()) {
                                // 로컬 이미지 파일 경로일 경우
                                return Image.file(
                                  File(imagePath),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text('Error loading image');
                                  },
                                );
                              } else {
                                // 알 수 없는 경로의 경우, 기본 이미지나 안내 텍스트 표시
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey,
                                  child:
                                      Center(child: Text('Invalid Image Path')),
                                );
                              }
                            }).toList(),
                          ),
                          Divider(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                color: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: NavbarButton(
                    buttonTitle: '수정하기',
                    onPressed: () async {
                      final updatedRecord = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateRecord(
                            recordId: widget.recordId, // 초기 데이터 전달
                            isEditing: true, // 수정 모드로 설정
                          ),
                        ),
                      );

                      if (updatedRecord != null) {
                        // 수정된 데이터가 돌아오면 처리
                        // 현재 화면을 업데이트하거나 데이터를 반영하는 작업
                      }
                    },
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
