import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF111827);
  static const Color primaryLight = Color(0xFF1F2937);
  static const Color primaryDark = Color(0xFF030712);
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFED7AA);
  static const Color accentDark = Color(0xFFEA580C);
  static const Color accentBg = Color(0xFFFFF7ED);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color surfaceDark = Color(0xFFE2E8F0);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textOnDark = Colors.white;

  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  static const Color divider = Color(0xFFE2E8F0);

  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFEDE9FE);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealLight = Color(0xFFCCFBF1);

  static const Color orderPending = Color(0xFFF59E0B);
  static const Color orderPendingLight = Color(0xFFFEF3C7);
  static const Color orderConfirmed = Color(0xFF3B82F6);
  static const Color orderConfirmedLight = Color(0xFFDBEAFE);
  static const Color orderPacked = Color(0xFF8B5CF6);
  static const Color orderPackedLight = Color(0xFFEDE9FE);
  static const Color orderOutForDelivery = Color(0xFF14B8A6);
  static const Color orderOutForDeliveryLight = Color(0xFFCCFBF1);
  static const Color orderDelivered = Color(0xFF10B981);
  static const Color orderDeliveredLight = Color(0xFFD1FAE5);
  static const Color orderCancelled = Color(0xFFEF4444);
  static const Color orderCancelledLight = Color(0xFFFEE2E2);

  static const List<Color> chartColors = [
    Color(0xFFF97316),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
  ];

  static LinearGradient statusGradient(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return warningGradient;
      case 'confirmed':
        return infoGradient;
      case 'packed':
        return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'out_for_delivery':
        return const LinearGradient(colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'delivered':
        return successGradient;
      case 'cancelled':
        return const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF87171)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:
        return const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return orderPending;
      case 'confirmed': return orderConfirmed;
      case 'packed': return orderPacked;
      case 'out_for_delivery': return orderOutForDelivery;
      case 'delivered': return orderDelivered;
      case 'cancelled': return orderCancelled;
      default: return const Color(0xFF94A3B8);
    }
  }

  static Color statusLightColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return orderPendingLight;
      case 'confirmed': return orderConfirmedLight;
      case 'packed': return orderPackedLight;
      case 'out_for_delivery': return orderOutForDeliveryLight;
      case 'delivered': return orderDeliveredLight;
      case 'cancelled': return orderCancelledLight;
      default: return const Color(0xFFF1F5F9);
    }
  }

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF111827), Color(0xFF1F2937)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppText {
  AppText._();

  static const TextStyle h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 14, color: AppColors.textPrimary);
  static const TextStyle bodySmall = TextStyle(fontSize: 13, color: AppColors.textSecondary);
  static const TextStyle caption = TextStyle(fontSize: 12, color: AppColors.textHint);
  static const TextStyle label = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5);
  static const TextStyle button = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3);
}

class AppShadows {
  static const soft = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const medium = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );
  static const strong = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}
