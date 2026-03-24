import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' as io;
import 'dart:convert';
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:rive/rive.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';

class FileViewerFromAPI extends StatefulWidget {
  const FileViewerFromAPI({super.key});

  @override
  State<FileViewerFromAPI> createState() => _FileViewerFromAPIState();
}

class _FileViewerFromAPIState extends State<FileViewerFromAPI> {
  String authToken = '';
  String sessionCookie = '';
  String routeIdCookie = '';
  bool _isLoading = true;
  String? localFilePath;

  late final FileLoader _riveLoader = FileLoader.fromAsset(
    'assets/cargando_imagen.riv',
    riveFactory: Factory.rive,
  );

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final numSerie =
        Provider.of<SerialNumberModel>(context, listen: false).serialNumber;

    if (numSerie.isNotEmpty) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      sessionCookie = authProvider.sessionCookie;
      routeIdCookie = authProvider.routeIdCookie;
      authToken = authProvider.authToken;

      await fetchAttachmentEntry(numSerie);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchAttachmentEntry(String numSerie) async {
    final client = io.HttpClient();
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) {
      return true;
    };

    final ioClient = IOClient(client);

    final firstQueryUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/CustomerEquipmentCards?'
      '\$select=AttachmentEntry&'
      '\$filter=ManufacturerSerialNum eq \'$numSerie\'and StatusOfSerialNumber eq \'A\'',
    );

    try {
      final response = await ioClient.get(
        firstQueryUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['value'] == null || data['value'].isEmpty) {
          showNoDocumentDialog();
          return;
        }

        final attachmentEntry = data['value'][0]['AttachmentEntry'];

        if (attachmentEntry == null) {
          showNoDocumentDialog();
        } else {
          await fetchFileNameAndOpen(attachmentEntry);
        }
      } else {
        showErrorDialog(
          'Error en la consulta de AttachmentEntry: ${response.statusCode}',
        );
      }
    } catch (error) {
      showErrorDialog('Error al consultar AttachmentEntry: $error');
    } finally {
      if (mounted && localFilePath == null) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> fetchFileNameAndOpen(int attachmentEntry) async {
    final client = io.HttpClient();
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) {
      return true;
    };

    final ioClient = IOClient(client);

    final secondQueryUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/Attachments2?\$filter=AbsoluteEntry eq $attachmentEntry',
    );

    try {
      final response = await ioClient.get(
        secondQueryUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final attachmentLines = data['value'][0]['Attachments2_Lines'];

        if (attachmentLines != null && attachmentLines.isNotEmpty) {
          final fileName = attachmentLines[0]['FileName'];
          final fileExtension = attachmentLines[0]['FileExtension'];

          if (fileName != null && fileExtension != null) {
            final fileUrl = Uri.parse(
              'http://68.155.144.63:9090/attachments/$fileName.$fileExtension',
            );
            await downloadAndDisplayFile(fileUrl);
          } else {
            showNoDocumentDialog();
          }
        } else {
          showNoDocumentDialog();
        }
      } else {
        showErrorDialog(
          'Error al obtener FileName y FileExtension: ${response.statusCode}',
        );
      }
    } catch (error) {
      showErrorDialog('Error al obtener el nombre del archivo: $error');
    }
  }

  Future<void> downloadAndDisplayFile(Uri fileUrl) async {
    setState(() {
      _isLoading = true;
    });

    final client = io.HttpClient();
    client.badCertificateCallback =
        (io.X509Certificate cert, String host, int port) {
      return true;
    };

    final ioClient = IOClient(client);

    try {
      final response = await ioClient.get(fileUrl);

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/temp_document.pdf';

        final io.File file = io.File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;

        setState(() {
          localFilePath = filePath;
          _isLoading = false;
        });
      } else {
        showErrorDialog('Error al descargar el archivo');
      }
    } catch (error) {
      showErrorDialog('Hubo un problema al descargar el archivo: $error');
    }
  }

  void showNoDocumentDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin Documento'),
          content: const Text('No hay documento para mostrar.'),
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

  void showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
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

  Widget _buildLoadingAnimation() {
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: RiveWidgetBuilder(
          fileLoader: _riveLoader,
          builder: (context, state) {
            return switch (state) {
              RiveLoading() => const CircularProgressIndicator(),
              RiveFailed() => Text(
                  'Error al cargar animación: ${state.error}',
                ),
              RiveLoaded() => RiveWidget(
                  controller: state.controller,
                  fit: Fit.contain,
                ),
            };
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _riveLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
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
      ),
      body: _isLoading
          ? _buildLoadingAnimation()
          : localFilePath != null
              ? PDFView(
                  filePath: localFilePath!,
                )
              : const Center(
                  child: Text('Archivo descargado y abierto.'),
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
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
                Text(
                  'Powered by IPL',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
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
