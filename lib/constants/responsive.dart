import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static late double _screenWidth;
  static late double _screenHeight;

  // Reference design size (Pixel 6 Pro / iPhone 14 Pro Max)
  static const double _referenceWidth = 393;
  static const double _referenceHeight = 852;

  static double get width => _screenWidth;
  static double get height => _screenHeight;

  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
  }

  static double w(double percent) => _screenWidth * (percent / 100);
  static double h(double percent) => _screenHeight * (percent / 100);

  /// Scale a width value from reference to current screen
  static double scaleW(double value) => value * (_screenWidth / _referenceWidth);

  /// Scale a height value from reference to current screen
  static double scaleH(double value) => value * (_screenHeight / _referenceHeight);

  /// Scale font size proportionally to screen width
  static double sp(double fontSize) => fontSize * (_screenWidth / _referenceWidth);

  /// Minimum of scaleW and scaleH (for squares/circles)
  static double scale(double value) => value * (_screenWidth / _referenceWidth).clamp(0.5, 1.5);

  /// Device type checks
  static bool get isSmallPhone => _screenWidth < 360;
  static bool get isNormalPhone => _screenWidth >= 360 && _screenWidth < 400;
  static bool get isLargePhone => _screenWidth >= 400 && _screenWidth < 600;
  static bool get isTablet => _screenWidth >= 600;

  static double get gridCrossAxisCount {
    if (isSmallPhone) return 2;
    if (isNormalPhone) return 2;
    if (isLargePhone) return 3;
    return 4;
  }

  static double get horizontalPadding {
    if (isSmallPhone) return 12;
    if (isNormalPhone) return 16;
    if (isLargePhone) return 20;
    return 24;
  }
}

extension ResponsiveContext on BuildContext {
  void initResponsive() => Responsive.init(this);

  double w(double percent) => Responsive.w(percent);
  double h(double percent) => Responsive.h(percent);
  double scaleW(double value) => Responsive.scaleW(value);
  double scaleH(double value) => Responsive.scaleH(value);
  double sp(double fontSize) => Responsive.sp(fontSize);
  double scale(double value) => Responsive.scale(value);
}
