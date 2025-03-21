import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:food_for_later_new/screens/recipe/view_research_list.dart';
import 'package:food_for_later_new/constants.dart';


class RecipeGrid extends StatefulWidget {
  final List<String> categories;
  final Map<String, List<Map<String, String>>> itemsByCategory;

  RecipeGrid({
    required this.categories,
    required this.itemsByCategory,
  });

  @override
  _RecipeGridState createState() => _RecipeGridState();
}

class _RecipeGridState extends State<RecipeGrid> {
  String? selectedCategory;

  // 선택된 아이템 상태를 관리할 리스트
  List<String> selectedItems = [];
  @override
  void initState() {
    super.initState();
    // 카테고리가 비어있을 경우 첫 번째 아이템으로 selectedCategory 설정
    if (widget.categories.isEmpty && widget.itemsByCategory.isNotEmpty) {
      selectedCategory = widget.itemsByCategory.keys.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(3.0),
            child: _buildCategoryGrid(),
          ),
          if (!widget.categories.isEmpty && selectedCategory != null) ...[
            Divider(
              thickness: 1,
              color: Colors.grey, // 색상 설정
              indent: 20, // 왼쪽 여백
              endIndent: 20, // 오른쪽 여백),),
            ),
          ],
          if (selectedCategory != null) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCategoryItemsGrid(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final theme = Theme.of(context);
    if (widget.categories.isEmpty) {
      // 기본 카테고리가 비어있을 때 처리
      return Container();
    }

    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹인지 판별
      double maxCrossAxisExtent = isWeb ? 200 : 70; // 웹에서는 6열, 모바일에서는 3열
      double childAspectRatio = isWeb ? 1 : 1; // 웹과 모바일에서 비율 조정

      return GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent, // 열 개수 조정
          crossAxisSpacing: 8.0, // 가로 간격
          mainAxisSpacing: 8.0, // 세로 간격
          childAspectRatio: childAspectRatio,
        ),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          String category = widget.categories[index];
          String? imageFileName = categoryImages[category]; // 🟢 카테고리 이미지 가져오기
          // String currentItem = selectedItems[index];
          // 카테고리 그리드 렌더링
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory =
                    selectedCategory == category ? null : category;
              });
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imageFileName != null)
                    SvgPicture.asset(
                      'assets/categories/$imageFileName', // ✅ 이미지 경로 적용
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  else
                    Icon(
                      Icons.image,
                      size: 50,
                      color: Colors.grey,
                    ),
                  AutoSizeText(
                    category,
                    style: TextStyle(
                      color: selectedCategory == category
                          ? theme.chipTheme.secondaryLabelStyle!.color
                          : theme.chipTheme.labelStyle!.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    minFontSize: 6, // 최소 글자 크기 설정
                    maxFontSize: 16, // 최대 글자 크기 설정
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildCategoryItemsGrid() {
    final theme = Theme.of(context);
    if (selectedCategory == null) {
      return Container();
    }

    List<Map<String, String>> items =
        widget.itemsByCategory[selectedCategory!] ?? [];

    return LayoutBuilder(builder: (context, constraints) {
      bool isWeb = constraints.maxWidth > 600; // 웹 여부 판단
      double maxCrossAxisExtent = isWeb ? 200 : 70; // 웹에서는 5열, 모바일에서는 3열
      double childAspectRatio = isWeb ? 1 : 1; // 웹에서 더 넓은 비율
      return GridView.builder(
        shrinkWrap: true,
        // GridView의 크기를 콘텐츠에 맞게 줄임
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(8.0),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent, // 열 개수
          crossAxisSpacing: 8.0, // 가로 간격
          mainAxisSpacing: 8.0, // 세로 간격
          childAspectRatio: childAspectRatio, // 비율 설정
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          String currentItem = items[index]['name'] ?? 'Unknown';
          String? imageFileName = items[index]['imageFileName'];
          // 기존 아이템 그리드 렌더링
          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ViewResearchList(
                            category: [currentItem],
                            useFridgeIngredients: false,
                          )));
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.chipTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              height: 60,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (imageFileName != null && imageFileName!.isNotEmpty)
                      SvgPicture.asset(
                        // SVG 파일이면 flutter_svg로 표시
                        'assets/foods/${imageFileName}.svg',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    AutoSizeText(
                      currentItem,
                      style:
                          TextStyle(color: theme.chipTheme.labelStyle!.color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      minFontSize: 6, // 최소 글자 크기 설정
                      maxFontSize: 16, // 최대 글자 크기 설정
                    ),
                  ]),
            ),
          );
        },
      );
    });
  }
}
