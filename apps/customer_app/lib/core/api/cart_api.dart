part of 'api_service_base.dart';

// ─── Cart Methods (user-facing) ────────────────────────────────

mixin CartApi on ApiServiceBase {
  // Cart operations are handled locally via CartNotifier.
  // This mixin exists for future server-side cart sync if needed.
}
