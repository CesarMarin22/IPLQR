import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'dart:convert';
import 'package:proyecto_qr/providers/auth_provider.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  _InputPageState createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController articleController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  String errorTextArticle = '';
  bool botonHabilitado = false;
  String authToken = '';
  String tipo = '';
  String sessionCookie = '';
  String routeIdCoockie = '';

  @override
  void dispose() {
    articleController.dispose();
    serialNumberController.dispose();
    super.dispose();
  }

  void navigateTomenuEquipos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuEquipos()),
    ).then((_) {
      articleController.clear();
      serialNumberController.clear();
      setState(() {
        errorTextArticle = '';
        botonHabilitado = false;
      });
    });
  }

  void navigateTomenuBaterias() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuBaterias()),
    ).then((_) {
      articleController.clear();
      serialNumberController.clear();
      setState(() {
        errorTextArticle = '';
        botonHabilitado = false;
      });
    });
  }

  void navigateTomenuCargadores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuCargadores()),
    ).then((_) {
      articleController.clear();
      serialNumberController.clear();
      setState(() {
        errorTextArticle = '';
        botonHabilitado = false;
      });
    });
  }

  void mostrarErrorArticulo() {
    setState(() {
      errorTextArticle = 'Articulo no valido';
      botonHabilitado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCoockie = authProvider.routeIdCookie;
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 243, 138, 0),
          toolbarHeight: 80,
          title: Center(
            child: Image.asset(
              'assets/logo ipl_BLANCO.png',
              width: 70,
              height: 70,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(
              children: [
                TextField(
                  controller: serialNumberController,
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty &&
                          serialNumberController.text.isNotEmpty) {
                        botonHabilitado = true;
                      } else {
                        botonHabilitado = false;
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Número de Serie',
                  ),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: botonHabilitado
                      ? () {
                          String serie = serialNumberController.text;
                          errorTextArticle = '';
                          if (serie.isNotEmpty) {
                            Provider.of<SerialNumberModel>(context,
                                    listen: false)
                                .setSerialNumber(serie);
                            _fetchDataFromAPI(serie);
                          }
                        }
                      : null,
                  child: const Text('Verificar'),
                ),
                const SizedBox(
                  height: 80,
                ),
                SizedBox(
                  width: 200,
                  height: 90,
                  child: ElevatedButton(
                    onPressed: () {
                      // Resetear el número de serie al hacer clic en "SCANEAR"
                      Provider.of<SerialNumberModel>(context, listen: false)
                          .setSerialNumber('');

                      // Navegar a la pantalla de escaneo (eleccion)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const eleccion(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.black, width: 5),
                      ),
                    ),
                    child: const Text(
                      'SCANEAR',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
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

  Future<void> _fetchDataFromAPI(String serie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final apiUrl = Uri.parse(
      'https://10.2.0.6:50000/b1s/v1/\$crossjoin(Items,ItemGroups)?'
      '\$expand=Items(\$select=AssetGroup),'
      'ItemGroups(\$select=GroupName)&'
      '\$filter=Items/ItemsGroupCode eq ItemGroups/Number and Items/ForeignName eq  \'$serie\'',
    );
    try {
      final response = await ioClient.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCoockie',
        },
      );

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        for (var item in decodedResponse['value']) {
          if (item['ItemGroups'] != null) {
            final items = item['ItemGroups'];
            tipo = items['GroupName'] ?? '';
            final assetGroup = item['Items']['AssetGroup'] ?? '';

            // Validar por GroupName y AssetGroup
            if (tipo == 'MONTACARGAS' || assetGroup == 'MO') {
              navigateTomenuEquipos();
            } else if (tipo == 'BATERIAS' || assetGroup == 'BAT') {
              navigateTomenuBaterias();
            } else if (tipo == 'CARGADORES' || assetGroup == 'CAR') {
              navigateTomenuCargadores();
            } else {
              mostrarErrorArticulo();
            }
          }
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
