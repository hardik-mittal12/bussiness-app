import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/business_profile_service.dart';
import '../../core/platform/platform_io.dart';
import '../theme/app_theme.dart';

class AppLogoImage extends StatelessWidget {
  final Uint8List? logoBytes;
  final String? logoPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? fallbackColor;
  final double? fallbackIconSize;
  final Widget? fallbackWidget;

  const AppLogoImage({
    super.key,
    this.logoBytes,
    this.logoPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallbackColor,
    this.fallbackIconSize,
    this.fallbackWidget,
  });

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;
    return Center(
      child: Icon(
        Icons.business_rounded,
        color: fallbackColor ?? AppColors.primary,
        size: fallbackIconSize ?? (width != null ? width! * 0.55 : 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Explicit in-memory bytes passed
    if (logoBytes != null && logoBytes!.isNotEmpty) {
      return Image.memory(
        logoBytes!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    // 2. Explicit file path passed
    if (logoPath != null && logoPath!.trim().isNotEmpty && !kIsWeb) {
      try {
        final file = File(logoPath!.trim());
        if (file.existsSync()) {
          return Image.file(
            file as dynamic,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        }
      } catch (_) {}
    }

    // 3. Contextual fallback: listen to BusinessProfileService
    try {
      final profileService = Provider.of<BusinessProfileService>(context, listen: true);
      final bytes = profileService.currentLogoBytes;
      if (bytes != null && bytes.isNotEmpty) {
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      }

      final pLogo = profileService.currentProfile?.logoPath;
      if (pLogo != null && pLogo.trim().isNotEmpty && !kIsWeb) {
        final file = File(pLogo.trim());
        if (file.existsSync()) {
          return Image.file(
            file as dynamic,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        }
      }
    } catch (_) {}

    return _buildFallback();
  }
}
