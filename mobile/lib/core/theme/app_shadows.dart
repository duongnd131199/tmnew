import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  static const circularControl = [
    BoxShadow(color: Color(0x19000000), blurRadius: 30, offset: Offset(0, 4)),
  ];

  static const navigation = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 30,
      spreadRadius: 9.6666666667,
      offset: Offset(0, 4),
    ),
  ];
}
