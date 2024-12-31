import 'package:flutter/material.dart';

class FloatingAddButton extends StatelessWidget {
  final String heroTag;
  final VoidCallback onPressed;

  const FloatingAddButton({
    Key? key,
    required this.heroTag,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50, // 원하는 높이로 설정
      width: 50, // 원하는 너비로 설정
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12), // 테두리 둥글기 값 조정
      ),
      child: FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        child: Icon(Icons.add),
      ),
    );
  }
}
