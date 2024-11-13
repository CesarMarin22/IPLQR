import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:proyecto_qr/models/user.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'dart:async';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import '../screens/sesion.dart';
import 'package:http/http.dart' as http;

class AuthProvider with ChangeNotifier {
  String _sessionCookie = '';
  String _routeIdCookie = '';
  String _authToken = '';
  User? _authenticatedUser;
  int? _userProfileId;
  Timer? _sessionTimer;
  DateTime? _sessionStartTime;
  int _sessionTimeoutMinutes = 30; // Tiempo de sesión en minutos

  int? get userProfileId => _userProfileId;
  String get sessionCookie => _sessionCookie;
  String get routeIdCookie => _routeIdCookie;
  String get authToken => _authToken;
  User? get authenticatedUser => _authenticatedUser;
  DateTime? get sessionStartTime => _sessionStartTime;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  static const apiUri = 'http://10.2.0.7:8081/api/usuarios';

  Future<void> login(
      String username, String password, BuildContext context) async {
    final response = await http.get(Uri.parse(apiUri));
    if (response.statusCode == 200) {
      final List<dynamic> usuarios = json.decode(response.body);
      final usuario = usuarios.firstWhere(
        (user) => user['USUARIO'] == username && user['PWD'] == password,
        orElse: () => null,
      );
      print(usuario);
      if (usuario == null) {
        throw UserNotFoundException('Usuario Incorrecto');
      }

      if (usuario['ACTIVO'] != 1) {
        throw UserNotActiveException('El usuario no está activo');
      }

      setUserProfileId(usuario['PERFIL']);

      // Realiza una solicitud de inicio de sesión a la API
      const apiLoginUrl = 'https://10.2.0.6:50000/b1s/v1/Login';
      final requestData = {
        "UserName": "manager",
        "Password": "yottak01",
        "CompanyDB": "B1_IPL"
      };

      // Configura un cliente HTTP personalizado para aceptar certificados autofirmados
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          return true; // Permite certificados autofirmados
        };

      // Crea un cliente IOClient con el cliente personalizado
      final ioClient = IOClient(client);

      try {
        final loginResponse = await ioClient.post(
          Uri.parse(apiLoginUrl),
          headers: {"Content-Type": "application/json"},
          body: json.encode(requestData),
        );

        if (loginResponse.statusCode == 200) {
          final jsonResponse = json.decode(loginResponse.body);
          _authToken = jsonResponse['SessionId'];
          final cookies = loginResponse.headers['set-cookie'];
          final cookiesMap = parseCookies(cookies);
          _sessionCookie = cookiesMap['B1SESSION']!;
          _routeIdCookie = cookiesMap['ROUTEID']!;
          resetSession();

          // Iniciar el temporizador de sesión al iniciar sesión

          if (context != null) {
            _startSessionTimer(context);
          }

          // Verificar el tipo de perfil y redirigir según corresponda
          switch (usuario['PERFIL']) {
            case 1: // Administrador
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => eleccion()),
              );
              break;
            case 2: // Usuario
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => eleccion()),
              );
              break;
            case 3: // Consulta
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => eleccion()),
              );
              break;
            default:
              // Perfil desconocido, manejar según sea necesario
              break;
          }
          notifyListeners();
        } else {
          throw Exception("Error en la respuesta de la API");
        }
      } catch (e) {
        print('Error: $e');
        ioClient.close();
        throw Exception('Error en la solicitud a la API');
      }
    }
  }

  void _startSessionTimer(BuildContext context) {
    _sessionStartTime = DateTime.now();
    _sessionTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      // Verificar si ha pasado el tiempo de sesión
      if (_sessionCookie != null &&
          _routeIdCookie != null &&
          _sessionStartTime != null) {
        if (DateTime.now().difference(_sessionStartTime!) >
            Duration(minutes: _sessionTimeoutMinutes)) {
          // Si ha pasado el tiempo, cerrar sesión automáticamente
          logout(context);
          // Llamar a la función para mostrar la alerta de sesión expirada
          showSessionExpiredAlert(context);
        }
      }
    });
  }

  void resetSession() {
    _sessionStartTime = DateTime.now();
  }

  void cancelSessionTimer() {
    _sessionTimer?.cancel();
  }

  void logout(BuildContext context) {
    // Limpia las variables y cancela el temporizador al cerrar sesión
    _authenticatedUser = null;
    _sessionCookie = '';
    _routeIdCookie = '';
    _authToken = '';
    cancelSessionTimer();
    resetSession();
    _logoutFromApi(context);
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
    notifyListeners();
  }

  Map<String, String> parseCookies(String? cookies) {
    final cookieMap = <String, String>{};
    if (cookies != null) {
      final cookieParts = cookies.split(';');
      for (final cookiePart in cookieParts) {
        if (cookiePart.contains("B1SESSION=")) {
          final keyValue = cookiePart.trim().split('=');
          if (keyValue.length == 2) {
            cookieMap[keyValue[0]] = keyValue[1];
          }
        } else if (cookiePart.contains("ROUTEID=")) {
          final routeIdParts = cookiePart.trim().split(',');
          for (final part in routeIdParts) {
            if (part.contains("ROUTEID=")) {
              final keyValue = part.trim().split('=');
              if (keyValue.length == 2) {
                cookieMap[keyValue[0]] = keyValue[1];
              }
            }
          }
        }
      }
    }
    return cookieMap;
  }

  Future<void> _logoutFromApi(BuildContext context) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final url = Uri.parse('https://10.2.0.6:50000/b1s/v1/Logout');

    try {
      final response = await ioClient.get(
        url,
        headers: {
          'Authorization':
              'Bearer $_authToken', // Incluye el token de autenticación
          'Cookie':
              'B1SESSION=$_sessionCookie; ROUTEID=$_routeIdCookie', // Agrega las cookies a la solicitud
        },
      );

      if (response.statusCode == 204) {
        _showLogoutSuccessAlertDialog(context);
      } else {
        _showLogoutErrorAlertDialog(context, response.statusCode);
      }
    } catch (error) {
      print('Error de red al cerrar sesión. Error: $error');
    } finally {
      ioClient.close();
    }
  }

  void _showLogoutSuccessAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sesión cerrada exitosamente'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutErrorAlertDialog(BuildContext context, statusCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error al cerrar sesión'),
          content: Text('Código de error: $statusCode'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cierra el diálogo
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showSessionExpiredAlert(BuildContext? context) {
    if (context != null) {
      Fluttertoast.showToast(
        msg: 'Tu sesión ha expirado',
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // Después de mostrar la alerta, puedes navegar de regreso a la pantalla de inicio de sesión.
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => LoginScreen()));
    }
  }

  void setUserProfileId(int id) {
    _userProfileId = id; // Método para establecer el valor del idPerfil
    notifyListeners(); // Notificar a los escuchadores del cambio
  }
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
