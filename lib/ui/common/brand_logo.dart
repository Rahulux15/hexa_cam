import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/responsive.dart';

class BrandLogo extends StatelessWidget {
  final double iconSize;
  final double titleFontSize;
  final String? subtitle;
  final bool showText;
  final MainAxisAlignment alignment;

  const BrandLogo({
    super.key,
    this.iconSize = 44,
    this.titleFontSize = 20,
    this.subtitle = 'Scientific Imaging & Microscopy',
    this.showText = true,
    this.alignment = MainAxisAlignment.start,
  });

  static const String _svgMarkup =
      '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" fill="none">
  <defs><linearGradient id="gradA" x1="36" y1="128" x2="220" y2="128" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#8B5CF6"/><stop offset="1" stop-color="#4F46E5"/></linearGradient>
  <linearGradient id="gradB" x1="56" y1="56" x2="206" y2="214" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#FF4D6D"/><stop offset="0.5" stop-color="#FF7A18"/><stop offset="1" stop-color="#7C3AED"/></linearGradient>
  <filter id="blurGlow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="18" result="blur"/></filter></defs>
  <g opacity="0.35" filter="url(#blurGlow)"><circle cx="96" cy="92" r="54" fill="#8B5CF6"/><circle cx="162" cy="164" r="54" fill="#7C3AED"/></g>
  <rect x="72" y="72" width="112" height="112" rx="34" stroke="url(#gradA)" stroke-width="18"/>
  <path d="M94 78C117 88 138 88 162 76" stroke="url(#gradB)" stroke-width="18" stroke-linecap="round"/>
  <path d="M184 94C194 118 194 138 182 162" stroke="url(#gradB)" stroke-width="18" stroke-linecap="round"/>
  <path d="M162 182C138 194 118 194 94 182" stroke="url(#gradB)" stroke-width="18" stroke-linecap="round"/>
  <path d="M76 162C64 138 64 118 74 94" stroke="url(#gradB)" stroke-width="18" stroke-linecap="round"/></svg>''';

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final effectiveIconSize = isTab ? iconSize * 1.2 : iconSize;
    final effectiveTitleSize = isTab ? titleFontSize * 1.15 : titleFontSize;
    final effectiveSubtitleSize = isTab ? 14.0 : 12.0;

    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: effectiveIconSize,
          height: effectiveIconSize,
          child: SvgPicture.string(_svgMarkup),
        ),
        if (showText) ...[
          SizedBox(width: isTab ? 14 : 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [
                    Color(0xFFA78BFA),
                    Color(0xFF818CF8),
                    Color(0xFF22D3EE)
                  ]).createShader(bounds),
                  child: Text(
                    'Hexa-Cam',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: effectiveTitleSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: effectiveSubtitleSize,
                        color: const Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
