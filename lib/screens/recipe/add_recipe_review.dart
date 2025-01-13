import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/ad/banner_ad_widget.dart';
import 'package:food_for_later_new/components/navbar_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddRecipeReview extends StatefulWidget {
  late final String recipeId;
  late final String? reviewId;

  AddRecipeReview({
    required this.recipeId,
    this.reviewId,
  });

  @override
  _AddRecipeReviewState createState() => _AddRecipeReviewState();
}

class _AddRecipeReviewState extends State<AddRecipeReview> {
  TextEditingController reviewContentController = TextEditingController();
  List<String> selectedImages = [];
  int selectedRating = 0;
  List<String>? _imageFiles = [];
  List<String> reviewImages = [];
  String imageUrl = '';
  String userRole = '';
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    if (widget.reviewId != null) {
      _loadReviewData();
      _loadUserRole();
    }
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
  // 리뷰 데이터를 Firestore에서 불러와서 초기화
  Future<void> _loadReviewData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> reviewSnapshot =
          await FirebaseFirestore.instance
              .collection('recipe_reviews')
              .doc(widget.reviewId) // reviewId로 불러옴
              .get();

      if (reviewSnapshot.exists) {
        final reviewData = reviewSnapshot.data();
        setState(() {
          reviewContentController.text = reviewData?['content'] ?? '';
          selectedRating = reviewData?['rating'] ?? 0;
          selectedImages = List<String>.from(reviewData?['images'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading review: $e');
    }
  }

  // 사진 추가 버튼 (예시로 로컬 파일 경로 리스트에 추가)
  Future<String> _addImage(File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final uniqueFileName =
          'recipe_review_image_${DateTime.now().millisecondsSinceEpoch}';
      final imageRef =
          storageRef.child('images/recipe_reviews/$uniqueFileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // 이미지의 MIME 타입 설정
      );
      final uploadTask = imageRef.putFile(imageFile, metadata);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }

  Future<String> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? pickedFiles = await picker.pickMultiImage();

    if (pickedFiles == null || pickedFiles.isEmpty) {
      // 이미지 선택이 취소된 경우
      print('No image selected.');
      return '';
    }

    if (_imageFiles == null) {
      _imageFiles = [];
    }

    for (XFile file in pickedFiles) {
      if (!_imageFiles!.contains(file.path)) {
        setState(() {
          _imageFiles!.add(file.path);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미 추가된 이미지입니다.'),
          ),
        );
      }
    }
    return _imageFiles!.isNotEmpty ? _imageFiles!.first : '';
  }

  Future<void> updateRecipeRating(String recipeId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> reviewsSnapshot =
          await FirebaseFirestore.instance
              .collection('recipe_reviews')
              .where('recipeId', isEqualTo: recipeId)
              .get();

      if (reviewsSnapshot.docs.isNotEmpty) {
        double totalRating = 0.0;
        for (var doc in reviewsSnapshot.docs) {
          totalRating += (doc['rating'] as num).toDouble();
        }

        double averageRating = totalRating / reviewsSnapshot.docs.length;

        // 평균 별점 Firestore에 업데이트
        await FirebaseFirestore.instance
            .collection('recipe')
            .doc(recipeId)
            .update({'rating': averageRating});
      }
    } catch (e) {
      print('Error calculating and updating recipe rating: $e');
    }
  }

  // 저장 버튼 클릭 시 처리
  void _saveReview() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String reviewContent = reviewContentController.text;

    if (reviewContent.isEmpty || selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리뷰를 입력해주세요')),
      );
      return;
    }

    try {
      // Generate unique reviewId
      String reviewId = widget.reviewId ??
          FirebaseFirestore.instance.collection('recipe_reviews').doc().id;

      // Get the current user's ID (assuming Firebase Authentication is used)
      // String userId = FirebaseAuth.instance.currentUser!.uid;

      // Save review to Firestore
      await FirebaseFirestore.instance
          .collection('recipe_reviews')
          .doc(reviewId)
          .set({
        'userId': userId,
        'recipeId': widget.recipeId,
        'reviewId': reviewId,
        'rating': selectedRating,
        'content': reviewContent,
        'images': selectedImages, // Assuming selectedImages contains image URLs
        'timestamp': FieldValue.serverTimestamp(), // Save the current timestamp
      }, SetOptions(merge: true));

      await updateRecipeRating(widget.recipeId);

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리뷰가 저장되었습니다')),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error saving review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('리뷰 저장 중 오류가 발생했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildReviewsAddSection();
  }

  Widget _buildReviewsAddSection() {
    final theme = Theme.of(context);
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.reviewId == null ? '리뷰쓰기' : '리뷰수정하기'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text('즐거운 요리시간 되셨나요?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                SizedBox(height: 16),
                _buildRatingStars(),
                SizedBox(height: 16),
                Center(
                  child: Text('어떤 부분이 좋았나요?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: reviewContentController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: '최소 10자 이상 입력해주세요!',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    String selectedImagePath =
                        await _selectImage(); // 이미지 선택 후 경로 반환
                    File imageFile = File(selectedImagePath);
                    imageUrl = await _addImage(imageFile);
                    if (selectedImagePath.isNotEmpty) {
                      // Firebase에 이미지 업로드
                      if (imageUrl.isNotEmpty) {
                        setState(() {
                          selectedImages.add(imageUrl); // 업로드된 이미지 URL을 리스트에 추가
                        });
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: theme.colorScheme.primary, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined),
                        SizedBox(width: 10), // 아이콘과 텍스트 간격
                        Text('사진 첨부하기'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                if (selectedImages.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: selectedImages.map((imagePath) {
                      return Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Image.network(
                              imagePath, // Firebase에서 불러온 이미지 URL
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedImages
                                      .remove(imagePath); // 선택한 이미지 삭제
                                });
                              },
                              child: Container(
                                color: Colors.black54,
                                child: Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 저장 버튼
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
                  buttonTitle: '저장하기',
                  onPressed: _saveReview,
                ),
              ),
            ),
            if (userRole != 'admin' && userRole != 'paid_user')
              SafeArea(
                bottom: false, // 하단 여백 제거
                child: BannerAdWidget(),
              ),
          ],
        ));
  }

  Widget _buildRatingStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedRating = index + 1;
                });
              },
              child: Icon(
                index < selectedRating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 40, // 아이콘 크기 설정
              ),
            ),
            if (index != 4) SizedBox(width: 2), // 아이콘 사이 간격 설정
          ],
        );
      }),
    );
  }
}
