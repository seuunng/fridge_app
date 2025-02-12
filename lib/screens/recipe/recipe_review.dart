import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/recipe/add_recipe_review.dart';
import 'package:food_for_later_new/screens/recipe/full_screen_image_view.dart';
import 'package:food_for_later_new/screens/settings/feedback_submission.dart';
import 'package:intl/intl.dart';

class RecipeReview extends StatefulWidget {
  late final String recipeId;

  RecipeReview({
    required this.recipeId,
  });

  @override
  _RecipeReviewState createState() => _RecipeReviewState();
}

class _RecipeReviewState extends State<RecipeReview> {
  List<Map<String, dynamic>> recipeReviews = [];
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool isAdmin = false;
  TextEditingController reviewContentController = TextEditingController();
  int likedCount = 0; // 좋아요 수

  @override
  void initState() {
    super.initState();
    _loadReviewsFromFirestore();
    _checkAdminRole();
    _loadScrapedAndLikedCounts();
  }

  void _loadScrapedAndLikedCounts() async {
    int liked = await _getLikedCount(widget.recipeId);

    setState(() {
      likedCount = liked;
    });
  }

  void _loadReviewsFromFirestore() async {
    List<Map<String, dynamic>> fetchedReviews = await fetchRecipeReviews();
    if (mounted)
      setState(() {
        recipeReviews = fetchedReviews;
      });
  }

  Future<List<Map<String, dynamic>>> fetchRecipeReviews() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('recipe_reviews')
              .where('recipeId', isEqualTo: widget.recipeId) // 실제 레시피 ID로 대체
              .get();

      List<Map<String, dynamic>> recipeReviews = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        data['docId'] = doc.id;

        // 기본값 설정
        data['isNiced'] = false; // 좋아요 상태
        data['avatar'] = 'assets/avatar/avatar-01.png'; // 기본 아바타
        data['nickname'] = 'Unknown User'; // 기본 닉네임

        // 2. 작성자의 아바타 가져오기
        String? reviewUserId = data['userId'];
        if (reviewUserId != null && reviewUserId.isNotEmpty) {
          // userId가 있는 경우 Firestore에서 작성자 데이터 가져오기
          DocumentSnapshot<Map<String, dynamic>> userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(reviewUserId)
                  .get();

          if (userDoc.exists) {
            data['avatar'] =
                userDoc.data()?['avatar'] ?? 'assets/avatar/avatar-01.png';
            data['nickname'] = userDoc.data()?['nickname'] ?? 'Unknown User';
          } else {
            print('작성자 정보가 없습니다. userId: $reviewUserId');
          }
        } else {
          print('리뷰에 userId가 없습니다. reviewId: ${doc.id}');
        }
        // 3. 현재 유저의 좋아요 상태 가져오기
        QuerySnapshot<Map<String, dynamic>> nicedSnapshot =
            await FirebaseFirestore.instance
                .collection('niced_reviews')
                .where('recipeId', isEqualTo: widget.recipeId)
                .where('reviewId', isEqualTo: data['reviewId'])
                .where('userId', isEqualTo: userId) // 현재 로그인한 유저 ID
                .get();

        if (widget.recipeId.isEmpty ||
            data['reviewId'] == null ||
            userId.isEmpty) {
          print('Error: recipeId, reviewId, or userId is missing!');
        }
        if (nicedSnapshot.docs.isNotEmpty) {
          data['isNiced'] = true; // 좋아요 상태 업데이트
        }

