import 'package:permission_handler/permission_handler.dart' as ph;

enum AppPermission { location, notification, camera, photos }

enum PermissionStatus { granted, denied, permanentlyDenied }

class PermissionService {
  ph.Permission _map(AppPermission type) {
    switch (type) {
      case AppPermission.location:
        return ph.Permission.locationWhenInUse;
      case AppPermission.notification:
        return ph.Permission.notification;
      case AppPermission.camera:
        return ph.Permission.camera;
      case AppPermission.photos:
        return ph.Permission.photos;
    }
  }

  PermissionStatus _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted) return PermissionStatus.granted;
    if (status.isPermanentlyDenied) return PermissionStatus.permanentlyDenied;
    return PermissionStatus.denied;
  }

  Future<PermissionStatus> check(AppPermission type) async {
    final permission = _map(type);
    final status = await permission.status;
    return _mapStatus(status);
  }

  Future<PermissionStatus> request(AppPermission type) async {
    final permission = _map(type);
    final status = await permission.request();
    return _mapStatus(status);
  }

  Future<bool> openSettings() {
    return ph.openAppSettings();
  }

  Future<PermissionStatus> ensure(AppPermission type) async {
    final status = await check(type);
    if (status == PermissionStatus.granted) return status;
    if (status == PermissionStatus.permanentlyDenied) return status;
    return request(type);
  }
}
