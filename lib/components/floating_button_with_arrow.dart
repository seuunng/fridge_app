import 'package:flutter/material.dart';
import 'package:food_for_later_new/components/floating_add_button.dart';

class FloatingButtonWithArrow extends StatefulWidget {
  final String heroTag;
  final VoidCallback onPressed;

  const FloatingButtonWithArrow({Key? key, required this.heroTag, required this.onPressed}) : super(key: key);

  @override
  _FloatingButtonWithArrowState createState() => _FloatingButtonWithArrowState();
}

class _FloatingButtonWithArrowState extends State<FloatingButtonWithArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    )..repeat(reverse: true); // 애니메이션 반복

    _arrowAnimation = Tween<Offset>(
      begin: Offset(0, 0.3), // 화살표 아래에서 시작
      end: Offset(0, 0),     // 원래 위치로 올라옴
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // 화살표 애니메이션
        Positioned(
          right: 5,
          bottom: 80, // 플로팅 버튼 바로 위에 위치
          child: SlideTransition(
            position: _arrowAnimation,
            child: Icon(
              Icons.arrow_downward,
              color: Colors.blue,
              size: 60,
            ),
          ),
        ),

        // 플로팅 액션 버튼
        FloatingAddButton(
          heroTag: widget.heroTag,
          onPressed: widget.onPressed,
        ),
      ],
    );
  }
}
