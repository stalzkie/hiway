import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}

class AppConfig {
  /// Base URL for your FastAPI backend (no trailing slash).
  /// Example in `.env`: FASTAPI_BASE_URL=http://10.0.2.2:8000
  static String get fastApiBaseUrl {
    final url = dotenv.env['FASTAPI_BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception(
        'FASTAPI_BASE_URL is not set in .env. Please add it there.',
      );
    }
    return url;
  }
}
