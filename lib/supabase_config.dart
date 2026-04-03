import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase yapılandırması — değerler .env / env.example üzerinden gelir.
/// Supabase Dashboard: https://supabase.com/dashboard > Projeniz > Settings > API
String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
