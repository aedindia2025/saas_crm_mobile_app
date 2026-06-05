import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiMethod {
  static Future<dynamic> getRequest({
    required String url,
    required Map<String, String> headers,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri, headers: headers);

      print("GET URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API GET Error: $e");
    }
  }

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

      print("POST URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API POST Error: $e");
    }
  }

  static Future<dynamic> patchRequest({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      print("PATCH URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API PATCH Error: $e");
    }
  }

  static Future<dynamic> putRequest({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      print("PUT URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API PUT Error: $e");
    }
  }

  static Future<dynamic> deleteRequest({
    required String url,
    required Map<String, String> headers,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.delete(uri, headers: headers);

      print("DELETE URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API DELETE Error: $e");
    }
  }

  static Future<dynamic> multipartRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
  }) async {
    try {
      final uri = Uri.parse(url);
      final request = http.MultipartRequest(method, uri);

      request.headers.addAll(headers);
      request.fields.addAll(fields);
      request.files.addAll(files);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("$method (Multipart) URL: $url");
      print("STATUS CODE: ${response.statusCode}");

      return {
        "statusCode": response.statusCode,
        "data": response.body.isEmpty ? null : jsonDecode(response.body),
      };
    } catch (e) {
      throw Exception("API Multipart Error: $e");
    }
  }
}
