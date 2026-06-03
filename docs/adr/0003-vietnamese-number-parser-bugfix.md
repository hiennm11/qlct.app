# ADR-0003: Vietnamese Number Parser — Fix "mươi", "50 ngàn", và Dialect Variants

**Date:** 2026-06-03
**Status:** Accepted
**Author:** hiennm11

## Context

`VietnameseNumberParser` (ADR-0002, line 109) có 2 bug được ghi nhận trong tests nhưng chưa fix:

1. **"mươi" nhập nhằng**: Từ `"mươi"` tồn tại trong cả `_numberMap` (value 10 — digit) và `_units` (×10 — multiplier). Vì `_numberMap` check trước trong vòng lặp, `"mươi"` luôn bị treat như digit +10, không bao giờ thành multiplier ×10.

2. **"50 ngàn" không combine**: `extractAmount` gọi `_parseNumeric` → tìm thấy "50" → return 50 ngay lập tức, bỏ qua scale word "ngàn" theo sau.

Ngoài ra, parser còn thiếu dialect variants (`"lăm"`, `"nhăm"`, `"tư"`) và chứa entry sai (`"mấy"` = "how many", không phải 10).

### Root Cause Analysis

**Bug 1 — `"mươi"` trong cả 2 map**:

```
_năm mươi nghìn_ trace (current logic):
'năm'   → _numberMap → current = 5
'mươi'  → _numberMap TRƯỚC _units → current = 5 + 10 = 15   ← SAI
'nghìn' → _scales → result = (0 + 15) × 1000 = 15000        ← SAI (expected 50000)
```

Lý do: `_numberMap.containsKey(word)` check ở dòng 77, trước `_units.containsKey(word)` ở dòng 79.

**Bug 2 — `"mươi"` chỉ nên nhân digit cuối, không nhân toàn bộ `current`**:

Ngay cả khi remove `"mươi"` khỏi `_numberMap`, parser vẫn sai với `"một trăm hai mươi"`:
```
'một'  → current = 1
'trăm' → current = 1 × 100 = 100
'hai'  → current = 100 + 2 = 102
'mươi' → _units → current = 102 × 10 = 1020     ← SAI (expected 120)
```

Vấn đề gốc: parser không track **digit cuối cùng**. `"mươi"` nên chỉ nhân digit ngay trước nó (2 × 10 = 20), không nhân toàn bộ accumulated `current` (102 × 10 = 1020). Đây là structural limitation của sequential accumulator đơn giản.

**Bug 3 — `extractAmount` không combine numeric + scale**:

```
extractAmount("ăn cơm 50 ngàn"):
  → _parseNumeric: tách words → tìm "50" → return 50  ← dừng, không check "ngàn"
```

`_parseNumeric` là pure numeric extraction, không aware của scale words.

### Missing Dialect Variants

Parser hiện tại không hỗ trợ:

| Word | Dialect | Example | Expected |
|------|---------|---------|----------|
| `"lăm"` | Chuẩn | `"mười lăm"` | 15 |
| `"nhăm"` | Miền Bắc | `"hai mươi nhăm"` | 25 |
| `"tư"` | Miền Nam | `"hai mươi tư"` | 24 |

Và có entry sai: `"mấy"` = 10 trong `_numberMap`. `"mấy"` nghĩa là "how many", không phải số.

## Decision

### 1. Remove `mươi`, `mười`, `mấy` khỏi `_numberMap`; Add `lăm`, `nhăm`, `tư`

```dart
static const Map<String, int> _numberMap = {
  'không': 0,
  'một': 1,
  'hai': 2,
  'ba': 3,
  'bốn': 4,
  'năm': 5,
  'sáu': 6,
  'bảy': 7,
  'tám': 8,
  'chín': 9,
  // REMOVED: 'mười': 10, 'mươi': 10, 'mấy': 10
  'lăm': 5,     // ADDED — "mười lăm"=15, "hai mươi lăm"=25
  'nhăm': 5,    // ADDED — variant: "hai mươi nhăm"=25
  'tư': 4,      // ADDED — Southern: "hai mươi tư"=24
};
```

**Rationale**: `"mười"` khi đứng một mình (`"mười"` = 10) vẫn hoạt động qua `_units` handler: `current=0 → current=1 → ×10 = 10`. Khi dùng trong compound (`"hai mười"` = 20, miền Nam), nó cần là multiplier, không phải digit.

