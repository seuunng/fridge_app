import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';

class FeedbackSubmission extends StatefulWidget {
  final String? postType; // 게시물 유형 (레시피, 리뷰)
  final String? postNo; // 게시물 ID (레시피 ID, 리뷰 ID)

  FeedbackSubmission({this.postType, this.postNo});

  @override
  _FeedbackSubmissionState createState() => _FeedbackSubmissionState();
}

class _FeedbackSubmissionState extends State<FeedbackSubmission> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String userRole = '';

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? postTitle;

  // 🔹 "제안"과 "신고"를 위한 라디오 버튼 선택 변수
  String _selectedType = '제안'; // 기본값은 "제안"

  // 🔹 "제안" 선택 시 드롭다운
  String _selectedCategoryProposal = '수정 제안'; // 기본 선택값
  final List<String> _categoriesProposal = [
    '오류 수정 제안',
    '기능 수정 제안',
    '기능 신설 요청'
  ]; // "제안" 드롭다운 리스트

  // 🔹 "신고" 선택 시 드롭다운
  String _selectedCategoryReport = '불법'; // 기본 선택값
  final List<String> _categoriesReport = ['불쾌', '불법', '유해']; // "신고" 드롭다운 리스트

  @override
  void initState() {
    super.initState();
    if (widget.postType != null && widget.postType!.isNotEmpty) {
      _selectedType = '신고';
    } else {
      _selectedType = '제안';
    }
    fetchPostTitle(); // 🔹 레시피명 또는 리뷰내용 가져오기
  }
  // 🔹 postNo를 이용해 Firestore에서 데이터 가져오기
  Future<void> fetchPostTitle() async {
    if (widget.postNo == null || widget.postNo!.isEmpty) return;

    try {
      DocumentSnapshot doc;
      if (widget.postType == '레시피') {
        doc = await _db.collection('recipe').doc(widget.postNo).get();
        setState(() {
          postTitle = doc.exists ? doc['recipeName'] : '알 수 없는 레시피';
        });
      } else if (widget.postType == '리뷰') {
        doc = await _db.collection('recipe_reviews').doc(widget.postNo).get();
        setState(() {
          postTitle = doc.exists ? doc['content'] : '알 수 없는 리뷰';
        });
      }
    } catch (e) {
      setState(() {
        postTitle = '데이터를 불러올 수 없음';
      });
    }
  }
  // 의견 제출 함수
  void _submitFeedback() async {
    String content = _contentController.text;
    String selectedCategory = _selectedType == '제안'
        ? _selectedCategoryProposal
        : _selectedCategoryReport;

    // 입력값을 처리하는 로직을 여기에 추가 (예: 서버로 전송 또는 로컬 저장)
    if (content.isNotEmpty) {
      try {
        // Firestore에 데이터 저장
        DocumentReference docRef = await _db.collection('feedback').add({
          // 'title': title,
          'content': content,
          'feedbackType': _selectedType, // 🔹 선택한 구분 (제안 or 신고)
          'category': selectedCategory,
          'timestamp': FieldValue.serverTimestamp(), // 서버 시간을 저장
          'postType': widget.postType ?? '의견보내기',
          'postNo': widget.postNo ?? '',
          'author': userId,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('의견이 성공적으로 전송되었습니다!')),
        );

        _titleController.clear();
        _contentController.clear();
        Navigator.pop(context);
      } catch (e) {
        // 오류 발생 시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('의견 전송 중 오류가 발생했습니다. 다시 시도해주세요.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제목과 내용을 모두 입력해주세요!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('의견보내기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Text(
                  '구분',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                ),
                SizedBox(width: 30),
                Expanded(
                  child: ListTile(
                    title: Text('제안',
                        style: TextStyle(color: theme.colorScheme.onSurface)),
                    leading: Radio<String>(
                      value: '제안',
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ),
                ), // 텍스트와 드롭다운 사이 간격
                Expanded(
                  child: ListTile(
                    title: Text('신고',
                        style: TextStyle(color: theme.colorScheme.onSurface)),
                    leading: Radio<String>(
                      value: '신고',
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            // 🔹 "제안"을 선택했을 때만 "수정 제안, 기능 요청" 드롭다운 표시
            if (_selectedType == '제안') ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '제안 종류',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _categoriesProposal
                              .contains(_selectedCategoryProposal)
                          ? _selectedCategoryProposal
                          : (_categoriesProposal.isNotEmpty
                              ? _categoriesProposal.first
                              : null),
                      isExpanded: true, // 드롭다운 너비 확장
                      items: _categoriesProposal.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategoryProposal = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],

            // 🔹 "신고"를 선택했을 때만 "불쾌, 오류, 불법, 스팸, 유해" 드롭다운 표시
            if (_selectedType == '신고') ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '신고 유형',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                  Spacer(),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _categoriesReport.contains(_selectedCategoryReport)
                          ? _selectedCategoryReport
                          : (_categoriesProposal.isNotEmpty
                              ? _categoriesProposal.first
                              : null),
                      isExpanded: true, // 드롭다운 너비 확장
                      items: _categoriesReport.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category,
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                              )
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategoryReport = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Text(
                '신고대상',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
              ),
              Text(
                '[${widget.postType ?? ''}] ${postTitle}',
                style:
                    TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
              ),
            ],
            SizedBox(height: 16),
            Text(
              '의견',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
            ),
            TextField(
              controller: _contentController,
              style:
                  TextStyle(color: theme.colorScheme.onSurface), // 입력 텍스트 스타일
              decoration: InputDecoration(
                hintText: '내용을 입력하세요',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface
                      .withOpacity(0.6), // 힌트 텍스트 스타일
                ),
              ),
              maxLines: 5, // 여러 줄 입력 가능
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Column이 최소한의 크기만 차지하도록 설정
        mainAxisAlignment: MainAxisAlignment.end, // 하단 정렬
        children: [
          Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: NavbarButton(
                buttonTitle: '의견 보내기',
                onPressed: _submitFeedback,
              ),
            ),
          ),
          if (userRole != 'admin' && userRole != 'paid_user')
            SafeArea(
              bottom: false, // 하단 여백 제거
              child: BannerAdWidget(),
            ),
        ],
      ),
    );
  }
}
