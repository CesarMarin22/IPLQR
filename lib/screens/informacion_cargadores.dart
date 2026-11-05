import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class InformacionCargadores extends StatefulWidget {
  const InformacionCargadores({super.key});

  @override
  State<InformacionCargadores> createState() => _InformacionCargadoresState();
}

class _InformacionCargadoresState extends State<InformacionCargadores> {
  static const _timeout = Duration(seconds: 25);
  static const _sinInfo = 'No Contiene Información';

  String _marca = '';
  String _modelo = '';
  String _serie = '';
  String _voltaje = '';
  String _amperaje = '';
  String _comentarios = '';

  bool _loading = true;
  bool _found = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchData() => _load(showLoader: true);

  Future<void> _load({bool showLoader = false}) async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;
    if (numSerie.isEmpty) {
      setState(() {
        _loading = false;
        _found = false;
        _error = null;
      });
      return;
    }
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await fetchDataFromAPI(numSerie);
  }

  void _goToLogin(String message) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    appMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _text(dynamic value) {
    if (value == null) return _sinInfo;
    final s = value.toString();
    return s.isEmpty ? _sinInfo : s;
  }

  Future<void> fetchDataFromAPI(String numSerie) async {
    context.read<AuthProvider>().resetSession();

    String? error;
    bool found = false;

    try {
      final response = await Api.get('/app-montacargas/cargador', {'serie': numSerie}).timeout(_timeout);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        if (values is List) {
          for (final item in values) {
            if (item is Map) {
              found = true;
              _serie = _text(item['ForeignName']);
              _modelo = _text(item['U_ModeloCargador']);
              _voltaje = _text(item['U_SalidaVoltaje']);
              _amperaje = _text(item['U_Amperaje']);
              _comentarios = item['User_Text'] == null
                  ? _sinInfo
                  : formatComentarios(item['User_Text'].toString());
              _marca = _text(item['U_MarcaC']);
            }
          }
        }
      } else if (response.statusCode == 401) {
        Map? err;
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['error'] is Map) err = decoded['error'];
        } catch (_) {}
        if (err?['code'] == 301) {
          _goToLogin(
              'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.');
          return;
        }
        final msg = err?['message'] is Map ? err!['message']['value'] : null;
        error = 'Error en la solicitud.\nCódigo de error: '
            '${err?['code'] ?? 401}${msg != null ? '\nMensaje: $msg' : ''}';
      } else {
        error =
            'Error en la solicitud.\nCódigo de error: ${response.statusCode}';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } catch (e) {
      error = 'No se pudo obtener la información. Revisa tu conexión.';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _found = found;
      _error = error;
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
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        onRetry: fetchData,
      );
    }
    if (!_found) {
      return EmptyState(
        icon: Icons.search_off,
        message: 'No se encontró información del cargador.',
        onRetry: fetchData,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          const Text(
            'Información del cargador',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  InfoRow(label: 'Marca', value: _marca),
                  const Divider(height: 1),
                  InfoRow(label: 'Modelo', value: _modelo),
                  const Divider(height: 1),
                  InfoRow(label: 'Serie', value: _serie),
                  const Divider(height: 1),
                  InfoRow(label: 'Voltaje', value: _voltaje),
                  const Divider(height: 1),
                  InfoRow(label: 'Amperaje', value: _amperaje),
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
                  const Text(
                    'Comentarios',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _comentarios.isEmpty ? '—' : _comentarios,
                    style: const TextStyle(fontSize: 15, color: AppColors.dark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Regresar'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}
