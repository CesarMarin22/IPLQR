import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/lector_qr.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'lector_manual.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:proyecto_qr/providers/serial_number.dart';

class eleccion extends StatefulWidget {
  const eleccion({Key? key}) : super(key: key);

  @override
  State<eleccion> createState() => _eleccion();
}

class _eleccion extends State<eleccion> {
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  @override
  Widget build(BuildContext context) {
    Provider.of<SerialNumberModel>(context, listen: false).setSerialNumber('');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 243, 138, 0),
          toolbarHeight: 80,
          title: Center(
            child: Image.asset(
              'assets/logo_ipl_negro.png',
              width: 70,
              height: 70,
            ),
          ),
        ),
//////////// cuerpo de la aplicacion/////////////////////////
        body: SingleChildScrollView(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Column(
            children: [
              const Text(
                '¿QUE DESEAS HACER?',
                style: TextStyle(
                  fontSize: 30,
                ),
              ),
              const SizedBox(
                height: 100,
              ),

////////////////////////////boton informacion////////////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const QRScannerPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 243, 138, 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                              const BorderSide(color: Colors.black, width: 5))),
                  child: const Text(
                    'LEER QR',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
/////////////////Termino de boton informacion////////////////////////////////////////////
              ///
              ////////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 65,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
//////////////////boton historia de servicios//////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const InputPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 243, 138, 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                              const BorderSide(color: Colors.black, width: 5))),
                  child: const Text(
                    'INGRESAR ARTICULO MANUALMENTE',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
///////////////////////fin boton historial de servicios/////////////////////////////
////////////////////////////Termino boton Reporte de instalacion/////////////////////////
              ////////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 80,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
/////////////////////boton REGRESAR //////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 90,
                child: ElevatedButton(
                  onPressed: () async {
                    // Realizar la solicitud POST al cerrar sesión
                    await logout();

                    // Navegar de vuelta a la pantalla de inicio de sesión
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black, width: 5)),
                  ),
                  child: const Text(
                    'CERRAR SESIÓN',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
///////////////////////fin boton historial de servicios/////////////////////////////
            ],
          ),
        ))),
/////////////////configuracion Fotter/////////////////////////////////////////////////////
        bottomNavigationBar: const BottomAppBar(
          color: Color.fromARGB(255, 29, 29, 27),
          shape: CircularNotchedRectangle(),
          child: SizedBox(
            height: 50,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Copyright ©2023, Todos los Derechos Reservados.',
                    style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12.0,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                  Text(
                    'Powered by IPL',
                    style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12.0,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                ],
              ),
            ),
          ),
        )
        ///////////////// fin de configuracion Fotter/////////////////////////////////////////////////////
        );
  }

  Future<void> logout() async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final url = Uri.parse('https://52.152.107.200:50000/b1s/v1/Logout');

    try {
      final response = await ioClient.get(
        url,
        headers: {
          'Authorization':
              'Bearer $authToken', // Incluye el token de autenticación
          'Cookie':
              'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie', // Agrega las cookies a la solicitud
        },
      );

      if (response.statusCode == 204) {
        // Éxito al cerrar sesión
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
      } else {
        // Error al cerrar sesión
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error al cerrar sesión'),
              content: Text('Código de error: ${response.statusCode}'),
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
    } catch (error) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error de red al cerrar sesión'),
            content: Text('Error: $error'),
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
  }
}
