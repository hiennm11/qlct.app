import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:qlct/core/theme.dart';

/// Reusable loading skeleton box. ADR-0043 (P2 micro-interactions).
///
/// Generic shimmer placeholder. Caller controls shape via [width],
/// [height], [borderRadius]. Use during full-area loading to give
/// perceived faster load than `CircularProgressIndicator`.
///
/// Theme: gray200 base + gray100 highlight (matches Material 3
/// surface variants).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.gray200,
      highlightColor: AppColors.gray100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
