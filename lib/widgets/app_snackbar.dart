import 'package:flutter/material.dart';
import '../constants/theme.dart';

enum SnackbarType { success, warning, error, info }

class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.success,
    int durationSeconds = 3,
  }) {
    final (Color bg, IconData icon) = switch (type) {
      SnackbarType.success => (AppColors.success, Icons.check_circle_rounded),
      SnackbarType.warning => (AppColors.warning, Icons.warning_amber_rounded),
      SnackbarType.error => (AppColors.error, Icons.error_rounded),
      SnackbarType.info => (const Color(0xFF0288D1), Icons.info_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: Duration(seconds: durationSeconds),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
  }
}
