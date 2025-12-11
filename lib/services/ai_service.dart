import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class AIService {
  static const String baseUrl =
      'https://us-central1-emotional-dairy-b3cc0.cloudfunctions.net/processEntry';

  static Future<Map<String, dynamic>> processEntry(
    String text,
    String? audioUrl,
  ) async {
    final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'text': text, 'audioUrl': audioUrl}),
    );
    if (res.statusCode != 200) {
      // Try to provide a helpful error message for common failures.
      String body = res.body;
      try {
        final parsed = jsonDecode(res.body);
        if (parsed is Map && parsed.containsKey('error')) {
          body = parsed['error'].toString();
        }
      } catch (_) {}

      if (res.statusCode == 410 && body.contains('huggingface')) {
        throw Exception(
          'AI processing failed: HuggingFace API returned 410. The cloud function appears to be calling the deprecated endpoint. Update the function to use https://router.huggingface.co instead of https://api-inference.huggingface.co. Full response: $body',
        );
      }

      throw Exception('AI processing failed: $body');
    }

    return jsonDecode(res.body);
  }

  // Backwards-compatible alias expected by some callers.
  static Future<Map<String, dynamic>> analyzeEntry(
    String text,
    String? audioUrl,
  ) async {
    return processEntry(text, audioUrl);
  }
}
