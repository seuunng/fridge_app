import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/recipe/view_research_list.dart'; // ViewResearchList 경로 맞게 수정

class BasicElevatedButton extends StatelessWidget {
  final String buttonTitle;
  final IconData iconTitle;
  final VoidCallback? onPressed;

  const BasicElevatedButton({
    Key? key,
    required this.buttonTitle,
    required this.iconTitle,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        // backgroundColor: theme.colorScheme.primaryContainer, // 배경 색상
        // foregroundColor: theme.colorScheme.onPrimaryContainer, // 텍스트 색상
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10), // 둥근 모서리
        ),
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 18.0), // 버튼 패딩
        elevation: 5, // 그림자 높이
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconTitle),
          SizedBox(width: 8),
          Text(
            buttonTitle,
            // style: TextStyle(fontSize: 16), // 텍스트 크기
          ),
        ],
      ),
    );
  }
}