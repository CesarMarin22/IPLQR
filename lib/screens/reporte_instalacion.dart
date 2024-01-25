import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:rive/rive.dart';
import 'dart:convert';
import 'package:http/io_client.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:flutter/cupertino.dart';

class FileViewerFromAPI extends StatefulWidget {
  const FileViewerFromAPI({super.key});

  @override
  _FileViewerFromAPIState createState() => _FileViewerFromAPIState();
}

class _FileViewerFromAPIState extends State<FileViewerFromAPI> {
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';
  bool _isLoading = true;
  int attachments2Lines = 0;
  String attachments2LinesString = '';

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

      await fetchAttachments2Lines(numSerie);
    }
  }

  Future<void> fetchAttachments2Lines(String numSerie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final firstQueryUrl = Uri.parse(
      'https://52.152.107.200:50000/b1s/v1/CustomerEquipmentCards?'
      '\$select=AttachmentEntry&'
      '\$filter=ManufacturerSerialNum eq \'$numSerie\'',
    );

    try {
      final response = await ioClient.get(
        firstQueryUrl,
        headers: {
          'Authorization':
              'Bearer $authToken', // Incluye el token de autenticación
          'Cookie':
              'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie', // Agrega las cookies a la solicitud
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['value'][0]['AttachmentEntry'] == null) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Sin Documento'),
                content: Text('No hay documento para mostrar.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {}
    } catch (error) {
      print('Error: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
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
      ),
      body: _isLoading
          ? const Center(
              child: RiveAnimation.asset(
                'assets/cargando_imagen.riv',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            )
          : const Center(
              child: Text('No hay documento para mostrar.'),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}
