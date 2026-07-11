import 'dart:io';
import 'package:flutter/foundation.dart';

/// Controls whether insecure SSL (self-signed certs) is allowed.
/// Defaults to [kDebugMode] but can be overridden via:
///   --dart-define=USE_INSECURE_SSL=true
///   --dart-define=USE_INSECURE_SSL=false
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

/// Call once at app startup to configure SSL/TLS behavior.
/// - **Debug**: allows self-signed certificates by default (for local dev).
/// - **Release**: strict certificate validation — MITM attacks are blocked.
///
/// Use `--dart-define=USE_INSECURE_SSL=false` even in debug to enforce strict
/// validation, or `--dart-define=USE_INSECURE_SSL=true` in release for testing.
void configureSslOverrides() {
  if (_useInsecureSsl) {
    HttpOverrides.global = _DevHttpOverrides();
  }
}
