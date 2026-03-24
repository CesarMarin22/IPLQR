import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'dart:io';
import 'package:http/io_client.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController controller = MobileScannerController();

  String numSerie = '';
  String authToken = '';
  String tipo = '';
  String sessionCookie = '';
  String routeIdCoockie = '';

  bool _isProcessing = false;
  bool _hasNavigated = false;
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCoockie = authProvider.routeIdCookie;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          await controller.stop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await controller.stop();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('QR Scanner'),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: (BarcodeCapture capture) {
                      if (_isProcessing || _hasNavigated || _dialogOpen) return;

                      for (final barcode in capture.barcodes) {
                        final String qrCodeContent = (barcode.rawValue ?? '')
                            .replaceAll('\n', '')
                            .trim();

                        if (qrCodeContent.isNotEmpty) {
                          _handleScannedCode(qrCodeContent);
                          break;
                        }
                      }
                    },
                  ),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
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
                    : Text('Serie: $numSerie'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleScannedCode(String qrCodeContent) async {
    if (_isProcessing || _hasNavigated || _dialogOpen) return;

    setState(() {
      _isProcessing = true;
      numSerie = qrCodeContent;
    });

    Provider.of<SerialNumberModel>(context, listen: false)
        .setSerialNumber(numSerie);

    await controller.stop();
    await _fetchDataFromAPI(numSerie);
  }

  Future<void> _fetchDataFromAPI(String numSerie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    final ioClient = IOClient(client);

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(Items,ItemGroups)?'
      '\$expand=Items(\$select=AssetGroup),'
      'ItemGroups(\$select=GroupName)&'
      '\$filter=Items/ItemsGroupCode eq ItemGroups/Number and Items/ForeignName eq \'$numSerie\'',
    );

    try {
      final response = await ioClient.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCoockie',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        for (var item in decodedResponse['value']) {
          if (item['ItemGroups'] != null) {
            final items = item['ItemGroups'];
            tipo = items['GroupName'] ?? '';
            final assetGroup = item['Items']['AssetGroup'] ?? '';

            _hasNavigated = true;

            if (tipo == 'MONTACARGAS' || assetGroup == 'MO') {
              navigateTomenuEquipos();
              return;
            } else if (tipo == 'BATERIAS' || assetGroup == 'BAT') {
              navigateTomenuBaterias();
              return;
            } else if (tipo == 'CARGADORES' || assetGroup == 'CAR') {
              navigateTomenuCargadores();
              return;
            }
          }
        }

        mostrarErrorArticulo();
      } else {
        mostrarErrorArticulo();
      }
    } catch (e) {
      if (!mounted) return;
      mostrarErrorArticulo();
    } finally {
      ioClient.close();

      if (mounted && !_hasNavigated && !_dialogOpen) {
        setState(() {
          _isProcessing = false;
        });
        await controller.start();
      }
    }
  }

  void navigateTomenuEquipos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuEquipos()),
    ).then((_) => _resetScanner());
  }

  void navigateTomenuBaterias() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuBaterias()),
    ).then((_) => _resetScanner());
  }

  void navigateTomenuCargadores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuCargadores()),
    ).then((_) => _resetScanner());
  }

  Future<void> _resetScanner() async {
    if (!mounted) return;

    setState(() {
      _hasNavigated = false;
      _isProcessing = false;
      _dialogOpen = false;
      numSerie = '';
    });

    await controller.start();
  }

  void mostrarErrorArticulo() {
    if (_dialogOpen) return;

    _dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: const Text('Artículo no válido'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                if (!mounted) return;

                setState(() {
                  _dialogOpen = false;
                  _isProcessing = false;
                });

                await controller.start();
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
