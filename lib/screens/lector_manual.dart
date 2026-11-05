import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  static const _timeout = Duration(seconds: 25);

  final TextEditingController serialNumberController = TextEditingController();
  final FocusNode serialFocusNode = FocusNode();

  bool _isLoading = false;

  @override
  void dispose() {
    serialNumberController.dispose();
    serialFocusNode.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: AppColors.danger,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Future<void> _buscarSerie() async {
    final serie = serialNumberController.text.trim();
    if (serie.isEmpty || _isLoading) return;

    FocusScope.of(context).unfocus();

    // Leer todo lo que depende de context antes del primer await.
    context.read<SerialNumberModel>().setSerialNumber(serie);
    context.read<AuthProvider>().resetSession();
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    String? error;
    Widget? destino;
    try {
      destino = await _fetchDestino(serie);
      if (destino == null) {
        error = 'No se encontró un artículo válido con ese número de serie.';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } on _HttpStatusException catch (e) {
      error =
          'No fue posible consultar la información. Código: ${e.code}';
    } catch (_) {
      error = 'Ocurrió un error al consultar el número de serie.';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final page = destino;
    if (page == null) {
      _showToast(error ?? 'Ocurrió un error al consultar el número de serie.');
      return;
    }

    await navigator.push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    serialNumberController.clear();
  }

  /// Consulta el artículo (SAP, a través de la Intranet) y devuelve el menú a
  /// abrir, o null si no es válido.
  Future<Widget?> _fetchDestino(String serie) async {
    final response = await Api.get(
      '/app-montacargas/articulo',
      {'serie': serie},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw _HttpStatusException(response.statusCode);
    }

    final decoded = json.decode(response.body);
    final values = decoded is Map ? decoded['value'] : null;
    if (values is! List) return null;

    for (final item in values) {
      if (item is! Map || item['ItemGroups'] == null) continue;

      final groups = item['ItemGroups'];
      final items = item['Items'];
      final tipo = groups is Map ? (groups['GroupName'] ?? '') : '';
      final assetGroup = items is Map ? (items['AssetGroup'] ?? '') : '';

      if (tipo == 'MONTACARGAS' || assetGroup == 'MO') {
        return const menuEquipos();
      } else if (tipo == 'BATERIAS' || assetGroup == 'BAT') {
        return const menuBaterias();
      } else if (tipo == 'CARGADORES' || assetGroup == 'CAR') {
        return const menuCargadores();
      }
    }
    return null;
  }

  void _volverAlMenu() {
    context.read<SerialNumberModel>().setSerialNumber('');
    final navigator = Navigator.of(context);
    // Esta pantalla se abre desde el menú (eleccion): volver a él sin
    // apilar un segundo menú.
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const eleccion()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Image.asset('assets/logo ipl_BLANCO.png', height: 52),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const Text(
                  'Búsqueda manual',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ingresa el número de serie para localizar el equipo, batería o cargador.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: serialNumberController,
                          focusNode: serialFocusNode,
                          enabled: !_isLoading,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _buscarSerie(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Número de serie',
                            hintText: 'Ejemplo: ABC123456',
                            prefixIcon: Icon(Icons.qr_code_2_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Solo este botón se reconstruye al escribir.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: serialNumberController,
                          builder: (context, value, _) {
                            final habilitado =
                                value.text.trim().isNotEmpty && !_isLoading;
                            return ElevatedButton.icon(
                              onPressed: habilitado ? _buscarSerie : null,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.dark,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(
                                _isLoading ? 'Buscando...' : 'Buscar equipo',
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _volverAlMenu,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text(
                            'Volver a escanear',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8EB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.orange),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Usa esta opción cuando el código QR no esté disponible o no pueda leerse correctamente.',
                          style: TextStyle(fontSize: 14, color: AppColors.dark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Color(0x33FFFFFF),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}

class _HttpStatusException implements Exception {
  const _HttpStatusException(this.code);
  final int code;
}
