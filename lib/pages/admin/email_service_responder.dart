import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailResponderService {
  static Future<bool> sendResponderAccountEmail({
    required String email,
    required String username,
    required String password,
    required String role,
  }) async {
    // ✅ Use your correct EmailJS credentials
    const serviceId = 'service_2szlwem';
    const templateId = 'template_3kms2ad'; // ✅ Correct template ID
    const userId = '7jNR_ojNzuUqezHRi';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            // ⚙️ These must match your EmailJS template variables exactly
            'name': username, // {{name}}
            'email': email, // {{email}}
            'responder_password': password, // {{responder_password}}
            'responder_role': role, // {{responder_role}}
          },
        }),
      );

      print("📩 EmailJS Response: ${response.statusCode}");
      print("📩 Response body: ${response.body}");

      if (response.statusCode == 200) {
        print("✅ Email successfully sent to $email");
        return true;
      } else {
        throw Exception(
          "EmailJS failed with status ${response.statusCode}: ${response.body}",
        );
      }
    } catch (e) {
      print("❌ Email sending failed: $e");
      return false;
    }
  }
}
