// api/api_client.dart
//
// Thin HTTP helper for the Opportunity module.
// Mirrors the web `api` axios instance: base URL + Bearer auth + tenant slug.
//
// If you already have `api_helpers/api_method.dart`, you can delete this file
// and route the calls through your existing helper instead — every call site
// uses the small surface below (getJson / postJson / put / delete / multipart).

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String detail;
  ApiException(this.statusCode, this.detail);
  @override
  String toString() => detail;
}

class ApiClient {
  // Same base URL used across the Flutter app.
  static const String baseUrl = 'https://ascent.crm.azcentrix.com:4447/api/v1';

  static Future<Map<String, String>> _headers({bool json = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final tenant = prefs.getString('tenant_slug') ?? '';
    final h = <String, String>{
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      // Adjust this header name to whatever your backend expects if different.
      if (tenant.isNotEmpty) 'X-Tenant-Slug': tenant,
    };
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  static String _detailFrom(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        final d = body['detail'];
        if (d is List) {
          return d
              .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
              .join(', ');
        }
        return d.toString();
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final qp = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) qp[k] = v.toString();
    });
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  // ── GET → dynamic (List or Map) ───────────────────────────────────────────
  static Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── POST JSON ──────────────────────────────────────────────────────────────
  static Future<dynamic> postJson(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── PUT JSON ─────────────────────────────────────────────────────────────────
  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── PATCH (query params; matches /workorders/{id}/progress) ─────────────────
  static Future<dynamic> patch(String path, {Map<String, dynamic>? query}) async {
    final res = await http.patch(_uri(path, query), headers: await _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── DELETE ───────────────────────────────────────────────────────────────────
  static Future<dynamic> delete(String path) async {
    final res = await http.delete(_uri(path), headers: await _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── Multipart POST (PO doc upload, consignee bulk import) ──────────────────
  static Future<dynamic> multipart(
    String path, {
    Map<String, String> fields = const {},
    List<MultipartFile> files = const [],
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(await _headers(json: false));
    req.fields.addAll(fields);
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes(
        f.field,
        f.bytes,
        filename: f.filename,
      ));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }

  // ── Raw bytes (file preview / download) ─────────────────────────────────────
  static Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers(json: false));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    throw ApiException(res.statusCode, _detailFrom(res));
  }
}

class MultipartFile {
  final String field;
  final String filename;
  final Uint8List bytes;
  MultipartFile({required this.field, required this.filename, required this.bytes});
}