        recipeReviews.add(data);
      }

      return recipeReviews;
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  void _toggleNiced(int index) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == 'guest@foodforlater.com') {
      // 🔹 방문자(게스트) 계정이면 스크랩 차단 및 안내 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 후 리뷰를 좋아요 할 수 있습니다.')),
      );
      return; // 🚫 여기서 함수 종료 (스크랩 기능 실행 안 함)
    }
    final String reviewId = recipeReviews[index]['reviewId'];

    try {
      // 스크랩 상태 확인을 위한 쿼리
      QuerySnapshot<Map<String, dynamic>> existingScrapedRecipes =
          await FirebaseFirestore.instance
              .collection('niced_reviews')
              .where('recipeId', isEqualTo: widget.recipeId)
              .where('userId', isEqualTo: userId)
              .where('reviewId', isEqualTo: reviewId)
              .get();

      if (existingScrapedRecipes.docs.isEmpty) {
        // 스크랩이 존재하지 않으면 새로 추가
        await FirebaseFirestore.instance.collection('niced_reviews').add({
          'userId': userId,
          'recipeId': widget.recipeId,
          'reviewId': reviewId,
          'isNiced': true,
        });

        setState(() {
          recipeReviews[index]['isNiced'] = true;
        });
      } else {
        // 스크랩이 존재하면 업데이트
        DocumentSnapshot<Map<String, dynamic>> doc =
            existingScrapedRecipes.docs.first;

        await FirebaseFirestore.instance
            .collection('niced_reviews')
            .doc(doc.id)
            .delete();

        setState(() {
          recipeReviews[index]['isNiced'] = false;
        });
      }
    } catch (e) {
      print('Error nicing recipe: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('리뷰 좋아요 처리 중 오류가 발생했습니다.'),
      ));
    }
  }

  Future<int> _getLikedCount(String recipeId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('niced_reviews')
          .where('reviewId', isEqualTo: recipeId)
          .where('isNiced', isEqualTo: true)
          .get();
      return snapshot.docs.length; // 좋아요된 문서 수 반환
    } catch (e) {
      print('Error fetching liked count: $e');
      return 0; // 에러 시 0 반환
    }
  }

  Future<void> _deleteReview(int index) async {
    String docId = recipeReviews[index]['docId'];
    bool isNiced = recipeReviews[index]['isNiced'] ?? false;
    final String reviewId = recipeReviews[index]['reviewId'];

    try {
      await FirebaseFirestore.instance
          .collection('recipe_reviews')
          .doc(docId)
          .delete();

      if (isNiced) {
        QuerySnapshot<Map<String, dynamic>> nicedReviewSnapshot =
            await FirebaseFirestore.instance
                .collection('niced_reviews')
                .where('recipeId', isEqualTo: widget.recipeId)
                .where('reviewId', isEqualTo: reviewId)
                .where('userId', isEqualTo: userId)
                .get();

        if (nicedReviewSnapshot.docs.isNotEmpty) {
          DocumentSnapshot<Map<String, dynamic>> doc =
              nicedReviewSnapshot.docs.first;
          await FirebaseFirestore.instance
              .collection('niced_reviews')
              .doc(doc.id)
              .delete();
        }
      }

      // 삭제 후 리스트에서 해당 리뷰 제거
      setState(() {
        recipeReviews.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('리뷰가 성공적으로 삭제되었습니다.'),
      ));
    } catch (e) {
      print('Error deleting review: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('리뷰 삭제 중 오류가 발생했습니다.'),
      ));
    }
  }

  // 삭제 확인 다이얼로그
  Future<void> _confirmDeleteReview(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('리뷰 삭제'),
          content: Text('이 리뷰를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('삭제'),
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                _deleteReview(index); // 리뷰 삭제 호출
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkAdminRole() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
          .instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          isAdmin = userDoc.data()?['role'] == 'admin'; // 관리자 역할 확인
        });
      }
    } catch (e) {
      print("Error checking admin role: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewsSection(),
          // _buildReviewsInputSection(),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('리뷰',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface)),
          SizedBox(height: 16),
          if (recipeReviews.isEmpty) Center(
                  // 리뷰가 없을 때 표시될 메시지
                  child: Column(
                    children: [
                      Icon(Icons.comment, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text(
                        '아직 리뷰가 없습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        '첫번째 리뷰를 작성해주세요!',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ) else ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: recipeReviews.length,
                  itemBuilder: (context, index) {
                    final Timestamp timestamp =
                        recipeReviews[index]['timestamp'] ?? Timestamp.now();
                    final DateTime dateTime = timestamp.toDate();
                    final String formattedDate =
                        DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
                    bool isNiced = recipeReviews[index]['isNiced'] ?? false;
                    int rating = recipeReviews[index]['rating'];
                    final List<String> images =
                        List<String>.from(recipeReviews[index]['images'] ?? []);
                    final bool isAuthor =
                        recipeReviews[index]['userId'] == userId;
                    final String avatar = recipeReviews[index]['avatar'];
                    final String nickname =
                        recipeReviews[index]['nickname']; // 작성자의 아바타

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20, // 아바타 크기
                                    backgroundImage: AssetImage(avatar),
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nickname,
                                          style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSurface)),
                                      SizedBox(width: 4),
                                      Text(formattedDate,
                                          style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSurface)),
                                      _buildRatingStars(rating)
                                    ],
                                  ),
                                  // Spacer(),
                                  SizedBox(width: 30,),
                                  Row(children: [
                                    Column(
                                      children: [
                                        Row(
                                          mainAxisSize:
                                              MainAxisSize.min, // 최소 공간만 차지하도록 설정
                                          children: [
                                            GestureDetector(
                                              onTap: () => _toggleNiced(index),
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Icon(
                                                    isNiced
                                                        ? Icons.thumb_up
                                                        : Icons
                                                            .thumb_up_alt_outlined,
                                                    size: 12,
                                                    color: theme
                                                        .colorScheme.onSurface),
                                              ),
                                            ),
                                            // SizedBox(width: 10),
                                            // Text(
                                            //   '$likedCount',
                                            //   style: TextStyle(
                                            //     fontSize: 12,
                                            //     color:
                                            //         theme.colorScheme.onSurface,
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    FeedbackSubmission(
                                                      postNo: recipeReviews[index]
                                                          ['reviewId'],
                                                      postType: '리뷰',
                                                    )));
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Icon(Icons.feedback_outlined,
                                            size: 12,
                                            color: theme.colorScheme.onSurface),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                  ]),
                                  if (isAdmin || isAuthor)
                                    Row(
                                      children: [
                                        Text('|',
                                            style: TextStyle(
                                                color:
                                                    theme.colorScheme.onSurface)),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        AddRecipeReview(
                                                          recipeId:
                                                              widget.recipeId,
                                                          reviewId:
                                                              recipeReviews[index]
                                                                  ['reviewId'],
                                                        )));
                                          },
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size(30, 20),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text('수정',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface)),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _confirmDeleteReview(index),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size(30, 20),
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text('삭제',
                                              style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface)),
                                        ),
                                        SizedBox(width: 5),
                                      ],
                                    ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Text(recipeReviews[index]['content']!,
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface)),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: images.isNotEmpty
                                    ? images.map((imageUrl) {
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FullScreenImageView(
                                                  images: images,
                                                  initialIndex: images.indexOf(
                                                      imageUrl), // 현재 클릭한 이미지의 인덱스 전달
                                                ),
                                              ),
                                            );
                                          },
                                          child: Image.network(
                                            imageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(Icons.broken_image);
                                            },
                                          ),
                                        );
                                      }).toList()
                                    : [Container()], // 이미지가 없는 경우 빈 컨테이너
                              ),
                            ]),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(
        rating,
        (index) => Icon(
          Icons.star,
          color: Colors.amber,
          size: 14,
        ),
      ),
    );
  }
}
