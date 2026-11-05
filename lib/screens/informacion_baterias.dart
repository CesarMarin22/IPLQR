import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class InformacionBaterias extends StatefulWidget {
  const InformacionBaterias({super.key});

  @override
  State<InformacionBaterias> createState() => _InformacionBateriasState();
}

class _InformacionBateriasState extends State<InformacionBaterias> {
  static const _sinInfo = 'No Contiene Información';
  static const _timeout = Duration(seconds: 25);

  late final IOClient _ioClient = IOClient(
    HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true,
  );

  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  bool _loading = true;
  String? _error;
  Map<String, String>? _info;
  String _numSerie = '';

  @override
  void initState() {
    super.initState();
    _numSerie = context.read<SerialNumberModel>().serialNumber;
    if (_numSerie.isEmpty) {
      _loading = false;
      _error = 'No hay un número de serie seleccionado.';
    } else {
      _readAuth();
      fetchDataFromAPI(_numSerie);
    }
  }

  @override
  void dispose() {
    _ioClient.close();
    super.dispose();
  }

  void _readAuth() {
    final authProvider = context.read<AuthProvider>();
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;
  }

  /// Recarga los datos (botón Reintentar / deslizar hacia abajo).
  Future<void> fetchData({bool showLoader = true}) async {
    if (_numSerie.isEmpty) return;
    _readAuth();
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await fetchDataFromAPI(_numSerie);
  }

  String _text(dynamic value) {
    if (value == null) return _sinInfo;
    final s = value.toString();
    return s.isEmpty ? _sinInfo : s;
  }

  void _goToLogin() {
    if (!mounted) return;
    appMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content:
            Text('Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.'),
        backgroundColor: AppColors.danger,
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  Future<void> fetchDataFromAPI(String numSerie) async {
    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/Items?'
      '\$select=U_MarcaB,U_ModeloBat,ForeignName,U_VoltajeB,U_CapacidadB,U_TipoB,User_Text&'
      '\$filter=(ItemsGroupCode eq 430 or AssetGroup eq \'BAT\') and ForeignName eq \'$numSerie\'',
    );

    String? error;
    Map<String, String>? info;

    try {
      final response = await _ioClient.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      ).timeout(_timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        if (values is List) {
          // Igual que antes: si hay varios registros, se queda el último.
          for (final item in values) {
            if (item is Map) {
              info = {
                'serie': _text(item['ForeignName']),
                'modelo': _text(item['U_ModeloBat']),
                'voltaje': _text(item['U_VoltajeB']),
                'capacidad': _text(item['U_CapacidadB']),
                'tipo': _text(item['U_TipoB']),
                'comentarios': formatComentarios(_text(item['User_Text'])),
                'marca': _text(item['U_MarcaB']),
              };
            }
          }
        }
        if (info == null) {
          error = 'No se encontró información para la serie $numSerie.';
        }
      } else if (response.statusCode == 401) {
        dynamic err;
        try {
          final decoded = json.decode(response.body);
          err = decoded is Map ? decoded['error'] : null;
        } catch (_) {}
        if (err is Map && err['code'] == 301) {
          _goToLogin();
          return;
        }
        final msg = err is Map && err['message'] is Map
            ? err['message']['value']
            : null;
        error = 'Error en la solicitud.\n'
            'Código de error: ${err is Map ? err['code'] : 401}'
            '${msg != null ? '\nMensaje: $msg' : ''}';
      } else {
        error =
            'Error en la solicitud.\nCódigo de error: ${response.statusCode}';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } on SocketException {
      error = 'No se pudo conectar con el servidor. Revisa tu conexión.';
    } catch (e) {
      error = 'Ocurrió un error inesperado: $e';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      _info = info;
    });
  }

  String formatComentarios(String userText) {
    List<String> lines = userText.split('\r\r');
    List<String> formattedLines = [];

    for (String line in lines) {
      if (line.trim().isNotEmpty) {
        // Dividir cada línea en columnas usando tabuladores
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final info = _info;
    if (_error != null || info == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyState(
            message: _error ?? 'Sin información.',
            icon: Icons.error_outline,
            onRetry: _numSerie.isEmpty ? null : fetchData,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Text(
          'Información de batería',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Serie: $_numSerie',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                InfoRow(label: 'Marca', value: info['marca']!),
                InfoRow(label: 'Modelo', value: info['modelo']!),
                InfoRow(label: 'Serie', value: info['serie']!),
                InfoRow(label: 'Voltaje', value: info['voltaje']!),
                InfoRow(label: 'Capacidad', value: info['capacidad']!),
                InfoRow(label: 'Tipo', value: info['tipo']!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notes, size: 20, color: AppColors.orangeDark),
                    SizedBox(width: 8),
                    Text(
                      'Comentarios',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  info['comentarios']!.isEmpty
                      ? _sinInfo
                      : info['comentarios']!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Regresar'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Image.asset('assets/logo ipl_BLANCO.png', height: 58),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => fetchData(showLoader: false),
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}
