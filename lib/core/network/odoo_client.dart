// Core Odoo JSON-RPC client for authenticating and calling model methods
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/odoo_session.dart';

class OdooClient {
  late final Dio _dio;
  final Logger _log = Logger();
  OdooSession? _session;

  OdooClient({required String baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_session != null) {
          options.headers['Cookie'] = 'session_id=${_session!.sessionId}';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        _log.e('Odoo RPC Error: ${e.message}');
        handler.next(e);
      },
    ));
  }

  void setBaseUrl(String url) {
    var formattedUrl = url.trim();
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
      formattedUrl = 'http://$formattedUrl';
    }
    _dio.options.baseUrl = formattedUrl;
  }

  // ── Authenticate ─────────────────────────────────────────────────────────
  Future<OdooSession> authenticate({
    required String db,
    required String login,
    required String password,
  }) async {
    final response = await _dio.post(
      '/web/session/authenticate',
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'db': db,
          'login': login,
          'password': password,
        },
      }),
    );

    final data = response.data is String
        ? jsonDecode(response.data)
        : Map<String, dynamic>.from(response.data);

    _checkError(data);

    final result = data['result'];
    if (result == null || result['uid'] == null || result['uid'] == false) {
      throw Exception(
          'Invalid credentials. Please check your login and password.');
    }

    final uid = result['uid'] as int;

    // Extract session_id from response set-cookie header
    String sessionId = '';
    final cookies = response.headers['set-cookie'];
    if (cookies != null) {
      for (final cookie in cookies) {
        final match = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
        if (match != null) {
          sessionId = match.group(1)!;
          break;
        }
      }
    }

    final userName =
        result['name'] as String? ?? result['username'] as String? ?? login;

    _session = OdooSession(
      uid: uid,
      db: db,
      login: login,
      sessionId: sessionId,
      userName: userName,
    );
    return _session!;
  }

  // ── Databases ─────────────────────────────────────────────────────────────
  Future<List<String>> getDatabases() async {
    try {
      final response = await _post('/web/database/list', {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {},
      });
      if (response['result'] != null) {
        return List<String>.from(response['result']);
      }
    } catch (e) {
      _log.e('Failed to fetch databases: $e');
    }
    return [];
  }

  // ── Read Records ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List domain,
    required List<String> fields,
    int? limit,
    int? offset,
    String? order,
  }) async {
    final result = await callKw(
      model: model,
      method: 'search_read',
      args: [domain],
      kwargs: {
        'fields': fields,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        if (order != null) 'order': order,
      },
    );
    return List<Map<String, dynamic>>.from(result as List);
  }

  // ── Call Any Model Method ─────────────────────────────────────────────────
  Future<dynamic> callKw({
    required String model,
    required String method,
    List args = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    final response = await _post('/web/dataset/call_kw', {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        'model': model,
        'method': method,
        'args': args,
        'kwargs': {'context': _context(), ...kwargs},
      },
    });
    _checkError(response);
    return response['result'];
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(String path, Map body) async {
    final response = await _dio.post(path, data: jsonEncode(body));
    return response.data is String
        ? jsonDecode(response.data)
        : Map<String, dynamic>.from(response.data);
  }

  Map<String, dynamic> _context() => {
        'lang': 'en_US',
        'tz': 'Africa/Addis_Ababa',
        if (_session != null) 'uid': _session!.uid,
      };

  void _checkError(Map<String, dynamic> response) {
    if (response['error'] != null) {
      final err = response['error'];
      final msg =
          err?['data']?['message'] ?? err?['message'] ?? 'Unknown Odoo error';
      throw Exception(msg);
    }
  }

  void setSession(OdooSession session) => _session = session;
  OdooSession? get session => _session;
}
