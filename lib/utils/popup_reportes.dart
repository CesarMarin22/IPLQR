import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/reportes_resultados.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

const _timeout = Duration(seconds: 25);
final _fmt = DateFormat('yyyy-MM-dd');

const List<Map<String, String>> _sucursales = [
  {"value": "*", "label": "Todas las sucursales"},
  {"value": "AGS", "label": "Aguascalientes"},
  {"value": "CLY", "label": "Celaya"},
  {"value": "GDL", "label": "Guadalajara"},
  {"value": "IRA", "label": "Irapuato"},
  {"value": "MEX", "label": "Ciudad de México"},
  {"value": "MTY", "label": "Monterrey"},
  {"value": "QRO", "label": "Querétaro"},
  {"value": "SLP", "label": "San Luis Potosí"},
  {"value": "TOL", "label": "Toluca"},
  {"value": "PUE", "label": "Puebla"},
];

/// Resultado que devuelve el diálogo cuando la consulta fue exitosa.
class _ReporteResult {
  const _ReporteResult({
    required this.resultados,
    required this.clienteNombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.sucursal,
  });

  final List<dynamic> resultados;
  final String clienteNombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String sucursal;
}

void mostrarPopupReportes(
  BuildContext context, {
  String? clienteInicial,
  DateTime? fechaInicioInicial,
  DateTime? fechaFinInicial,
  String? sucursalInicial,
}) {
  Provider.of<AuthProvider>(context, listen: false).resetSession();
  // Se captura el Navigator ahora: el context del diálogo deja de existir al
  // cerrarlo y no debe usarse para navegar después (causaba
  // "_dependents.isEmpty").
  final navigator = Navigator.of(context);

  showDialog<_ReporteResult>(
    context: context,
    builder: (_) => _ReportesDialog(
      clienteInicial: clienteInicial,
      fechaInicioInicial: fechaInicioInicial,
      fechaFinInicial: fechaFinInicial,
      sucursalInicial: sucursalInicial,
    ),
  ).then((result) {
    if (result == null || !navigator.mounted) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReporteResultadosScreen(
          resultados: result.resultados,
          clienteNombre: result.clienteNombre,
          fechaInicio: result.fechaInicio,
          fechaFin: result.fechaFin,
          sucursal: result.sucursal,
        ),
      ),
    );
  });
}

class _ReportesDialog extends StatefulWidget {
  const _ReportesDialog({
    this.clienteInicial,
    this.fechaInicioInicial,
    this.fechaFinInicial,
    this.sucursalInicial,
  });

  final String? clienteInicial;
  final DateTime? fechaInicioInicial;
  final DateTime? fechaFinInicial;
  final String? sucursalInicial;

  @override
  State<_ReportesDialog> createState() => _ReportesDialogState();
}

class _ReportesDialogState extends State<_ReportesDialog> {
  late final TextEditingController _clienteController =
      TextEditingController(text: widget.clienteInicial ?? '');

  late DateTime? _fechaInicio = widget.fechaInicioInicial;
  late DateTime? _fechaFin = widget.fechaFinInicial;
  late String _sucursal = _sucursales.any(
    (s) => s['value'] == widget.sucursalInicial,
  )
      ? widget.sucursalInicial!
      : '*';

  List<dynamic> _sugerencias = [];
  bool _buscandoClientes = false;
  bool _consultando = false;
  String? _error;

