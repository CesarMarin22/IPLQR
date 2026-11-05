import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/theme/app_theme.dart';
import 'package:rive/rive.dart';

const _timeout = Duration(seconds: 25);

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

  /// Mensaje para estado vacío / error (null mientras carga o si hay PDF).
  String? _message;
  bool _isError = false;

  late final FileLoader _riveLoader = FileLoader.fromAsset(
    'assets/cargando_imagen.riv',
    riveFactory: Factory.rive,
  );

  /// Un solo cliente para las tres peticiones; se cierra en dispose.
  IOClient? _client;
  IOClient get _http => _client ??= IOClient(
        io.HttpClient()
          ..connectionTimeout = _timeout
          ..badCertificateCallback =
              (io.X509Certificate cert, String host, int port) => true,
      );

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    _client?.close();
    _riveLoader.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _message = null;
        _isError = false;
        localFilePath = null;
      });
    }

    if (numSerie.isNotEmpty) {
      final authProvider = context.read<AuthProvider>();
      sessionCookie = authProvider.sessionCookie;
      routeIdCookie = authProvider.routeIdCookie;
      authToken = authProvider.authToken;

      await fetchAttachmentEntry(numSerie);
    } else {
      showNoDocumentDialog();
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $authToken',
        'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
      };

  Future<void> fetchAttachmentEntry(String numSerie) async {
    final firstQueryUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/CustomerEquipmentCards?'
      '\$select=AttachmentEntry&'
      '\$filter=ManufacturerSerialNum eq \'$numSerie\'and StatusOfSerialNumber eq \'A\'',
    );

    try {
      final response =
          await _http.get(firstQueryUrl, headers: _headers).timeout(_timeout);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final values = data is Map ? data['value'] : null;

        if (values is! List || values.isEmpty || values.first is! Map) {
          showNoDocumentDialog();
          return;
        }

        final attachmentEntry = (values.first as Map)['AttachmentEntry'];

        if (attachmentEntry is num) {
          await fetchFileNameAndOpen(attachmentEntry.toInt());
        } else {
          showNoDocumentDialog();
        }
      } else {
        showErrorDialog(
          'No se pudo consultar el reporte (código ${response.statusCode}).',
        );
      }
    } on TimeoutException {
      showErrorDialog(_timeoutMsg);
    } catch (error) {
      debugPrint('Error AttachmentEntry: $error');
      showErrorDialog(_networkMsg);
    }
  }

  Future<void> fetchFileNameAndOpen(int attachmentEntry) async {
    final secondQueryUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/Attachments2?\$filter=AbsoluteEntry eq $attachmentEntry',
    );

    try {
      final response =
          await _http.get(secondQueryUrl, headers: _headers).timeout(_timeout);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final values = data is Map ? data['value'] : null;
        final first = values is List && values.isNotEmpty && values.first is Map
            ? values.first as Map
            : null;
        final attachmentLines = first?['Attachments2_Lines'];

        if (attachmentLines is List &&
            attachmentLines.isNotEmpty &&
            attachmentLines.first is Map) {
          final line = attachmentLines.first as Map;
          final fileName = line['FileName'];
          final fileExtension = line['FileExtension'];

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
          'No se pudo obtener el archivo (código ${response.statusCode}).',
        );
      }
    } on TimeoutException {
      showErrorDialog(_timeoutMsg);
    } catch (error) {
      debugPrint('Error Attachments2: $error');
      showErrorDialog(_networkMsg);
    }
  }

  Future<void> downloadAndDisplayFile(Uri fileUrl) async {
    try {
      final response = await _http.get(fileUrl).timeout(_timeout);
      if (!mounted) return;

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
        showErrorDialog('Error al descargar el archivo.');
      }
    } on TimeoutException {
      showErrorDialog(_timeoutMsg);
    } catch (error) {
      debugPrint('Error descarga: $error');
      showErrorDialog('Hubo un problema al descargar el archivo.');
    }
  }

  static const _timeoutMsg = 'El servidor tardó demasiado en responder.\n'
      'Revisa tu conexión e inténtalo de nuevo.';
  static const _networkMsg = 'No se pudo conectar con el servidor.\n'
      'Revisa tu conexión e inténtalo de nuevo.';

  /// Antes mostraba un diálogo y dejaba el texto "Archivo descargado y
  /// abierto." de fondo; ahora muestra un estado vacío en la pantalla.
  void showNoDocumentDialog() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isError = false;
      _message = 'No hay reporte de instalación para este equipo.';
    });
  }

  void showErrorDialog(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isError = true;
      _message = message;
      localFilePath = null;
    });
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
              RiveLoading() => const Center(child: CircularProgressIndicator()),
              RiveFailed() => const Center(child: CircularProgressIndicator()),
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

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingAnimation();
    final path = localFilePath;
    if (path != null) {
      return PDFView(
        filePath: path,
        onError: (error) {
          debugPrint('Error PDFView: $error');
          showErrorDialog('No se pudo abrir el documento.');
        },
      );
    }
    return SingleChildScrollView(
      child: EmptyState(
        message: _message ?? 'No hay documento para mostrar.',
        icon: _isError ? Icons.cloud_off_outlined : Icons.description_outlined,
        onRetry: fetchData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de instalación')),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: const AppFooter(),
    );
  }
}
