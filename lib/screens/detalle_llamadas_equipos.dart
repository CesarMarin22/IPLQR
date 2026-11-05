import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

const _timeout = Duration(seconds: 25);

class DetallesLlamadaServicioEquipos extends StatefulWidget {
  final String ot;

  const DetallesLlamadaServicioEquipos({super.key, required this.ot});

  @override
  State<DetallesLlamadaServicioEquipos> createState() =>
      _DetallesLlamadaServicioEquiposState();
}

class _DetallesLlamadaServicioEquiposState
    extends State<DetallesLlamadaServicioEquipos> {
  /// Detalles de la OT tal como los devuelve SAP.
  Map<String, dynamic>? detallesOT;
  bool _loading = true;
  bool _sinDetalles = false;
  String? _error;

  IOClient? _client;
  IOClient get _http => _client ??= IOClient(
        HttpClient()
          ..connectionTimeout = _timeout
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true,
      );

  @override
  void initState() {
    super.initState();
    _fetchOTDetails(widget.ot);
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
      _sinDetalles = false;
    });
    _fetchOTDetails(widget.ot);
  }

  Future<void> _fetchOTDetails(String ot) async {
    final auth = context.read<AuthProvider>();
    final authToken = auth.authToken;
    final sessionCookie = auth.sessionCookie;
    final routeIdCookie = auth.routeIdCookie;

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes,EmployeesInfo)?'
      '\$expand=ServiceCalls(\$select=Subject,U_PersonWhoReports,Resolution,U_Horometro),'
      'ServiceCallTypes(\$select=Name),'
      'EmployeesInfo(\$select=FirstName,LastName)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and EmployeesInfo/EmployeeID eq ServiceCalls/TechnicianCode and ServiceCalls/ServiceCallID eq $ot',
    );

    Map<String, dynamic>? detalles;
    var sinDetalles = false;
    String? error;

    try {
      final response = await _http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      ).timeout(_timeout);
      if (!mounted) return;

      // Antes las ramas 401/404/otros estaban dentro del "if 200" y nunca se
      // ejecutaban: la pantalla se quedaba cargando para siempre.
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        if (values is List &&
            values.isNotEmpty &&
            values.first is Map<String, dynamic>) {
          detalles = values.first as Map<String, dynamic>;
        } else {
          sinDetalles = true;
        }
      } else if (response.statusCode == 401) {
        // Igual que antes: cualquier 401 (código 301 u otro) lleva al login.
        _sessionExpired();
        return;
      } else if (response.statusCode == 404) {
        sinDetalles = true;
      } else {
        error = 'Error en la solicitud (código ${response.statusCode}).';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    } catch (e) {
      debugPrint('Error detalle_llamadas_equipos: $e');
      error = 'No se pudo conectar con el servidor.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      detallesOT = detalles;
      _sinDetalles = sinDetalles;
      _error = error;
    });
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

  /// Lee detallesOT[grupo][campo] como texto sin lanzar excepciones.
  String _campo(String grupo, String campo) {
    final g = detallesOT?[grupo];
    if (g is! Map) return '';
    final v = g[campo];
    return v == null ? '' : v.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de OT')),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SingleChildScrollView(
        child: EmptyState(
          message: _error!,
          icon: Icons.cloud_off_outlined,
          onRetry: _retry,
        ),
      );
    }
    if (_sinDetalles || detallesOT == null) {
      return SingleChildScrollView(
        child: EmptyState(
          message: 'La llamada de servicio no contiene detalles.',
          onRetry: _retry,
        ),
      );
    }

    final tecnico = [
      _campo('EmployeesInfo', 'FirstName'),
      _campo('EmployeesInfo', 'LastName'),
    ].where((s) => s.isNotEmpty).join(' ');
    final tipo = _campo('ServiceCallTypes', 'Name');
    final resolucion = _campo('ServiceCalls', 'Resolution');

    return ListView(
      padding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.build_outlined, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OT ${widget.ot}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      if (tipo.isNotEmpty)
                        Text(
                          tipo,
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
                InfoRow(
                    label: 'Falla', value: _campo('ServiceCalls', 'Subject')),
                InfoRow(
                  label: 'Horómetro',
                  value: _campo('ServiceCalls', 'U_Horometro'),
                ),
                InfoRow(
                  label: 'Persona que reporta',
                  value: _campo('ServiceCalls', 'U_PersonWhoReports'),
                ),
                InfoRow(label: 'Técnico', value: tecnico),
                InfoRow(label: 'Tipo de servicio', value: tipo),
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
                  'Trabajo realizado',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  resolucion.isEmpty ? '—' : resolucion,
                  style: const TextStyle(fontSize: 15, color: AppColors.dark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
