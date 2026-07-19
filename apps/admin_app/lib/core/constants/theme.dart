import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core
  static const Color primary = Color(0xFF5B3DF5);
  static const Color primaryLight = Color(0xFF7B61FF);
  static const Color primaryDark = Color(0xFF4A2FD4);
  static const Color secondary = Color(0xFF00D09C);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8E8E);

  // Backgrounds
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Colors.white;
  static const Color card = Colors.white;

  // Text
  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color success = Color(0xFF00D09C);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFFF4757);
  static const Color info = Color(0xFF3B82F6);

  // Surfaces
  static const Color surfaceDim = Color(0xFFF3F4F6);
  static const Color surfaceDark = Color(0xFFE5E7EB);

  // Light status backgrounds
  static const Color successLight = Color(0xFFECFDF5);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color accentBg = Color(0xFFFFF1F0);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF0F1F5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF5B3DF5), Color(0xFF7B61FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF5B3DF5), Color(0xFF7B61FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00D09C), Color(0xFF00E6B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB800), Color(0xFFFFCF44)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF8C42), Color(0xFFFFB347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFFFF6BB5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status helpers
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
      case 'approved':
      case 'active':
        return success;
      case 'pending':
      case 'processing':
      case 'new':
      case 'pending_approval':
        return warning;
      case 'cancelled':
      case 'rejected':
      case 'failed':
        return error;
      case 'in_transit':
      case 'out_for_delivery':
        return info;
      default:
        return textSecondary;
    }
  }

  static LinearGradient statusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
      case 'approved':
      case 'active':
        return successGradient;
      case 'pending':
      case 'processing':
      case 'new':
      case 'pending_approval':
        return warningGradient;
      case 'cancelled':
      case 'rejected':
      case 'failed':
        return errorGradient;
      case 'in_transit':
      case 'out_for_delivery':
        return infoGradient;
      default:
        return primaryGradient;
    }
  }
}

class AppText {
  AppText._();

  static const TextStyle h1 = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
    letterSpacing: -0.5, height: 1.2,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
    letterSpacing: -0.3, height: 1.3,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
    height: 1.3,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
    height: 1.4,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
    height: 1.4,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary,
    letterSpacing: 0.5, height: 1.3,
  );
  static const TextStyle button = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
    height: 1.3,
  );
}

class AppShadows {
  AppShadows._();

  static BoxShadow get soft => BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 12, offset: const Offset(0, 4),
  );
  static BoxShadow get medium => BoxShadow(
    color: Colors.black.withValues(alpha: 0.08),
    blurRadius: 20, offset: const Offset(0, 8),
  );
  static BoxShadow get strong => BoxShadow(
    color: Colors.black.withValues(alpha: 0.12),
    blurRadius: 28, offset: const Offset(0, 12),
  );
  static BoxShadow get colored => BoxShadow(
    color: AppColors.primary.withValues(alpha: 0.2),
    blurRadius: 20, offset: const Offset(0, 8),
  );
}

class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double full = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}
