import 'dart:async';

import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

/// Sesión de la app con los usuarios y permisos de la Intranet.
///
/// - Inicia sesión con /api/auth/login de la Intranet (misma contraseña, mismo
///   bloqueo por intentos fallidos).
/// - El acceso lo da el permiso VER del módulo APP_MONTACARGAS y los reportes por
///   cliente el de APP_MONTACARGAS_REPORTES; ambos se asignan en la Intranet.
class AuthProvider with ChangeNotifier {
  static const _timeout = Duration(seconds: 25);

  AuthProvider() {
    Api.onSesionVencida = () => _expireSession(
        'Tu sesión terminó. Inicia sesión de nuevo.');
  }

  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  final int _sessionTimeoutMinutes = 30; // Igual que la Intranet

  String _usuario = '';
  String _nombre = '';
  bool _puedeReportes = false;

  String get usuario => _usuario;
  String get nombre => _nombre;
  bool get puedeReportes => _puedeReportes;
  DateTime? get sessionStartTime => _sessionStartTime;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  bool get isLoggedIn => Api.tieneSesion;

  /// Inicia sesión. Lanza [PasswordTemporalException] si la Intranet pide
  /// cambiar la contraseña (entonces la pantalla de login muestra el cambio y
  /// después llama a [cargarPermisos]).
  Future<void> login(String username, String password) async {
    Api.limpiarSesion();
    final response = await _llamar(() => Api.post(
          '/auth/login',
          {'USUARIO': username, 'PWD': password},
          avisar401: false,
        ));

    if (response.statusCode == 401) {
      throw InvalidCredentialsException(
          Api.mensaje(response) ?? 'Usuario o contraseña incorrectos');
    }
    if (response.statusCode == 403) {
      throw UserNotActiveException(
          Api.mensaje(response) ?? 'El usuario no está activo');
    }
    if (response.statusCode == 429) {
      throw InvalidCredentialsException(
          Api.mensaje(response) ?? 'Demasiados intentos fallidos');
    }
    if (response.statusCode != 200) {
      throw NetworkException(
          Api.mensaje(response) ?? 'Error del servidor (${response.statusCode}).');
    }

    final data = Api.data(response);
    if (data is Map && data['DEBE_CAMBIAR_PWD'] == true) {
      throw PasswordTemporalException();
    }
    await cargarPermisos();
  }

  /// Cambia la contraseña temporal (misma regla que la Intranet).
  /// Devuelve null si se cambió o el mensaje de error.
  Future<String?> cambiarPassword(String actual, String nueva) async {
    final response = await _llamar(() => Api.post(
          '/auth/cambiar-password',
          {'ACTUAL': actual, 'NUEVA': nueva},
        ));
    if (response.statusCode == 200) return null;
    return Api.mensaje(response) ?? 'No se pudo cambiar la contraseña.';
  }

  /// Revisa que el usuario tenga acceso a la app y qué puede ver.
  Future<void> cargarPermisos() async {
    final response =
        await _llamar(() => Api.get('/app-montacargas/permisos'));

    if (response.statusCode == 403) {
      await logout();
      throw SinPermisoException(
          'Tu usuario no tiene acceso a esta app. Pide en la Intranet el '
          'permiso "APP MONTACARGAS".');
    }
    if (response.statusCode != 200) {
      await logout();
      throw NetworkException(
          Api.mensaje(response) ?? 'Error del servidor (${response.statusCode}).');
    }

    final data = Api.data(response);
    final permisos = data is Map ? data : const {};
    _usuario = '${permisos['USUARIO'] ?? ''}';
    _nombre = '${permisos['NOMBRE'] ?? ''}';
    _puedeReportes = permisos['REPORTES'] == true;
    _startSessionTimer();
    notifyListeners();
  }

  Future<dynamic> _llamar(Future<dynamic> Function() peticion) async {
    try {
      return await peticion().timeout(_timeout);
    } on TimeoutException {
      throw NetworkException('El servidor tardó demasiado en responder.');
    } on AppException {
      rethrow;
    } catch (_) {
      throw NetworkException('No se pudo conectar con el servidor.');
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
        _expireSession('Tu sesión ha expirado. Inicia sesión de nuevo.');
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

  bool _expirando = false;

  void _expireSession(String mensaje) {
    if (_expirando) return;
    _expirando = true;
    logout().whenComplete(() => _expirando = false);
    appMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.danger),
    );
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Cierra la sesión en el servidor y limpia los datos locales.
  /// Devuelve true si el servidor confirmó el cierre. No navega.
  Future<bool> logout([BuildContext? context]) async {
    final teniaSesion = Api.tieneSesion;
    _usuario = '';
    _nombre = '';
    _puedeReportes = false;
    _sessionStartTime = null;
    cancelSessionTimer();

    if (!teniaSesion) {
      notifyListeners();
      return true;
    }
    try {
      final response = await Api.post('/auth/logout', null, avisar401: false)
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error de red al cerrar sesión: $e');
      return false;
    } finally {
      Api.limpiarSesion();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    cancelSessionTimer();
    super.dispose();
  }
}

class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class InvalidCredentialsException extends AppException {
  InvalidCredentialsException(super.message);
}

class UserNotActiveException extends AppException {
  UserNotActiveException(super.message);
}

class SinPermisoException extends AppException {
  SinPermisoException(super.message);
}

class PasswordTemporalException extends AppException {
  PasswordTemporalException()
      : super('Debes cambiar tu contraseña temporal antes de continuar.');
}
