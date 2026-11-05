import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:proyecto_qr/models/user.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class AuthProvider with ChangeNotifier {
  String _sessionCookie = '';
  String _routeIdCookie = '';
  String _authToken = '';
  User? _authenticatedUser;
  int? _userProfileId;
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  final int _sessionTimeoutMinutes = 30; // Tiempo de sesión en minutos

  int? get userProfileId => _userProfileId;
  String get sessionCookie => _sessionCookie;
  String get routeIdCookie => _routeIdCookie;
  String get authToken => _authToken;
  User? get authenticatedUser => _authenticatedUser;
  DateTime? get sessionStartTime => _sessionStartTime;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  bool get isLoggedIn => _sessionCookie.isNotEmpty;

  static const apiUri = 'http://68.155.144.63:8081/api/usuarios';
  static const _sapBase = 'https://68.155.144.63:50000/b1s/v1';
  static const _timeout = Duration(seconds: 25);

  IOClient _sapClient() {
    final client = HttpClient()
      ..connectionTimeout = _timeout
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(client);
  }

  /// Valida al usuario y abre sesión en SAP B1.
  /// No navega: la pantalla que llama decide a dónde ir.
  /// El parámetro [context] se conserva por compatibilidad y no se usa.
  Future<void> login(String username, String password,
      [BuildContext? context]) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse(apiUri)).timeout(_timeout);
    } on TimeoutException {
      throw NetworkException('El servidor tardó demasiado en responder.');
    } catch (_) {
      throw NetworkException('No se pudo conectar con el servidor.');
    }

    if (response.statusCode != 200) {
      throw NetworkException(
          'Error del servidor de usuarios (${response.statusCode}).');
    }

    final List<dynamic> usuarios = json.decode(response.body);
    final usuario = usuarios.cast<Map<String, dynamic>?>().firstWhere(
          (user) => user?['USUARIO'] == username,
          orElse: () => null,
        );

    if (usuario == null) {
      throw UserNotFoundException('Usuario incorrecto');
    }
    if (usuario['PWD'] != password) {
      throw InvalidCredentialsException('Contraseña incorrecta');
    }
    if (usuario['ACTIVO'] != 1) {
      throw UserNotActiveException('El usuario no está activo');
    }

    const requestData = {
      "UserName": "manager",
      "Password": "yottak01",
      "CompanyDB": "B1_IPL"
    };

    final ioClient = _sapClient();
    try {
      final loginResponse = await ioClient
          .post(
            Uri.parse('$_sapBase/Login'),
            headers: {"Content-Type": "application/json"},
            body: json.encode(requestData),
          )
          .timeout(_timeout);

      if (loginResponse.statusCode != 200) {
        throw NetworkException(
            'SAP rechazó el inicio de sesión (${loginResponse.statusCode}).');
      }

      final jsonResponse = json.decode(loginResponse.body);
      final cookiesMap = parseCookies(loginResponse.headers['set-cookie']);

      _authToken = jsonResponse['SessionId'] ?? '';
      _sessionCookie = cookiesMap['B1SESSION'] ?? _authToken;
      _routeIdCookie = cookiesMap['ROUTEID'] ?? '';
      _userProfileId = usuario['PERFIL'] as int?;

      _startSessionTimer();
      notifyListeners();
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      throw NetworkException('SAP tardó demasiado en responder.');
    } catch (e) {
      debugPrint('Error login SAP: $e');
      throw NetworkException('Error al conectar con SAP.');
    } finally {
      ioClient.close();
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionStartTime = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final start = _sessionStartTime;
      if (start == null || !isLoggedIn) return;
      if (DateTime.now().difference(start) >
          Duration(minutes: _sessionTimeoutMinutes)) {
        _expireSession();
      }
    });
  }

  /// Reinicia el contador de expiración (p. ej. ante actividad del usuario).
  void resetSession() {
    _sessionStartTime = DateTime.now();
  }

  void cancelSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  void _expireSession() {
    logout();
    appMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Tu sesión ha expirado. Inicia sesión de nuevo.'),
        backgroundColor: AppColors.danger,
      ),
    );
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Cierra la sesión en SAP y limpia los datos locales.
  /// Devuelve true si SAP confirmó el cierre. No navega.
  Future<bool> logout([BuildContext? context]) async {
    final token = _authToken;
    final session = _sessionCookie;
    final routeId = _routeIdCookie;

    _authenticatedUser = null;
    _sessionCookie = '';
    _routeIdCookie = '';
    _authToken = '';
    _userProfileId = null;
    _sessionStartTime = null;
    cancelSessionTimer();
    notifyListeners();

    if (session.isEmpty) return true;

    final ioClient = _sapClient();
    try {
      final response = await ioClient.post(
        Uri.parse('$_sapBase/Logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Cookie': 'B1SESSION=$session; ROUTEID=$routeId',
        },
      ).timeout(_timeout);
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Error de red al cerrar sesión: $e');
      return false;
    } finally {
      ioClient.close();
    }
  }

  Map<String, String> parseCookies(String? cookies) {
    final cookieMap = <String, String>{};
    if (cookies == null) return cookieMap;
    for (final match
        in RegExp(r'(B1SESSION|ROUTEID)=([^;,\s]+)').allMatches(cookies)) {
      cookieMap[match.group(1)!] = match.group(2)!;
    }
    return cookieMap;
  }

  void setUserProfileId(int id) {
    _userProfileId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    cancelSessionTimer();
    super.dispose();
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class UserNotFoundException implements Exception {
  final String message;
  UserNotFoundException(this.message);
}

class InvalidCredentialsException implements Exception {
  final String message;
  InvalidCredentialsException(this.message);
}

class UserNotActiveException implements Exception {
  final String message;
  UserNotActiveException(this.message);
}
