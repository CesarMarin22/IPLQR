import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_equipos.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DetallesLlamadaServicioEquipos extends StatefulWidget {
  final String ot;

  DetallesLlamadaServicioEquipos({required this.ot});

  @override
  _DetallesLlamadaServicioEquiposState createState() =>
      _DetallesLlamadaServicioEquiposState();
}

class _DetallesLlamadaServicioEquiposState
    extends State<DetallesLlamadaServicioEquipos> {
  Map<String, dynamic>? detallesOT;
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = ''; // Almacena los detalles de la OT

  @override
  void initState() {
    super.initState();
    // Realizar una consulta a la API para obtener los detalles de la OT
    _fetchOTDetails(widget.ot);
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _fetchOTDetails(String ot) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);
    print(ot);
    final apiUrl = Uri.parse(
      'https://52.152.107.200:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes,EmployeesInfo)?'
      '\$expand=ServiceCalls(\$select=Subject,U_PersonWhoReports,Resolution,U_Horometro),'
      'ServiceCallTypes(\$select=Name),'
      'EmployeesInfo(\$select=FirstName,LastName)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and EmployeesInfo/EmployeeID eq ServiceCalls/TechnicianCode and ServiceCalls/ServiceCallID eq $ot',
    );

    try {
      final response = await ioClient.get(
        apiUrl,
        headers: {
          'Authorization':
              'Bearer $authToken', // Incluye el token de autenticación
          'Cookie':
              'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie', // Agrega las cookies a la solicitud
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = json.decode(response.body);
        if (decodedResponse['value'] != null &&
            decodedResponse['value'].isNotEmpty) {
          setState(() {
            detallesOT = decodedResponse['value'][0];
          });
        } else if (response.statusCode == 401) {
          final decodedResponse = json.decode(response.body);
          final error = decodedResponse['error'];
          if (error['code'] == 301) {
            // Mostrar el FlutterToast indicando que la sesión ha expirado
            showToast(
                'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.');
            // Redirigir al inicio de sesión
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      LoginScreen()), // Reemplaza 'LoginPage' con la clase de tu pantalla de inicio de sesión
            );
          } else {
            // Mostrar el AlertDialog con el mensaje de sesión expirada
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Sesión expirada'),
                  content: Text(
                      'La sesión ha expirado. Por favor, inicia sesión nuevamente.'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Puedes navegar a la pantalla de inicio de sesión o realizar alguna otra acción
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()));
                      },
                      child: Text('OK'),
                    ),
                  ],
                );
              },
            );
          }
        } else if (response.statusCode == 404) {
          // Llamada de servicio no contiene detalles
          _mostrarDialogoSinDetalles();
        } else {
          // Mostrar el AlertDialog con el mensaje de error
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error en la solicitud'),
                content: Text('Código de error: ${response.statusCode}'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LlamadaServiciosEquipos(),
                        ),
                      );
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      // Mostrar el AlertDialog con el mensaje de error
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Ocurrió un error inesperado: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LlamadaServiciosEquipos(),
                    ),
                  );
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildDetailCard(String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 5),
            TextField(
              controller: TextEditingController(text: value),
              readOnly: true,
              maxLines: label == 'TRABAJO REALIZADO' ? 2 : 1,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
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
        body: detallesOT != null
            ? SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'DETALLE DE OT',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                      ),
                      Text(
                        'Número de OT: ${widget.ot}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildDetailCard('FALLA',
                          detallesOT?['ServiceCalls']['Subject'] ?? ''),
                      _buildDetailCard(
                          'HORÓMETRO',
                          detallesOT!['ServiceCalls']['U_Horometro']
                              .toString()),
                      _buildDetailCard('PERSONA QUE REPORTA',
                          detallesOT!['ServiceCalls']['U_PersonWhoReports']),
                      _buildDetailCard('TÉCNICO',
                          '${detallesOT!['EmployeesInfo']['FirstName']} ${detallesOT!['EmployeesInfo']['LastName']}'),
                      _buildDetailCard('TIPO DE SERVICIO',
                          detallesOT!['ServiceCallTypes']['Name']),
                      _buildDetailCard('TRABAJO REALIZADO',
                          detallesOT!['ServiceCalls']['Resolution']),
                      SizedBox(
                        height: 20,
                      ),
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 90,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const LlamadaServiciosEquipos(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              backgroundColor:
                                  const Color.fromARGB(255, 250, 2, 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                    color: Colors.black, width: 5),
                              ),
                            ),
                            child: const Text(
                              'REGRESAR',
                              style:
                                  TextStyle(fontSize: 20, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: CircularProgressIndicator(),
              ),
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
        ));
  }

  void _mostrarDialogoSinDetalles() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Llamada de servicio sin detalles"),
          content: Text("La llamada de servicio no contiene detalles."),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .pop(); // Esto cerrará el cuadro de diálogo y la pantalla actual
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
}
