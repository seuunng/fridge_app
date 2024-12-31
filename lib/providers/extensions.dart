import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

extension StyledText on Text {
  Text withDefaultStyle(BuildContext context) {
    return Text(
      this.data ?? '', // 기존 Text의 데이터
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.merge(this.style), // bodyMedium 스타일 + 기존 스타일
    );
  }
}
