// recipe_webview_page.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:food_for_later_new/models/recipe_model.dart';

class RecipeWebViewPage extends StatefulWidget {
  final String link;
  final String title;
  final RecipeModel recipe;
  final bool initialScraped;  // 추가: 초기 스크랩 상태
  // 스크랩 상태 토글이나 레시피 내일 기록 기능은 콜백 함수를 통해 전달할 수 있습니다.
  final Future<bool> Function(String recipeId, String? link) onToggleScraped;
  final void Function(RecipeModel recipe) onSaveRecipeForTomorrow;

  const RecipeWebViewPage({
    Key? key,
    required this.link,
    required this.title,
    required this.recipe,
    required this.initialScraped,
    required this.onToggleScraped,
    required this.onSaveRecipeForTomorrow,
  }) : super(key: key);

  @override
  _RecipeWebViewPageState createState() => _RecipeWebViewPageState();
}

class _RecipeWebViewPageState extends State<RecipeWebViewPage> {
  late final WebViewController _controller;
  late bool _isScraped; // 내부 상태로 스크랩 상태를 관리

  @override
  void initState() {
    super.initState();
    _isScraped = widget.initialScraped;
    _initializeWebView();
  }
  Future<void> _initializeWebView() async {
    _controller = WebViewController();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.loadRequest(Uri.parse(widget.link));
  }
  String _generateScrapedKey(String recipeId, String? link) {
    return link != null && link.isNotEmpty ? 'link|$link' : 'id|$recipeId';
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // 제목을 화면의 앞쪽에 표시합니다.
            Expanded(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 오른쪽에 스크랩과 캘린더 아이콘을 배치합니다.
            Row(
              children: [
                IconButton(
                  icon: Icon(
                      _isScraped ? Icons.bookmark : Icons.bookmark_border,
                      size: 26),
                  onPressed: () async {

                    bool newState = await widget.onToggleScraped(
                      widget.recipe.id,
                      widget.recipe.link,
                    );
                    print('onToggleScraped 반환값: $newState');
                    setState(() {
                      _isScraped = newState;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.calendar_today, size: 25),
                  onPressed: () {
                    widget.onSaveRecipeForTomorrow(widget.recipe);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