### 2. Track `lastDigitValue` để "mươi"/"mười" chỉ nhân digit cuối

Thêm biến `lastDigitValue` trong `_parseVietnameseWords`. Khi gặp `"mươi"` hoặc `"mười"` trong `_units`:

```dart
if (lastDigitValue > 0 && (word == 'mươi' || word == 'mười')) {
  // Replace last digit with digit × 10
  current = current - lastDigitValue + (lastDigitValue * _units[word]!);
} else {
  current *= _units[word]!;
}
lastDigitValue = 0;
```

Trace lại `"một trăm hai mươi"`:
```
'một'  → current=1,   lastDigit=1
'trăm' → current=100, lastDigit=1  (trăm không trigger lastDigit path)
'hai'  → current=102, lastDigit=2
'mươi' → lastDigit=2>0 → current = 102 - 2 + (2×10) = 120  ✓
```

Trace `"hai mươi"`:
```
'hai'  → current=2, lastDigit=2
'mươi' → current = 2 - 2 + (2×10) = 20  ✓
```

Trace `"mười hai"` (standalone "mười"):
```
'mười' → lastDigit=0, current=0 → 1 → ×10 = 10
'hai'  → current=12  ✓
```

### 3. Fix `extractAmount` — ưu tiên Vietnamese words, fallback numeric+scale

Đảo thứ tự trong `extractAmount`:
1. Ưu tiên `_parseVietnameseWords` (bỏ qua noise words)
2. Fallback `_parseNumericWithScales` (tìm numeric + scale word trong text)

Method mới `_parseNumericWithScales`:
```dart
static int? _parseNumericWithScales(String text) {
  final words = text.split(RegExp(r'\s+'));
  int? numericValue;
  int scaleMultiplier = 1;

  for (final word in words) {
    final cleaned = word.replaceAll(RegExp(r'[.,]'), '');
    final num = int.tryParse(cleaned);
    if (num != null && num > 0) {
      numericValue = num;
    } else if (_scales.containsKey(word)) {
      scaleMultiplier *= _scales[word]!;
    }
  }

  return numericValue != null ? numericValue! * scaleMultiplier : null;
}
```

### 4. Test Coverage

Cập nhật expected values + thêm 10+ test case:

| Test case | Before | After |
|-----------|--------|-------|
| `parse("năm mươi nghìn")` | 15000 | **50000** |
| `parse("một trăm hai mươi")` | 112 | **120** |
| `extractAmount("ăn cơm 50 ngàn")` | 50 | **50000** |
| `extractAmount("ăn cơm năm mươi nghìn")` | 15000 | **50000** |

Test mới:
- `"hai mươi"` → 20
- `"mười hai"` → 12
- `"mười lăm"` → 15
- `"hai mươi lăm"` → 25
- `"hai mươi tư"` → 24
- `"một trăm ba mươi hai"` → 132
- `extractAmount("mua xe 2 triệu")` → 2000000
- `extractAmount("500 nghìn tiền điện")` → 500000
- `parse("mười")` → 10 (standalone regression test)
- `parse("một trăm")` → 100 (regression test)

## Consequences

### Positive
- Fix cả 3 bug gốc + mở rộng dialect coverage
- `_parseVietnameseWords` bỏ qua noise words → `extractAmount("ăn cơm năm mươi nghìn")` hoạt động
- Fallback numeric+scale → `extractAmount("ăn cơm 50 ngàn")` hoạt động
- Dialect variants (`lăm`, `nhăm`, `tư`) hỗ trợ người dùng miền Bắc/Nam
- Tất cả thay đổi chỉ trong 1 file parser (108 dòng) + 1 file test — risk thấp, không đụng UI/VM/Repo

### Negative
- Sequential accumulator vẫn có limitation với cấu trúc phức tạp (e.g. `"một trăm hai mươi ba nghìn"` — chưa xử lý đúng vì `nghìn` scale sẽ nhân toàn bộ accumulated result). Cần parser state-machine đầy đủ nếu mở rộng thêm.
- `_parseNumericWithScales` dùng naive scan toàn bộ text — nếu text có nhiều số + scale word khác nhau, có thể combine nhầm. Tuy nhiên voice input thực tế hiếm gặp pattern này.
- Chưa xử lý `"mốt"` (variant của `"một"`: `"hai mươi mốt"` = 21).
