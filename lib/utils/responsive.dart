import 'package:flutter/material.dart';

/// Responsive breakpoints and helpers - Exact from specification
class Responsive {
  Responsive._();

  // Breakpoints - Exact from specification
  static const double phoneMax = 600;    // Mobile max
  static const double tabletMin = 600;   // Tablet min
  static const double tabletMax = 1024;  // Tablet max
  static const double desktopMin = 1024; // Desktop min

  // Landscape tablet breakpoint
  static const double landscapeTabletMin = 700;
  static const double landscapeTabletMax = 1024;

  /// True when shortest side >= 600 (iPad mini, Android tablets).
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tabletMin;

  /// True when width >= 1024 (large tablets in landscape).
  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// True when width >= 1024 (desktop).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;

  /// Landscape tablet: min-width 700px and min-height 500px and orientation landscape
  static bool isLandscapeTablet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);
    return size.width >= landscapeTabletMin &&
           size.height >= 500 &&
           orientation == Orientation.landscape;
  }

  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 720;

  /// True when the screen is narrow and upright enough to feel phone-like.
  static bool isPhonePortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isPortrait(context) && size.shortestSide < tabletMin;
  }

  /// True when the screen is narrow and horizontal enough to need tighter chrome.
  static bool isPhoneLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isLandscape(context) && size.shortestSide < tabletMin;
  }

  /// Adaptive value: returns [phone] on phones, [tablet] on tablets.
  static T value<T>(BuildContext context, {required T phone, required T tablet}) =>
      isTablet(context) ? tablet : phone;

  /// Adaptive value for desktop: returns [phone] on phones, [tablet] on tablets, [desktop] on desktop.
  static T value3<T>(BuildContext context, {
    required T phone,
    required T tablet,
    required T desktop
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return phone;
  }

  /// Number of grid columns for the current screen width.
  /// Folder grid: 1→2→3→4→5 columns
  static int gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1280) return 5;  // xl
    if (w >= 1024) return 4;  // lg
    if (w >= 768) return 3;   // md
    if (w >= 640) return 2;   // sm
    return 1;                // mobile
  }

  /// Stats grid columns: 2→4 columns
  static int statsGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 640) return 4;   // md+
    return 2;                // mobile
  }

  /// Media grid columns: 2→3→4 columns
  static int mediaGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1024) return 4;  // lg
    if (w >= 768) return 3;   // md
    return 2;                // mobile
  }

  /// Tools grid columns: 4→6 columns
  static int toolsColumns(BuildContext context) {
    return isTablet(context) ? 6 : 4;
  }

  /// Content max width – keeps forms/cards from stretching edge-to-edge on tablets.
  static double contentMaxWidth(BuildContext context) =>
      isDesktop(context)
          ? 1080
          : isLandscapeTablet(context)
              ? 940
              : isTablet(context)
                  ? 760
                  : double.infinity;

  /// Horizontal page padding.
  static double pagePadding(BuildContext context) =>
      isPhoneLandscape(context)
          ? 12.0
          : isLandscapeTablet(context)
              ? 20.0
              : value(context, phone: 14.0, tablet: 20.0);

  /// Adaptive font scale factor for headings.
  static double fontScale(BuildContext context) =>
      isLandscapeTablet(context) ? 1.12 : isTablet(context) ? 1.15 : 1.0;

  /// Icon size scaled for tablets.
  static double iconSize(BuildContext context, {double base = 24}) =>
      isTablet(context) ? base * 1.2 : base;

  /// Button height scaled for tablets.
  static double buttonHeight(BuildContext context) =>
      isPhoneLandscape(context)
          ? 40.0
          : isLandscapeTablet(context)
              ? 48.0
              : value(context, phone: 44.0, tablet: 50.0);

  /// Bottom bar action button height.
  static double bottomBarHeight(BuildContext context) =>
      isPhoneLandscape(context)
          ? 40.0
          : isLandscapeTablet(context)
              ? 48.0
              : value(context, phone: 42.0, tablet: 50.0);

  /// AppBar icon/back button size.
  static double appBarIconSize(BuildContext context) =>
      isPhoneLandscape(context)
          ? 36.0
          : isLandscapeTablet(context)
              ? 44.0
              : value(context, phone: 40.0, tablet: 48.0);

  /// Grid child aspect ratio for folder cards.
  static double statCardAspect(BuildContext context) =>
      value(context, phone: 1.5, tablet: 1.8);

  /// Folder card icon size
  static double folderIconSize(BuildContext context) =>
      isLandscapeTablet(context)
          ? 56.0
          : value(context, phone: 48.0, tablet: 56.0);

  /// Wraps [child] in a Center + ConstrainedBox so it doesn't stretch on tablets.
  static Widget constrain(BuildContext context, {
    required Widget child,
    double? maxWidth,
    EdgeInsetsGeometry? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? EdgeInsets.symmetric(horizontal: pagePadding(context)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth ?? contentMaxWidth(context)),
          child: child,
        ),
      ),
    );
  }

  /// Responsive padding for containers
  static EdgeInsets padding(BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
  }) {
    final pad = pagePadding(context);
    return EdgeInsets.symmetric(
      horizontal: horizontal > 0 ? horizontal : pad,
      vertical: vertical,
    );
  }

  /// Safe area aware padding
  static EdgeInsets safePadding(BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
    bool includeBottom = true,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final pad = pagePadding(context);
    return EdgeInsets.fromLTRB(
      horizontal > 0 ? horizontal : pad,
      vertical > 0 ? vertical : pad + mediaQuery.padding.top,
      horizontal > 0 ? horizontal : pad,
      vertical > 0 ? vertical : (includeBottom ? pad + mediaQuery.padding.bottom : pad),
    );
  }

  /// Camera chrome padding for landscape tablets
  static EdgeInsets cameraChromePadding(BuildContext context) {
    if (isLandscapeTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
    return EdgeInsets.symmetric(horizontal: pagePadding(context), vertical: 16);
  }

  /// Camera preview padding for landscape tablets
  static EdgeInsets cameraPreviewPadding(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (isLandscapeTablet(context)) {
      final horizontal = (size.width * 0.018).clamp(10.0, 18.0).toDouble();
      final vertical = (size.height * 0.008).clamp(4.0, 8.0).toDouble();
      return EdgeInsets.only(
        top: vertical,
        left: horizontal,
        right: horizontal,
        bottom: vertical,
      );
    }
    return EdgeInsets.symmetric(
      horizontal: pagePadding(context),
      vertical: 16,
    );
  }

  /// Camera preview viewport fitted inside an outer frame.
  static Rect cameraPreviewViewport(BuildContext context, Rect redBox) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return redBox;
    }

    final scaleX = redBox.width / size.width;
    final scaleY = redBox.height / size.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final width = size.width * scale;
    final height = size.height * scale;
    final offsetX = redBox.left + (redBox.width - width) / 2;
    final offsetY = redBox.top + (redBox.height - height) / 2;

    return Rect.fromLTWH(offsetX, offsetY, width, height);
  }

  /// Camera media window constraints
  static BoxConstraints cameraMediaConstraints(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return BoxConstraints(
      maxWidth: size.width,
      maxHeight: size.height,
    );
  }

  /// Tools panel width for landscape tablets
  static double toolsPanelWidth(BuildContext context) {
    if (isLandscapeTablet(context)) {
      final vw = MediaQuery.sizeOf(context).width / 100;
      return (15 * 16.0).clamp(0.0, 23 * vw).toDouble();
    }
    return double.infinity;
  }

  /// Tools panel max height for tablets
  static double toolsPanelMaxHeight(BuildContext context) {
    final dvh = MediaQuery.sizeOf(context).height / 100;
    return (72 * dvh).clamp(0, 34 * 16);
  }

  /// Tools panel bottom offset
  static double toolsPanelBottomOffset(BuildContext context) {
    // calc(88px + env(safe-area-inset-bottom))
    return 88 + MediaQuery.of(context).padding.bottom;
  }

  /// Action buttons vertical offset for landscape
  static double cameraActionsVerticalOffset(BuildContext context) {
    if (isLandscapeTablet(context)) {
      return MediaQuery.sizeOf(context).height / 2 - 60; // Center vertically
    }
    return 0;
  }
}
