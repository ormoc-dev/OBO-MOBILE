import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AssetHelper {
  /// Get the correct asset path for different platforms
  static String getAssetPath(String assetName) {
    // For web, assets work with just the filename
    if (kIsWeb) {
      return assetName;
    }
    
    // For mobile (APK), we need the full assets/ path
    return 'assets/$assetName';
  }

  /// Load image with fallback handling
  static Widget loadImage({
    required String assetName,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    final assetPath = getAssetPath(assetName);
    
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // If image fails to load, show fallback or icon
        if (fallback != null) {
          return fallback;
        }
        
        // Default fallback to business icon
        return Icon(
          Icons.business,
          size: width ?? height ?? 60,
          color: const Color(0xFF4A5568),
        );
      },
    );
  }

  /// Load Ormoc seal with fallback
  static Widget loadOrmocSeal({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return loadImage(
      assetName: 'ormoc_seal.png',
      width: width,
      height: height,
      fit: fit,
      fallback: Icon(
        Icons.account_balance,
        size: width ?? height ?? 60,
        color: const Color(0xFF4A5568),
      ),
    );
  }

  /// Load OBO logo with fallback
  static Widget loadOboLogo({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return loadImage(
      assetName: 'obo_logo.png',
      width: width,
      height: height,
      fit: fit,
      fallback: Icon(
        Icons.business,
        size: width ?? height ?? 60,
        color: const Color(0xFF4A5568),
      ),
    );
  }
}
