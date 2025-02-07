import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:food_for_later_new/models/recipe_model.dart';
import 'package:food_for_later_new/screens/recipe/full_screen_image_view.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';
import 'package:food_for_later_new/screens/recipe/recipe_webview_page.dart';
import 'package:food_for_later_new/screens/records/create_record.dart';
import 'package:food_for_later_new/screens/records/view_record_main.dart';
import 'package:food_for_later_new/services/scraped_recipe_service.dart';
import 'package:intl/intl.dart';
import '../../models/record_model.dart';
import 'package:uuid/uuid.dart';

class ReadRecord extends StatefulWidget {
  final String recordId; // recordId를 전달받도록 수정

  ReadRecord({required this.recordId});

  @override
  _ReadRecordState createState() => _ReadRecordState();
}

class _ReadRecordState extends State<ReadRecord> {
  Map<String, List<String>> categoryMap = {};
  List<Map<String, dynamic>> recentlyDeletedRecords = [];
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isScraped = false;

  @override
  void initState() {
    super.initState();
    _fetchRecordCategories(); // 초기화 시 record_categories 불러오기
    _loadUserRole();
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
  Future<Map<String, dynamic>> loadScrapedData(String recipeId,
      {String? link}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (link != null) {
        // 🔹 웹 레시피의 경우 link로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('link', isEqualTo: link)
            .get();
      } else {
        // 🔹 Firestore 레시피의 경우 recipeId로 확인
        snapshot = await FirebaseFirestore.instance
            .collection('scraped_recipes')
            .where('userId', isEqualTo: userId)
            .where('recipeId', isEqualTo: recipeId)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'isScraped': data['isScraped'] ?? false,
          'scrapedGroupName': data['scrapedGroupName'] ?? '기본함'
        };
      } else {
        return {'isScraped': false, 'scrapedGroupName': '기본함'};
      }
    } catch (e) {
      print("Error fetching recipe data: $e");
      return {'isScraped': false, 'scrapedGroupName': '기본함'};
    }
  }

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


  // Firestore에서 해당 기록을 삭제하는 함수
  Future<void> _deleteRecord(String recordId) async {
    try {
      // Firestore에서 삭제 전 레코드 정보를 불러와서 저장
      final recordSnapshot = await FirebaseFirestore.instance
          .collection('record')
          .doc(recordId)
          .get();

      if (recordSnapshot.exists) {
        final recordData = recordSnapshot.data();
        if (recordData != null) {
          recentlyDeletedRecords.add({
            'recordId': recordId,
            'recordData': recordData, // 레코드의 모든 데이터 저장
          });
        }
      }
      await FirebaseFirestore.instance
          .collection('record')
          .doc(recordId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('기록이 삭제되었습니다.'),
          action: SnackBarAction(
            label: '복원',
            onPressed: _restoreDeletedRecord, // 복원 로직 연결
          ),
        ),
      );
      Navigator.pop(context); // 기록 삭제 후 이전 화면으로 돌아가기
    } catch (e) {
      print('Error deleting record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('기록 삭제에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }
  void _restoreDeletedRecord() async {
    if (recentlyDeletedRecords.isNotEmpty) {
      final lastDeletedRecord = recentlyDeletedRecords.removeLast(); // 마지막 삭제된 항목 가져오기
      final recordId = lastDeletedRecord['recordId'];
      final recordData = lastDeletedRecord['recordData'];

      try {
        // Firestore에 레코드 복원
        await FirebaseFirestore.instance
            .collection('record')
            .doc(recordId)
            .set(recordData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록이 복원되었습니다.')),
        );
      } catch (e) {
        print('Error restoring record: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록 복원에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }
  void _openRecipeLink(String link, String title, RecipeModel recipe, bool initialScraped) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeWebViewPage(
          link: link,
          title: title,
          recipe: recipe,
          initialScraped: initialScraped,
          onToggleScraped: toggleScraped,         // 기존의 toggleScraped 함수 사용
          onSaveRecipeForTomorrow: _saveRecipeForTomorrow, // 기존의 _saveRecipeForTomorrow 함수 사용
        ),
      ),
    );
  }

  Future<bool> toggleScraped(String recipeId, String? link) async {
    bool newState = await ScrapedRecipeService.toggleScraped(
      context,
      recipeId,
      link,
    );
    return newState; // 또는 비동기 작업 결과로 반환
  }

  DateTime getTomorrowDate() {
    return DateTime.now().add(Duration(days: 1));
  }
  void _saveRecipeForTomorrow(RecipeModel recipe) async {
    try {
      // 기존의 fetchRecipeData 대신 recipe 객체의 데이터를 사용합니다.
      var recipeData = {
        'recipeName': recipe.recipeName,
        'mainImages': recipe.mainImages,
      };

      // 내일 날짜로 저장
      DateTime tomorrow = getTomorrowDate().toUtc();

      // records 배열 구성
      List<Map<String, dynamic>> records = [
        {
          'unit': '레시피 보기',  // 고정값 혹은 다른 값으로 대체 가능
          'contents': recipeData['recipeName'] ?? 'Unnamed Recipe',
          'images': recipeData['mainImages'] ?? [], // 이미지 배열
          'link': recipe.link,
          'recipeId': recipe.id,
        }
      ];

      // 저장할 데이터 구조 정의
      Map<String, dynamic> recordData = {
        'id': Uuid().v4(),  // 고유 ID 생성
        'date': Timestamp.fromDate(tomorrow),
        'userId': userId,
        'color': '#88E09F',  // 고정된 색상 코드 또는 동적 값 사용 가능
        'zone': '레시피',  // 고정값 또는 다른 값으로 대체 가능
        'records': records,
      };

      // Firestore에 저장
      await FirebaseFirestore.instance.collection('record').add(recordData);

      // 저장 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레시피가 내일 날짜로 기록되었습니다.'),
          action: SnackBarAction(
            label: '기록 보기',
            onPressed: () {
              // 기록 페이지로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewRecordMain(),
                ),
              );
            },
          ),),
      );
    } catch (e) {
      print('레시피 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레시피 저장에 실패했습니다. 다시 시도해주세요.')
        ),
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
          TextButton(
            child: Text('삭제'),
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
                      '${record.zone ?? ''} 기록',
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
                    return GestureDetector(
                      onTap: () async {
                        if (rec.unit == '레시피 보기') {
                          final recipeId = rec.recipeId ?? '';

                          final RecipeModel recipe = RecipeModel(
                            id: recipeId,
                            recipeName: rec.contents ?? '',
                            link: rec.link ?? '',
                            mainImages: List<String>.from(rec.images ?? []),
                            rating: 0.0,
                            userID: userId,
                            difficulty: '',
                            serving: 0,
                            time: 0,
                            foods: <String>[],
                            themes: <String>[],
                            methods: <String>[],
                            steps: <Map<String, String>>[],
                            date: DateTime.now(),
                          );

                          final Map<String, dynamic> scrapedData = await loadScrapedData(recipe.id, link: recipe.link);
                          bool initialScraped = scrapedData['isScraped'] ?? false;

                          if ((rec.link ?? '').isNotEmpty) {
                            _openRecipeLink(rec.link ?? '', rec.contents, recipe, initialScraped);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadRecipe(
                                  recipeId: recipe.id,
                                  searchKeywords: [],
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Padding(
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
                                    overflow: TextOverflow.ellipsis
                                ),
                                Text(
                                  ' | ',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface),
                                    overflow: TextOverflow.ellipsis
                                ),
                                Expanded(
                                  child: Text(
                                    rec.contents ?? 'No description',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: theme.colorScheme.onSurface),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: rec.images.map((imagePath) {
                                  // 원격 이미지 URL일 경우
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullScreenImageView(
                                            images: rec.images,
                                            initialIndex: index,
                                          ),
                                        ),
                                      );
                                    },
                                    child:  Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: _buildImageWidget(imagePath),
                                    ),
                                  );
                      
                              }).toList(),
                            ),
                            Divider(),
                          ],
                        ),
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
  String getValidImagePath(String imagePath) {
    try {
      // 네트워크 경로 (https://)일 경우 유효한 것으로 간주
      if (imagePath.startsWith('http') || imagePath.startsWith('https')) {
        return imagePath;
      }

      // 로컬 경로일 경우 실제 파일이 존재하는지 확인
      final file = File(imagePath);
      if (file.existsSync()) {
        return imagePath;
      } else {
        print('유효하지 않은 로컬 경로: $imagePath');
        return ''; // 유효하지 않은 로컬 경로
      }
    } catch (e) {
      print('경로 확인 중 오류 발생: $e');
      return '';
    }
  }
  Widget _buildImageWidget(String imagePath, {bool fullScreen = false}) {
    final imageSize = fullScreen ? double.infinity : 60.0;
    final fitMode = fullScreen ? BoxFit.contain : BoxFit.cover;
    imagePath = getValidImagePath(imagePath);

    if (imagePath.isEmpty) {
      return Container(
        width: imageSize,
        height: imageSize,
        color: Colors.grey,
        child: Center(child: Text('Invalid Image Path')),
      );
    }
    print(File(imagePath).existsSync());
    if (Uri.parse(imagePath).isAbsolute) {
      return Image.network(
        imagePath,
        width: imageSize,
        height: imageSize,
        fit: fitMode,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: imageSize),
      );
    } else if (!kIsWeb && File(imagePath).existsSync()) {
      return Image.file(
        File(imagePath),
        width: imageSize,
        height: imageSize,
        fit: fitMode,
        errorBuilder: (context, error, stackTrace) => Text('Error loading image'),
      );
    } else {
      return Container(
        width: imageSize,
        height: imageSize,
        color: Colors.grey,
        child: Center(child: Text('Invalid Image Path')),
      );
    }
  }
}
