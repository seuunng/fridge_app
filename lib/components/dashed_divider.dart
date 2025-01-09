import 'package:flutter/material.dart';
import 'package:flutter_dash/flutter_dash.dart';

class DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dash(
      direction: Axis.horizontal,
      length: MediaQuery.of(context).size.width - 32, // 🔹 화면 너비에서 패딩 고려
      dashLength: 6,  // 점선 길이
      dashColor: Colors.grey,  // 점선 색상
      dashThickness: 1,  // 점선 두께
    );
  }
}
