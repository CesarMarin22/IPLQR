import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';
import 'package:rive/rive.dart';

const _timeout = Duration(seconds: 25);

class FileViewerFromAPI extends StatefulWidget {
  const FileViewerFromAPI({super.key});

  @override
  State<FileViewerFromAPI> createState() => _FileViewerFromAPIState();
}

class _FileViewerFromAPIState extends State<FileViewerFromAPI> {
  bool _isLoading = true;
  String? localFilePath;

  /// Mensaje para estado vacío / error (null mientras carga o si hay PDF).
  String? _message;
  bool _isError = false;

  late final FileLoader _riveLoader = FileLoader.fromAsset(
    'assets/cargando_imagen.riv',
    riveFactory: Factory.rive,
  );

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
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
      context.read<AuthProvider>().resetSession();
      await downloadAndDisplayFile(numSerie);
    } else {
      showNoDocumentDialog();
    }
  }

  /// El servidor busca en SAP el adjunto de la tarjeta del equipo y regresa el PDF.
  Future<void> downloadAndDisplayFile(String numSerie) async {
    try {
      final response = await Api.get(
        '/app-montacargas/reporte-instalacion',
        {'serie': numSerie},
      ).timeout(_timeout);
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
      } else if (response.statusCode == 404) {
        showNoDocumentDialog();
      } else {
        showErrorDialog(Api.mensaje(response) ??
            'No se pudo consultar el reporte (código ${response.statusCode}).');
      }
    } on TimeoutException {
      showErrorDialog(_timeoutMsg);
    } catch (error) {
      debugPrint('Error descarga: $error');
      showErrorDialog(_networkMsg);
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
