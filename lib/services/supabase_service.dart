import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _client;

  SupabaseService._();

  static SupabaseService get instance {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  SupabaseClient get client => _client;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('Supabase: .env file not found, skipping initialization ($e)');
      return;
    }

    final url = dotenv.env['SUPABASE_URL'];
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || anonKey == null) {
      debugPrint('Supabase: SUPABASE_URL or SUPABASE_ANON_KEY not set, skipping');
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);

    instance._client = Supabase.instance.client;

    if (kDebugMode) {
      debugPrint('Supabase connected: $url');
    }
  }

  // ─── Example: Insert ───────────────────────────────────────────

  Future<Map<String, dynamic>?> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.from(table).insert(data).select().single();
    return response;
  }

  // ─── Example: Fetch all ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAll(String table) async {
    final response = await _client.from(table).select();
    return response;
  }

  // ─── Example: Fetch by column ──────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchWhere(
    String table,
    String column,
    dynamic value,
  ) async {
    final response = await _client.from(table).select().eq(column, value);
    return response;
  }

  // ─── Example: Update ───────────────────────────────────────────

  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String column,
    dynamic value,
  ) async {
    await _client.from(table).update(data).eq(column, value);
  }

  // ─── Example: Delete ───────────────────────────────────────────

  Future<void> delete(
    String table,
    String column,
    dynamic value,
  ) async {
    await _client.from(table).delete().eq(column, value);
  }

  // ─── Auth helpers (optional, if using Supabase Auth) ───────────

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
