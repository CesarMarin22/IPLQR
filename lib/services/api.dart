import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente del backend de la Intranet IPL.
///
/// La app usa el mismo inicio de sesión que la Intranet: los usuarios, perfiles y
/// permisos se administran allá (módulo "APP MONTACARGAS"). La sesión es la
/// cookie que devuelve /api/auth/login y se manda en cada petición.
/// SAP ya no se consulta desde el celular: lo hace el servidor.
class Api {
  Api._();

  /// URL pública del backend (con certificado válido).
  static const String baseUrl = 'https://iplsap10.ddns.net:8443/api';

  static final http.Client _client = http.Client();
  static String _cookie = '';

  /// Se llama cuando el servidor responde 401 (sesión vencida o cerrada).
  static void Function()? onSesionVencida;

  static bool get tieneSesion => _cookie.isNotEmpty;

  static void limpiarSesion() => _cookie = '';

  static Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$baseUrl$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  static Map<String, String> _headers({bool json = false}) => {
        if (_cookie.isNotEmpty) 'Cookie': _cookie,
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Flask reenvía la cookie "session" cuando la sesión cambia: siempre se guarda la última.
  static void _guardarCookie(http.Response r) {
    final setCookie = r.headers['set-cookie'];
    if (setCookie == null) return;
    final m = RegExp(r'(?:^|[,\s])session=([^;]*)').firstMatch(setCookie);
    if (m == null) return;
    final valor = m.group(1) ?? '';
    _cookie = valor.isEmpty ? '' : 'session=$valor';
  }

  static http.Response _revisar(http.Response r, {bool avisar401 = true}) {
    _guardarCookie(r);
    if (r.statusCode == 401 && avisar401 && _cookie.isNotEmpty) {
      _cookie = '';
      onSesionVencida?.call();
    }
    // Flask manda "application/json" sin charset y http lo leería como latin1
    // (los acentos saldrían mal en response.body): se marca como UTF-8.
    final tipo = r.headers['content-type'] ?? '';
    if (tipo.startsWith('application/json') && !tipo.contains('charset')) {
      return http.Response.bytes(
        r.bodyBytes,
        r.statusCode,
        headers: {...r.headers, 'content-type': '$tipo; charset=utf-8'},
        request: r.request,
      );
    }
    return r;
  }

  static Future<http.Response> get(String path,
      [Map<String, String>? query]) async {
    final r = await _client.get(uri(path, query), headers: _headers());
    return _revisar(r);
  }

  static Future<http.Response> post(String path, Object? body,
      {bool avisar401 = true}) async {
    final r = await _client.post(
      uri(path),
      headers: _headers(json: true),
      body: jsonEncode(body ?? {}),
    );
    return _revisar(r, avisar401: avisar401);
  }

  /// Mensaje que manda el backend ({"ok": false, "message": "..."}), si lo hay.
  static String? mensaje(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map && d['message'] is String) return d['message'] as String;
    } catch (_) {}
    return null;
  }

  /// "data" de la respuesta estándar del backend.
  static dynamic data(http.Response r) {
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      return d is Map ? d['data'] : null;
    } catch (_) {
      return null;
    }
  }
}
