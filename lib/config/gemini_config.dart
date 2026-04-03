import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Gemini API anahtarı — .env / env.example üzerinden okunur.
/// Kendi key'iniz: https://aistudio.google.com/apikey
String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
