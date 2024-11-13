import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'dart:convert';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'dart:io';
import 'package:http/io_client.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  late QRViewController controller;
  String numSerie = '';
  String authToken = '';
  String tipo = '';
  String sessionCookie = '';
  String routeIdCoockie = '';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCoockie = authProvider.routeIdCookie;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('QR Scanner'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: numSerie.isEmpty
                  ? const Text('Escaneando...')
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        String qrCodeContent = scanData.code?.replaceAll('\n', '') ?? '';
        if (qrCodeContent.isNotEmpty) {
          numSerie = qrCodeContent;
          Provider.of<SerialNumberModel>(context, listen: false)
              .setSerialNumber(numSerie);
          _fetchDataFromAPI(numSerie);
        }
      });
    });
  }

  Future<void> _fetchDataFromAPI(String numSerie) async {
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
      '\$filter=Items/ItemsGroupCode eq ItemGroups/Number and Items/ForeignName eq   \'$numSerie\'',
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

  void navigateTomenuEquipos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuEquipos()),
    );
  }

  void navigateTomenuBaterias() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuBaterias()),
    );
  }

  void navigateTomenuCargadores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuCargadores()),
    );
  }

  void mostrarErrorArticulo() {
    setState(() {
      numSerie = '';
    });
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: const Text('Articulo no valido'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
