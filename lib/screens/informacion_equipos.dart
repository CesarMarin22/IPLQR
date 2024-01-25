import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'dart:convert';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:fluttertoast/fluttertoast.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _serieController = TextEditingController();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _tipoController = TextEditingController();
  final TextEditingController _voltajeController = TextEditingController();
  final TextEditingController _capacidadController = TextEditingController();
  final TextEditingController _alturaEstibaController = TextEditingController();
  //TextEditingController _aditamentoController = TextEditingController();
  // TextEditingController _fechaImportacionController = TextEditingController();
  final TextEditingController _comentariosController = TextEditingController();
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final numSerie =
        Provider.of<SerialNumberModel>(context, listen: false).serialNumber;
    if (numSerie != "" && numSerie.isNotEmpty) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      sessionCookie = authProvider.sessionCookie;
      routeIdCookie = authProvider.routeIdCookie;
      authToken = authProvider.authToken;

      print('authToken: $authToken');
      print('sessionCookie: $sessionCookie');
      print('routeIdCookie: $routeIdCookie');

      await fetchDataFromAPI(numSerie);
    }
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
        body: SingleChildScrollView(
          // Agregamos SingleChildScrollView aquí
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Column(
                children: [
                  const Text(
                    'INFORMACIÓN DE EQUIPO',
                    style: TextStyle(fontSize: 30),
                  ),
                  const SizedBox(
                    height: 70,
                  ),
                  TextField(
                    controller: _serieController,
                    decoration: InputDecoration(
                      labelText: 'Serie',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _marcaController,
                    decoration: InputDecoration(
                      labelText: 'Marca',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _modeloController,
                    decoration: InputDecoration(
                      labelText: 'Modelo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _tipoController,
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _voltajeController,
                    decoration: InputDecoration(
                      labelText: 'Voltaje',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _capacidadController,
                    decoration: InputDecoration(
                      labelText: 'Capacidad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _alturaEstibaController,
                    decoration: InputDecoration(
                      labelText: 'Altura de Estiba',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 18.0), // Espaciado entre TextField
                  // TextField(
                  //   controller: _aditamentoController,
                  //   decoration: InputDecoration(
                  //     labelText: 'Aditamento',
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(10.0),
                  //     ),
                  //   ),
                  //   readOnly: true,
                  // ),
                  // SizedBox(height: 18.0), // Espaciado entre TextField
                  // TextField(
                  //   controller: _fechaImportacionController,
                  //   decoration: InputDecoration(
                  //     labelText: 'Fecha de Importación',
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(10.0),
                  //     ),
                  //   ),
                  //   readOnly: true,
                  // ),
                  // SizedBox(height: 18.0), // Espaciado entre TextField
                  TextField(
                    controller: _comentariosController,
                    maxLines: null,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Comentarios',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Comentarios'),
                            content: SingleChildScrollView(
                              child: Text(_comentariosController.text),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Cerrar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18.0),
                  SizedBox(
                    width: 200,
                    height: 90,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const menuEquipos()));
                      },
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                  color: Colors.black, width: 5))),
                      child: const Text(
                        'REGRESAR',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // Espaciado entre TextField
                ],
              ),
            ),
          ),
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

  Future<void> fetchDataFromAPI(String numSerie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final apiUrl = Uri.parse(
      'https://52.152.107.200:50000/b1s/v1/\$crossjoin(Items,Manufacturers)?'
      '\$expand=Items(\$select=ForeignName,U_Modelo,U_Voltaje,U_Capacidad,U_AlturaMaxEstiba,U_Tipo,User_Text,Valid),'
      'Manufacturers(\$select=ManufacturerName)&'
      '\$filter=Items/Manufacturer eq Manufacturers/Code and Items/ForeignName eq \'$numSerie\' and Items/ItemsGroupCode eq 435',
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
        final decodedResponse = json.decode(response.body);
        for (var item in decodedResponse['value']) {
          final items = item['Items'];
          if (item['Items'] != null && items['Valid'] == 'Y') {
            _serieController.text =
                items['ForeignName'] ?? 'No Contiene Información';
            _modeloController.text =
                items['U_Modelo'] ?? 'No Contiene Información';
            _voltajeController.text =
                items['U_Voltaje'] ?? 'No Contiene Información';
            _capacidadController.text =
                items['U_Capacidad'] ?? 'No Contiene Información';
            _alturaEstibaController.text =
                items['U_AlturaMaxEstiba'] ?? 'No Contiene Información';
            _tipoController.text = items['U_Tipo'] ?? 'No Contiene Información';
            _comentariosController.text = formatComentarios(
                items['User_Text'] ?? 'No Contiene Información');
          }
          if (item['Manufacturers'] != null) {
            final manufacturers = item['Manufacturers'];
            _marcaController.text =
                manufacturers['ManufacturerName'] ?? 'No Contiene Información';
          }
        }
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
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error en la solicitud'),
                content: Text(
                    'Código de error: ${error['code']}\nMensaje: ${error['message']['value']}'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {
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
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
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
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  String formatComentarios(String userText) {
    List<String> lines = userText.split('\r\r');
    List<String> formattedLines = [];

    for (String line in lines) {
      if (line.trim().isNotEmpty) {
        // Dividir cada línea en columnas usando espacios
        List<String> columns = line.split('\t');

        // Agregar sangría a las líneas opcionales
        if (columns.length > 1) {
          columns[1] = '  ${columns[1]}';
        }

        // Unir las columnas nuevamente
        String formattedLine = columns.join('\t');
        formattedLines.add(formattedLine.trim());
      }
    }

    // Unir todas las líneas formateadas con saltos de línea
    return formattedLines.join('\n');
  }
}
