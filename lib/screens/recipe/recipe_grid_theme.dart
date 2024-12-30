import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/recipe/view_recipe_list.dart';
import 'package:food_for_later_new/screens/recipe/view_research_list.dart';

class RecipeGridTheme extends StatefulWidget {
  final List<String> categories;

  RecipeGridTheme({
    required this.categories,
  });

  @override
  _RecipeGridThemeState createState() => _RecipeGridThemeState();
}

class _RecipeGridThemeState extends State<RecipeGridTheme> {
  String? selectedCategory;

  // 선택된 아이템 상태를 관리할 리스트
  List<String> selectedItems = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(3.0),
            child: _buildCategoryGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    if (widget.categories.isEmpty) {
      // 기본 카테고리가 비어있을 때 처리
      return Center(child: Text("카테고리가 없습니다."));
    }

    return LayoutBuilder(
        builder: (context, constraints) {
          bool isWeb = constraints.maxWidth > 600; // 웹 기준 분기
          int crossAxisCount = isWeb ? 3 : 1; // 웹에서는 3열, 모바일에서는 1열
          double aspectRatio = isWeb ? 6 : 6; // 웹과 모바일의 비율 설정

        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(8.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, // 한 줄에 몇 개의 그리드가 들어갈지 설정
            crossAxisSpacing: 8.0, // 가로 간격
            mainAxisSpacing: 8.0, // 세로 간격
            childAspectRatio: aspectRatio,
          ),
          itemCount: widget.categories.length,
          itemBuilder: (context, index) {
            String category = widget.categories[index];
            // String currentItem = selectedItems[index];
            // 카테고리 그리드 렌더링
            return GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ViewResearchList(
                          category: [category],
                          useFridgeIngredients: false,
                        )));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: selectedCategory == category
                      ? theme.chipTheme.selectedColor
                      : theme.chipTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8.0),
                ), // 카테고리 버튼 크기 설정
                // height: 60,
                // margin: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(
                  child: Text(
                    category,
                    style: TextStyle(color: theme.chipTheme.labelStyle!.color, fontSize: 16),
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }
}
