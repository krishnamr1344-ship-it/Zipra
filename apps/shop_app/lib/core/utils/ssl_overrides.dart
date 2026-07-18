import 'dart:io';
import 'package:flutter/foundation.dart';

const bool _useInsecureSsl = bool.fromEnvironment(
  'USE_INSECURE_SSL',
  defaultValue: kDebugMode,
);

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => _useInsecureSsl;
  }
}

void configureSslOverrides() {
  if (_useInsecureSsl) {
    HttpOverrides.global = _DevHttpOverrides();
  }
}
