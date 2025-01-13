import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/screens/records/read_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/record_model.dart';

class RecordsAlbumView extends StatefulWidget {
  @override
  _RecordsAlbumViewState createState() => _RecordsAlbumViewState();
}

class _RecordsAlbumViewState extends State<RecordsAlbumView> {
  DateTime? startDate;
  DateTime? endDate;
  List<String>? selectedCategories;
  bool isLoading = true; // 데이터를 불러오는 중 상태 표시
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

  Map<String, dynamic>? _findRecordByImage(
      List<RecordModel> recordsList, String imagePath) {
    for (var record in recordsList) {
      for (var rec in record.records) {
        if (rec.images.contains(imagePath)) {
          return {
            'record': record, // 상위 레코드
            'rec': rec // 해당 이미지가 포함된 개별 레코드
          };
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Firestore 쿼리 필터링
    Query query = FirebaseFirestore.instance.collection('record');
    if (userId != null) {
      query = query
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true);
    }

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

          return _buildImageGrid(recordsList);
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

      ),
    );
  }

  Widget _buildImageGrid(List<RecordModel> recordsList) {
    List<String> allImages = [];
    for (var record in recordsList) {
      for (var rec in record.records) {
        allImages.addAll(List<String>.from(rec.images));
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 1줄에 4개씩 나열
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
        childAspectRatio: 1, // 정사각형으로 만듦
      ),
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        String imageUrl = allImages[index];
        // 수정된 부분: 리턴 타입이 Map<String, dynamic>이므로 각각에 접근
        final recordMap = _findRecordByImage(recordsList, imageUrl);
        final RecordModel? record = recordMap?['record'];
        final RecordDetail? rec = recordMap?['rec'];

        return GestureDetector(
          onTap: () {
            if (record != null) {
              // print("Found recordsList: ${record}");
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReadRecord(
                    recordId: record.id ?? 'default_record_id',
                  ),
                ),
              );
            }
          },
          child: _buildImageWidget(imageUrl),
        );
      },
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    if (Uri.parse(imageUrl).isAbsolute) {
      // 네트워크 URL인 경우
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image, size: 50);
        },
      );
    } else if (!kIsWeb) {
      // 로컬 파일 경로인 경우
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image, size: 50);
        },
      );
    } else {
      // 웹 환경에서 로컬 파일 경로가 주어진 경우
      return Icon(Icons.broken_image, size: 50); // 기본 아이콘 반환
    }
  }
}
