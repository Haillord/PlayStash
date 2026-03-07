import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1800;
}

enum DeviceType { mobile, tablet, desktop, largeDesktop }

class AdaptiveUtils {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.mobile) return DeviceType.mobile;
    if (width < Breakpoints.tablet) return DeviceType.tablet;
    if (width < Breakpoints.desktop) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }
  

  static EdgeInsets adaptivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case DeviceType.largeDesktop:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
  }
}