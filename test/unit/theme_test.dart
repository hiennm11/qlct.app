// ADR-0066: regression guard cho theme tokens.
//
// Verify AppColors pins + AppTheme.light() derivation:
// - AppColors.error = #BA1A1A (was #FF5459 salmon ở 1.7.0)
// - AppColors.primary = #208091 (không regress)
// - AppTheme.lightTheme.textTheme dùng 'Inter' font family
// - ElevatedButton.shape = StadiumBorder (pill)
// - ChipThemeData.shape = RoundedRectangleBorder(4) (soft)
// - primaryContainer KHÔNG pin (M3 auto-derive)
//
// Spec: docs/specs/0066-theme-alignment-contract.html §7

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qlct/core/theme.dart';

void main() {
  group('ADR-0066 — AppColors pins', () {
    test('primary = #208091 (Stitch design system)', () {
      expect(AppColors.primary.toARGB32(), const Color(0xFF208091).toARGB32());
    });

    test('error = #BA1A1A (M3 standard, was #FF5459 ở 1.7.0)', () {
      expect(AppColors.error.toARGB32(), const Color(0xFFBA1A1A).toARGB32());
    });

    test('background / surface / border = #F5F5F5 / #FFFFFF / #E0E0E0', () {
      expect(AppColors.background.toARGB32(), const Color(0xFFF5F5F5).toARGB32());
      expect(AppColors.surface.toARGB32(), const Color(0xFFFFFFFF).toARGB32());
      expect(AppColors.border.toARGB32(), const Color(0xFFE0E0E0).toARGB32());
    });
  });

  group('ADR-0066 — AppTheme.light() ColorScheme derive', () {
    test('colorScheme.error = AppColors.error (pick-up)', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.error.toARGB32(), AppColors.error.toARGB32());
    });

    test('colorScheme.primary = AppColors.primary', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary.toARGB32(), AppColors.primary.toARGB32());
    });

    test('primaryContainer: contract note (flat ColorScheme vs fromSeed)', () {
      // Contract §6: primaryContainer KHÔNG pin cứng; intent = M3 dynamic derive
      // từ primary seed. Flutter `ColorScheme.light()` flat constructor
      // mirror primary khi primaryContainer không pin (true M3 dynamic derive
      // chỉ áp dụng khi dùng `ColorScheme.fromSeed`).
      // Behavior này chấp nhận được cho 1.7.1 — 1 site coupled
      // (MonthCloseBanner ADR-0056) dùng primaryContainer; nó vẫn render
      // teal hợp lý với primary mirror (không error).
      // Nếu future dark mode hoặc design system yêu cầu tonal derive, switch
      // sang `ColorScheme.fromSeed(seedColor: AppColors.primary)` và document
      // lại primaryContainer tone trong contract.
      final theme = AppTheme.lightTheme;
      // Document behavior: primaryContainer == primary (flat constructor mirror).
      expect(
        theme.colorScheme.primaryContainer.toARGB32(),
        AppColors.primary.toARGB32(),
        reason: 'Hiện tại: ColorScheme.light() không pin primaryContainer → '
            'mirror primary. Đây là fallback an toàn cho 1.7.1; dynamic '
            'derive sẽ revisit khi ship dark mode (P+ ADR-0047).',
      );
    });
  });

  group('ADR-0066 — Typography (Inter font)', () {
    test('textTheme.bodyMedium fontFamily = Inter', () {
      final theme = AppTheme.lightTheme;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    });

    test('textTheme.bodySmall fontFamily = Inter', () {
      final theme = AppTheme.lightTheme;
      expect(theme.textTheme.bodySmall?.fontFamily, 'Inter');
    });

    test('textTheme.titleLarge fontFamily = Inter + weight 500', () {
      final theme = AppTheme.lightTheme;
      expect(theme.textTheme.titleLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w500);
    });

    test('textTheme.headlineLarge fontFamily = Inter + weight 700', () {
      final theme = AppTheme.lightTheme;
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Inter');
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    });
  });

  group('ADR-0066 — Button shape (pill)', () {
    test('elevatedButtonTheme.shape = StadiumBorder', () {
      final theme = AppTheme.lightTheme;
      final shape = theme.elevatedButtonTheme.style?.shape?.resolve({});
      expect(shape, isA<StadiumBorder>());
    });
  });

  group('ADR-0066 — Chip shape (soft 4px)', () {
    test('chipTheme.shape = RoundedRectangleBorder(4)', () {
      final theme = AppTheme.lightTheme;
      final shape = theme.chipTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      final rrect = shape as RoundedRectangleBorder;
      // BorderRadius.circular(4) → BorderRadius.all(Radius.circular(4))
      expect(rrect.borderRadius, BorderRadius.circular(4));
    });

    test('chipTheme.side = BorderSide(color: AppColors.border)', () {
      final theme = AppTheme.lightTheme;
      final side = theme.chipTheme.side;
      expect(side?.color.toARGB32(), AppColors.border.toARGB32());
    });
  });
}
