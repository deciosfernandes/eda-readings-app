import 'package:flutter/material.dart';

IconData profileIconFromCodePoint(int codePoint) {
  switch (codePoint) {
    case 0xe318:
      return Icons.home;
    case 0xe089:
      return Icons.apartment;
    case 0xe6bc:
      return Icons.villa;
    case 0xe19b:
      return Icons.cottage;
    case 0xe11b:
      return Icons.business;
    case 0xe60a:
      return Icons.store;
    case 0xf04fd:
      return Icons.factory;
    case 0xe293:
      return Icons.flash_on;
    default:
      return Icons.home;
  }
}
