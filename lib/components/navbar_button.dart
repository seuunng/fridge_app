import 'package:flutter/material.dart';

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
        padding: EdgeInsets.symmetric(vertical: 10), // 위아래 패딩을 조정하여 버튼 높이 축소
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // 버튼의 모서리를 둥글게
        ),
        elevation: 5,
      ),
    );
  }
}
