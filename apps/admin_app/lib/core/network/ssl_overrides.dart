import 'dart:io';

class _NoCertCheck extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, _, _) => true;
  }
}

void configureSslOverrides() {
  HttpOverrides.global = _NoCertCheck();
}
