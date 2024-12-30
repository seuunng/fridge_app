import 'package:flutter/material.dart';
import 'package:food_for_later_new/screens/recipe/view_research_list.dart'; // ViewResearchList 경로 맞게 수정

class NavbarButton extends StatelessWidget {
  final String buttonTitle;
  final VoidCallback onPressed;

  const NavbarButton({
    Key? key,
    required this.buttonTitle,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return ElevatedButton(
      onPressed: onPressed,
      child: Text(buttonTitle),
      style: ElevatedButton.styleFrom(
        padding:
            EdgeInsets.symmetric(vertical: 10), // 위아래 패딩을 조정하여 버튼 높이 축소
        // backgroundColor: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // 버튼의 모서리를 둥글게
        ),
        elevation: 5,
        // textStyle: TextStyle(
        //   // fontSize: 18, // 글씨 크기 조정
        //   // fontWeight: FontWeight.w500, // 약간 굵은 글씨체
        //   letterSpacing: 1.2, //
        //   // color: theme.colorScheme.onPrimaryContainer,
        // ),
      ),
    );
  }
}