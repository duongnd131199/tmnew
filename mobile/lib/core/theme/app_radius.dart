import 'package:flutter/material.dart';

abstract final class AppRadius {
  static const xs = Radius.circular(4);
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(24);

  static const card = BorderRadius.all(md);
  static const input = BorderRadius.all(sm);
  static const pill = BorderRadius.all(xl);
}
