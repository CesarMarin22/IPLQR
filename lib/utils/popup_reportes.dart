import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:proyecto_qr/screens/reportes_resultados.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

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

void mostrarPopupReportes(
  BuildContext context, {
  String? clienteInicial,
  DateTime? fechaInicioInicial,
  DateTime? fechaFinInicial,
  String? sucursalInicial,
}) {
  final TextEditingController clienteController =
      TextEditingController(text: clienteInicial ?? '');

  DateTime? fechaInicio = fechaInicioInicial;
  DateTime? fechaFin = fechaFinInicial;
  String? sucursalSeleccionada = sucursalInicial ?? "*";

  List<dynamic> sugerencias = [];
  Timer? debounce;

  final List<Map<String, String>> sucursales = [
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

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final authToken = authProvider.authToken;
  final sessionCookie = authProvider.sessionCookie;
  final routeIdCookie = authProvider.routeIdCookie;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.bar_chart, color: Color.fromARGB(255, 243, 138, 0)),
            SizedBox(width: 8),
            Text(
              'Consulta de Reportes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            void buscarCliente(String input) {
              if (debounce?.isActive ?? false) debounce!.cancel();

              debounce = Timer(const Duration(milliseconds: 500), () async {
                if (input.isEmpty) {
                  setState(() => sugerencias = []);
                  return;
                }

                final uri = Uri.parse(
                  "https://68.155.144.63:50000/b1s/v1/BusinessPartners?"
                  "\$filter=(contains(CardCode,'$input') or contains(CardName,'$input') or contains(CardForeignName,'$input')) and CardType eq 'cCustomer'",
                );

                try {
                  final response = await http.get(
                    uri,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $authToken',
                      'Cookie':
                          'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
                    },
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    setState(() => sugerencias = data['value'] ?? []);
                  } else {
                    setState(() => sugerencias = []);
                  }
                } catch (_) {
                  setState(() => sugerencias = []);
                }
              });
            }

            Future<void> seleccionarFechaInicio() async {
              final fecha = await showDatePicker(
                context: context,
                initialDate: fechaInicio ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );

              if (fecha != null) {
                setState(() => fechaInicio = fecha);
              }
            }

            Future<void> seleccionarFechaFin() async {
              final fecha = await showDatePicker(
                context: context,
                initialDate: fechaFin ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );

              if (fecha != null) {
                setState(() => fechaFin = fecha);
              }
            }

            return SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cliente',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: clienteController,
                      inputFormatters: [UpperCaseTextFormatter()],
                      onChanged: (value) {
                        buscarCliente(value);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Nombre o código del cliente',
                        hintText: 'Ej. C00001 o nombre del cliente',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    if (sugerencias.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sugerencias.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final cliente = sugerencias[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                "${cliente['CardCode']} - ${cliente['CardName']}",
                              ),
                              onTap: () {
                                clienteController.text =
                                    "${cliente['CardCode']} - ${cliente['CardName']}";
                                setState(() => sugerencias = []);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Sucursal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: sucursalSeleccionada,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: sucursales.map((s) {
                        return DropdownMenuItem<String>(
                          value: s["value"],
                          child: Text("${s["value"]} - ${s["label"]}"),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          sucursalSeleccionada = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Rango de fechas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: seleccionarFechaInicio,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black38),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fechaInicio != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(fechaInicio!)
                                          : 'Fecha inicio',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: seleccionarFechaFin,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black38),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      fechaFin != null
                                          ? DateFormat('yyyy-MM-dd')
                                              .format(fechaFin!)
                                          : 'Fecha final',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Consultar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 243, 138, 0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final clienteRaw = clienteController.text.trim();
              final clienteCode = clienteRaw.split(" - ").first.trim();

              if (clienteCode.isEmpty ||
                  fechaInicio == null ||
                  fechaFin == null ||
                  sucursalSeleccionada == null ||
                  sucursalSeleccionada!.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text("Completa todos los campos"),
                  ),
                );
                return;
              }

              if (fechaInicio!.isAfter(fechaFin!)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "La fecha de inicio no puede ser mayor a la fecha final",
                    ),
                  ),
                );
                return;
              }

              final body = jsonEncode({
                "cliente": clienteCode,
                "fecha1": DateFormat('yyyy-MM-dd').format(fechaInicio!),
                "fecha2": DateFormat('yyyy-MM-dd').format(fechaFin!),
                "sucursal": sucursalSeleccionada,
              });

              final uri = Uri.parse(
                "http://68.155.144.63:8081/api/llamadas-servicio",
              );

              try {
                final response = await http.post(
                  uri,
                  headers: {"Content-Type": "application/json"},
                  body: body,
                );

                if (!dialogContext.mounted) return;

                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);

                  Navigator.pop(dialogContext);

                  Navigator.push(
                    dialogContext,
                    MaterialPageRoute(
                      builder: (context) => ReporteResultadosScreen(
                        resultados: data,
                        clienteNombre: clienteRaw,
                        fechaInicio: fechaInicio!,
                        fechaFin: fechaFin!,
                        sucursal: sucursalSeleccionada!,
                      ),
                    ),
                  );
                } else {
                  throw Exception(
                    'Error ${response.statusCode}: ${response.body}',
                  );
                }
              } catch (e) {
                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text("Error al generar reporte: $e"),
                  ),
                );
              }
            },
          ),
        ],
      );
    },
  ).then((_) {
    debounce?.cancel();
    clienteController.dispose();
  });
}
