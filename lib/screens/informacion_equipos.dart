import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

const _sinInfo = 'No Contiene Información';
const _timeout = Duration(seconds: 25);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _serie = '';
  String _marca = '';
  String _modelo = '';
  String _tipo = '';
  String _voltaje = '';
  String _capacidad = '';
  String _alturaEstiba = '';
  String _comentarios = '';

  bool _loading = true;
  bool _found = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> fetchData() async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;
    if (numSerie.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No hay número de serie seleccionado.';
      });
      return;
    }
    if (!_loading || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    await fetchDataFromAPI(numSerie);
  }

  static String _txt(dynamic v) {
    if (v == null) return _sinInfo;
    final s = v.toString();
    return s.isEmpty ? _sinInfo : s;
  }

  Future<void> fetchDataFromAPI(String numSerie) async {
    context.read<AuthProvider>().resetSession();

    String? error;
    try {
      final response = await Api.get('/app-montacargas/equipo', {'serie': numSerie}).timeout(_timeout);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        var found = false;
        if (values is List) {
          for (final item in values) {
            if (item is! Map) continue;
            final items = item['Items'];
            if (items is Map && items['Valid'] == 'Y') {
              found = true;
              _serie = _txt(items['ForeignName']);
              _modelo = _txt(items['U_Modelo']);
              _voltaje = _txt(items['U_Voltaje']);
              _capacidad = _txt(items['U_Capacidad']);
              _alturaEstiba = _txt(items['U_AlturaMaxEstiba']);
              _tipo = _txt(items['U_Tipo']);
              _comentarios = formatComentarios(_txt(items['User_Text']));
            }
            final manufacturers = item['Manufacturers'];
            if (manufacturers is Map) {
              found = true;
              _marca = _txt(manufacturers['ManufacturerName']);
            }
          }
        }
        _found = found;
      } else if (response.statusCode == 401) {
        final err = _parseError(response.body);
        if (err.$1 == 301) {
          _sessionExpired();
          return;
        }
        error = 'Error en la solicitud (código ${err.$1 ?? 401}).'
            '${err.$2 != null ? '\n${err.$2}' : ''}';
      } else {
        error = 'Error en la solicitud (código ${response.statusCode}).';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    } catch (e) {
      debugPrint('Error informacion_equipos: $e');
      error = 'No se pudo conectar con el servidor.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  /// Devuelve (código, mensaje) del error de SAP sin lanzar excepciones.
  (int?, String?) _parseError(String body) {
    try {
      final decoded = json.decode(body);
      final error = decoded is Map ? decoded['error'] : null;
      if (error is! Map) return (null, null);
      final code = error['code'];
      final message = error['message'];
      return (
        code is int ? code : int.tryParse('$code'),
        message is Map ? message['value']?.toString() : message?.toString(),
      );
    } catch (_) {
      return (null, null);
    }
  }

  void _sessionExpired() {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    unawaited(auth.logout());
    messenger.showSnackBar(
      const SnackBar(
        content:
            Text('Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.'),
        backgroundColor: AppColors.danger,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Información del equipo')),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget content;
    if (_error != null) {
      content = EmptyState(
        message: _error!,
        icon: Icons.cloud_off_outlined,
        onRetry: fetchData,
      );
    } else if (!_found) {
      content = EmptyState(
        message: 'No se encontró información para este equipo.',
        onRetry: fetchData,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.forklift, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _serie,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [_marca, _modelo]
                              .where((s) => s.isNotEmpty && s != _sinInfo)
                              .join(' · '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  InfoRow(label: 'Serie', value: _serie),
                  InfoRow(label: 'Marca', value: _marca),
                  InfoRow(label: 'Modelo', value: _modelo),
                  InfoRow(label: 'Tipo', value: _tipo),
                  InfoRow(label: 'Voltaje', value: _voltaje),
                  InfoRow(label: 'Capacidad', value: _capacidad),
                  InfoRow(label: 'Altura de estiba', value: _alturaEstiba),
                ],
              ),
            ),
          ),
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
      );
    }

    return RefreshIndicator(
      // Recarga sin ocultar el contenido actual.
      onRefresh: () =>
          fetchDataFromAPI(context.read<SerialNumberModel>().serialNumber),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [content],
      ),
    );
  }
}
