

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiMethod {


  static Future<dynamic> postRequest({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse(url);

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      print("STATUS CODE: ${response.statusCode}");
      print("RESPONSE: ${response.body}");

      return {
        "statusCode": response.statusCode,
        "data": jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API Error: $e");
    }
  }


}