  Timer? _debounce;
  int _busquedaId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _clienteController.dispose();
    super.dispose();
  }

  void _buscarCliente(String input) {
    _debounce?.cancel();
    if (_error != null) setState(() => _error = null);

    if (input.isEmpty) {
      _busquedaId++;
      setState(() {
        _sugerencias = [];
        _buscandoClientes = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final id = ++_busquedaId;
      if (!mounted) return;
      setState(() => _buscandoClientes = true);


      List<dynamic> nuevas = [];
      try {
        final response = await Api.get(
          '/app-montacargas/clientes',
          {'q': input},
        ).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final value = data is Map ? data['value'] : null;
          if (value is List) nuevas = value;
        }
      } catch (_) {
        nuevas = [];
      }

      // Ignorar respuestas de búsquedas anteriores o si el diálogo se cerró.
      if (!mounted || id != _busquedaId) return;
      setState(() {
        _sugerencias = nuevas;
        _buscandoClientes = false;
      });
    });
  }

  String _textoCliente(dynamic cliente) {
    if (cliente is! Map) return '';
    return "${cliente['CardCode'] ?? ''} - ${cliente['CardName'] ?? ''}";
  }

  Future<void> _seleccionarFecha({required bool inicio}) async {
    final actual = inicio ? _fechaInicio : _fechaFin;
    final fecha = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha == null || !mounted) return;
    setState(() {
      if (inicio) {
        _fechaInicio = fecha;
      } else {
        _fechaFin = fecha;
      }
      _error = null;
    });
  }

  Future<void> _consultar() async {
    if (_consultando) return;

    final clienteRaw = _clienteController.text.trim();
    final clienteCode = clienteRaw.split(" - ").first.trim();
    final fechaInicio = _fechaInicio;
    final fechaFin = _fechaFin;

    if (clienteCode.isEmpty ||
        fechaInicio == null ||
        fechaFin == null ||
        _sucursal.isEmpty) {
      setState(() => _error = 'Completa todos los campos');
      return;
    }

    if (fechaInicio.isAfter(fechaFin)) {
      setState(
        () => _error = 'La fecha de inicio no puede ser mayor a la fecha final',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _consultando = true;
      _error = null;
    });

    final body = {
      "cliente": clienteCode,
      "fecha1": _fmt.format(fechaInicio),
      "fecha2": _fmt.format(fechaFin),
      "sucursal": _sucursal,
    };


    String error;
    try {
      final response = await Api.post('/app-montacargas/reporte-clientes', body)
          .timeout(_timeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          Navigator.of(context).pop(
            _ReporteResult(
              resultados: data,
              clienteNombre: clienteRaw,
              fechaInicio: fechaInicio,
              fechaFin: fechaFin,
              sucursal: _sucursal,
            ),
          );
          return;
        }
        error = 'Error al generar reporte: respuesta inesperada del servidor.';
      } else {
        error = 'Error al generar reporte (código ${response.statusCode}).';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } catch (_) {
      error = 'Error al generar reporte. Revisa tu conexión e intenta de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _consultando = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Row(
        children: [
          Icon(Icons.bar_chart_rounded, color: AppColors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Consulta de Reportes',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Label('Cliente'),
              TextField(
                controller: _clienteController,
                enabled: !_consultando,
                inputFormatters: [UpperCaseTextFormatter()],
                textInputAction: TextInputAction.search,
                onChanged: _buscarCliente,
                decoration: InputDecoration(
                  labelText: 'Nombre o código del cliente',
                  hintText: 'Ej. C00001 o nombre del cliente',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscandoClientes
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              if (_sugerencias.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _sugerencias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final texto = _textoCliente(_sugerencias[index]);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.business_outlined),
                          title: Text(texto),
                          onTap: () {
                            _busquedaId++;
                            _debounce?.cancel();
                            _clienteController.text = texto;
                            setState(() {
                              _sugerencias = [];
                              _buscandoClientes = false;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _Label('Sucursal'),
              DropdownButtonFormField<String>(
                initialValue: _sucursal,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                items: [
                  for (final s in _sucursales)
                    DropdownMenuItem<String>(
                      value: s["value"],
                      child: Text(
                        "${s["value"]} - ${s["label"]}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _consultando
                    ? null
                    : (value) {
                        if (value != null) setState(() => _sucursal = value);
                      },
              ),
              const SizedBox(height: 16),
              const _Label('Rango de fechas'),
              Row(
                children: [
                  Expanded(
                    child: _FechaBox(
                      texto: _fechaInicio != null
                          ? _fmt.format(_fechaInicio!)
                          : 'Fecha inicio',
                      onTap: _consultando
                          ? null
                          : () => _seleccionarFecha(inicio: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FechaBox(
                      texto: _fechaFin != null
                          ? _fmt.format(_fechaFin!)
                          : 'Fecha final',
                      onTap: _consultando
                          ? null
                          : () => _seleccionarFecha(inicio: false),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: _consultando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _consultando ? null : _consultar,
          icon: _consultando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(_consultando ? 'Consultando...' : 'Consultar'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
      ),
    );
  }
}

class _FechaBox extends StatelessWidget {
  const _FechaBox({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          borderRadius: radius,
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range, size: 20, color: AppColors.dark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(texto, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
