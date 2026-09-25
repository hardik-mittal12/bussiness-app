import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/platform/platform_io.dart';
import '../theme/app_theme.dart';

class AppLogoImage extends StatelessWidget {
  final String? logoPath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppLogoImage({
    super.key,
    required this.logoPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (logoPath == null || logoPath!.trim().isEmpty) {
      return Icon(
        Icons.account_balance_wallet_rounded,
        color: Colors.white,
        size: (width != null ? width! * 0.5 : 22),
      );
    }

    if (kIsWeb) {
      // In web preview, display a sleek branded badge or placeholder
      return Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.business_rounded,
          color: AppColors.primary,
          size: (width != null ? width! * 0.55 : 24),
        ),
      );
    }

    // On native desktop (Windows, macOS), load local file
    try {
      final file = File(logoPath!);
      if (file.existsSync()) {
        return Image.file(
          file as dynamic,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.business_rounded,
            color: AppColors.primary,
            size: (width != null ? width! * 0.5 : 22),
          ),
        );
      }
    } catch (_) {}

    return Icon(
      Icons.account_balance_wallet_rounded,
      color: Colors.white,
      size: (width != null ? width! * 0.5 : 22),
    );
  }
}
