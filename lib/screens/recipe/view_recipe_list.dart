import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/recipe/read_recipe.dart';

class ViewRecipeList extends StatefulWidget {
  final String recipeName;

  ViewRecipeList({
    required this.recipeName,
  });

  @override
  _ViewRecipeListState createState() => _ViewRecipeListState();
}

class _ViewRecipeListState extends State<ViewRecipeList> {
  String? selectedRecipe;
// 요리명 리스트
  List<String> recipeList = ['참치김밥', '불고기', '닭갈비'];
  List<String> ingredients = ['닭고기', '소금', '후추'];
  String ratings = '★★★★☆';

  // 냉장고에 있는 재료 리스트
  List<String> fridgeIngredients = [];

  bool isScraped = false; // 이미 좋아요를 눌렀는지 여부

  @override
  void initState() {
    super.initState();
    _checkIfRecipeIsScraped();
  }

  // void _toggleScraped() {
  //   setState(() {
  //     if (isScraped) {
  //       isScraped = false;
  //     } else {
  //       isScraped = true;
  //     }
  //   });
  // }

  Future<void> _checkIfRecipeIsScraped() async {
    final userId = '현재 유저아이디'; // 실제 사용자의 ID로 대체

    try {
      // Firestore에서 현재 레시피가 이미 스크랩된 상태인지 확인
      final existingScrap = await FirebaseFirestore.instance
          .collection('scraped_recipe')
          .where('userId', isEqualTo: userId)
          .where('recipeName', isEqualTo: widget.recipeName)
          .get();
print(widget.recipeName);
      setState(() {
        isScraped = existingScrap.docs.isNotEmpty; // 스크랩된 경우 true
      });
    } catch (e) {
      print('Error checking if recipe is scraped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(3.0),
              child: _buildRecipeGrid(),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRecipeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.all(8.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 3,
      ),
      itemCount: recipeList.length,
      itemBuilder: (context, index) {
        String recipeName = recipeList[index];
        bool hasImage = false;
        // 카테고리 그리드 렌더링
        return GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ReadRecipe(
                      recipeId: recipeName,searchKeywords: [],
                    )));
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 1.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(8.0),
            ), // 카테고리 버튼 크기 설정
            child: Row(
              children: [
                // 왼쪽에 정사각형 그림
                Container(
                  width: 60.0,
                  height: 60.0,
                  decoration: BoxDecoration(
                    color: Colors.grey, // Placeholder color for image
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: hasImage
                      ? Image.asset(
                    'assets/images/recipe_placeholder.png', // 이미지 경로
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    Icons.image, // 이미지가 없을 경우 대체할 아이콘
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(width: 10), // 간격 추가
                // 요리 이름과 키워드를 포함하는 Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 요리명
                      Row(
                        children: [
                          Text(
                            recipeName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Spacer(),
                          Text(ratings),
                          IconButton(
                            icon: Icon(isScraped ? Icons.bookmark : Icons.bookmark_border,
                                size: 20), // 스크랩 아이콘 크기 조정
                            onPressed:(){},
                          ),
                        ],
                      ), // 간격 추가
                      // 키워드
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 1.0,
                        children: ingredients.map((ingredient) {
                          bool inFridge =
                          fridgeIngredients.contains(ingredient);
                          return Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 2.0, horizontal: 4.0),
                            decoration: BoxDecoration(
                              color: inFridge ? Colors.green : Colors.white,
                              border: Border.all(
                                color: Colors.grey,
                                width: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              ingredient,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: inFridge ? Colors.white : Colors.black,
                              ),
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
        );
      },
    );
  }
}
