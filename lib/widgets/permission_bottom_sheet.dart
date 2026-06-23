import 'package:flutter/material.dart';
import '../services/permission_service.dart';

Future<void> showPermissionSheet({
  required BuildContext context,
  required AppPermission permission,
  required String title,
  required String message,
  bool isPermanentlyDenied = false,
  VoidCallback? onGranted,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PermissionSheetBody(
      permission: permission,
      title: title,
      message: message,
      isPermanentlyDenied: isPermanentlyDenied,
      onGranted: onGranted,
    ),
  );
}

class _PermissionSheetBody extends StatefulWidget {
  final AppPermission permission;
  final String title;
  final String message;
  final bool isPermanentlyDenied;
  final VoidCallback? onGranted;

  const _PermissionSheetBody({
    required this.permission,
    required this.title,
    required this.message,
    this.isPermanentlyDenied = false,
    this.onGranted,
  });

  @override
  State<_PermissionSheetBody> createState() => _PermissionSheetBodyState();
}

class _PermissionSheetBodyState extends State<_PermissionSheetBody> {
  final _service = PermissionService();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Icon(
            _icon(),
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          if (!widget.isPermanentlyDenied) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _tryAgain,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Try Again',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _loading ? null : _openSettings,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text(
                'Open Settings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not Now',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon() {
    switch (widget.permission) {
      case AppPermission.location:
        return Icons.location_on_outlined;
      case AppPermission.notification:
        return Icons.notifications_outlined;
      case AppPermission.camera:
        return Icons.camera_alt_outlined;
      case AppPermission.photos:
        return Icons.photo_library_outlined;
    }
  }

  Future<void> _tryAgain() async {
    setState(() => _loading = true);
    final status = await _service.request(widget.permission);
    if (!mounted) return;
    if (status == PermissionStatus.granted) {
      Navigator.pop(context);
      widget.onGranted?.call();
    } else if (status == PermissionStatus.permanentlyDenied) {
      setState(() => _loading = false);
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    setState(() => _loading = true);
    await _service.openSettings();
    if (!mounted) return;
    final status = await _service.check(widget.permission);
    if (!mounted) return;
    if (status == PermissionStatus.granted) {
      Navigator.pop(context);
      widget.onGranted?.call();
    } else {
      setState(() => _loading = false);
    }
  }
}
