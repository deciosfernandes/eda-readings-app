import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eda_app/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('lightTheme is not null', () {
      expect(AppTheme.lightTheme, isNotNull);
    });

    test('darkTheme is not null', () {
      expect(AppTheme.darkTheme, isNotNull);
    });

    test('lightTheme uses Material 3', () {
      expect(AppTheme.lightTheme.useMaterial3, isTrue);
    });

    test('darkTheme uses Material 3', () {
      expect(AppTheme.darkTheme.useMaterial3, isTrue);
    });

    test('lightTheme primary color is EDA yellow', () {
      expect(
        AppTheme.lightTheme.colorScheme.primary,
        const Color(0xFFFFD000),
      );
    });

    test('darkTheme primary color is EDA yellow', () {
      expect(
        AppTheme.darkTheme.colorScheme.primary,
        const Color(0xFFFFD000),
      );
    });

    test('lightTheme brightness is light', () {
      expect(AppTheme.lightTheme.colorScheme.brightness, Brightness.light);
    });

    test('darkTheme brightness is dark', () {
      expect(AppTheme.darkTheme.colorScheme.brightness, Brightness.dark);
    });

    test('lightTheme onPrimary color is black (for legibility on yellow)', () {
      expect(AppTheme.lightTheme.colorScheme.onPrimary, Colors.black);
    });

    test('darkTheme onPrimary color is black (for legibility on yellow)', () {
      expect(AppTheme.darkTheme.colorScheme.onPrimary, Colors.black);
    });

    test('darkTheme surface is near-black', () {
      expect(AppTheme.darkTheme.colorScheme.surface, const Color(0xFF121212));
    });

    test('lightTheme and darkTheme are different instances', () {
      expect(AppTheme.lightTheme, isNot(same(AppTheme.darkTheme)));
    });
  });
}
