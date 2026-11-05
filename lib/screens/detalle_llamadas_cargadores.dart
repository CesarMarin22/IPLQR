import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

/// Detalle de una orden de trabajo (llamada de servicio) de un cargador.
///
/// Antes esta clase se llamaba igual que la de baterías
/// (DetallesLlamadaServicioBaterias) y nadie la usaba: el historial de
/// cargadores abría la pantalla de baterías.
class DetallesLlamadaServicioCargadores extends StatefulWidget {
  final String ot;

  const DetallesLlamadaServicioCargadores({super.key, required this.ot});

  @override
  State<DetallesLlamadaServicioCargadores> createState() =>
      _DetallesLlamadaServicioCargadoresState();
}

class _DetallesLlamadaServicioCargadoresState
    extends State<DetallesLlamadaServicioCargadores> {
  static const _timeout = Duration(seconds: 25);
  static const _sinDato = '(no se proporcionó el dato)';

  late final IOClient _client = IOClient(
    HttpClient()
      ..connectionTimeout = _timeout
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) =>
              true, // Permite certificados autofirmados
  );

  Map<String, dynamic>? detallesOT; // Almacena los detalles de la OT
  bool _loading = true;
  bool _sinDetalles = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOTDetails(widget.ot);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
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

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
      _sinDetalles = false;
    });
    await _fetchOTDetails(widget.ot);
  }

  Future<void> _fetchOTDetails(String ot) async {
    final auth = context.read<AuthProvider>();
    final authToken = auth.authToken;
    final sessionCookie = auth.sessionCookie;
    final routeIdCookie = auth.routeIdCookie;

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes,EmployeesInfo)?'
      '\$expand=ServiceCalls(\$select=Subject,U_PersonWhoReports,Resolution),'
      'ServiceCallTypes(\$select=Name),'
      'EmployeesInfo(\$select=FirstName,LastName)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and EmployeesInfo/EmployeeID eq ServiceCalls/TechnicianCode and ServiceCalls/ServiceCallID eq $ot',
    );

    Map<String, dynamic>? detalles;
    bool sinDetalles = false;
    String? error;

    try {
      final response = await _client.get(
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
        if (values is List && values.isNotEmpty && values.first is Map) {
          detalles = Map<String, dynamic>.from(values.first as Map);
        } else {
          sinDetalles = true;
        }
      } else if (response.statusCode == 401) {
        _goToLogin('Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.');
        return;
      } else if (response.statusCode == 404) {
        // Llamada de servicio no contiene detalles
        sinDetalles = true;
      } else {
        error =
            'Error en la solicitud.\nCódigo de error: ${response.statusCode}';
      }
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } catch (e) {
      error = 'No se pudo obtener el detalle. Revisa tu conexión.';
    }

    if (!mounted) return;
    setState(() {
      detallesOT = detalles;
      _sinDetalles = sinDetalles;
      _error = error;
      _loading = false;
    });
  }

  Map _section(String key) {
    final value = detallesOT?[key];
    return value is Map ? value : const {};
  }

  String _value(dynamic v) {
    if (v == null) return _sinDato;
    final s = v.toString().trim();
    return s.isEmpty ? _sinDato : s;
  }

  String _tecnico() {
    final emp = _section('EmployeesInfo');
    final nombre = [emp['FirstName'], emp['LastName']]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .join(' ');
    return nombre.isEmpty ? _sinDato : nombre;
  }

  Widget _buildDetails() {
    final calls = _section('ServiceCalls');
    final types = _section('ServiceCallTypes');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Text(
          'Detalle de OT',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Número de OT: ${widget.ot}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.orangeDark,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                InfoRow(label: 'Falla', value: _value(calls['Subject'])),
                const Divider(height: 1),
                InfoRow(
                  label: 'Persona que reporta',
                  value: _value(calls['U_PersonWhoReports']),
                ),
                const Divider(height: 1),
                InfoRow(label: 'Técnico', value: _tecnico()),
                const Divider(height: 1),
                InfoRow(
                  label: 'Tipo de servicio',
                  value: _value(types['Name']),
                ),
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
                  'Trabajo realizado',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _value(calls['Resolution']),
                  style: const TextStyle(fontSize: 15, color: AppColors.dark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        onRetry: _retry,
      );
    }
    if (_sinDetalles || detallesOT == null) {
      return const EmptyState(
        icon: Icons.description_outlined,
        message: 'Llamada de servicio sin detalles.\n'
            'La llamada de servicio no contiene detalles.',
      );
    }
    return _buildDetails();
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
