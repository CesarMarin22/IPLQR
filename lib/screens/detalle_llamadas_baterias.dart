import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class DetallesLlamadaServicioBaterias extends StatefulWidget {
  final String ot;

  const DetallesLlamadaServicioBaterias({super.key, required this.ot});

  @override
  State<DetallesLlamadaServicioBaterias> createState() =>
      _DetallesLlamadaServicioBateriasState();
}

class _DetallesLlamadaServicioBateriasState
    extends State<DetallesLlamadaServicioBaterias> {
  static const _sinDato = '(no se proporcionó el dato)';
  static const _timeout = Duration(seconds: 25);

  late final IOClient _ioClient = IOClient(
    HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true,
  );

  Map<String, dynamic>? detallesOT; // Almacena los detalles de la OT
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  bool _loading = true;
  String? _error;
  bool _sinDetalles = false;

  @override
  void initState() {
    super.initState();
    // Realizar una consulta a la API para obtener los detalles de la OT
    _fetchOTDetails(widget.ot);
  }

  @override
  void dispose() {
    _ioClient.close();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
      _sinDetalles = false;
    });
    await _fetchOTDetails(widget.ot);
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

  Future<void> _fetchOTDetails(String ot) async {
    final authProvider = context.read<AuthProvider>();
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes,EmployeesInfo)?'
      '\$expand=ServiceCalls(\$select=Subject,U_PersonWhoReports,Resolution),'
      'ServiceCallTypes(\$select=Name),'
      'EmployeesInfo(\$select=FirstName,LastName)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and EmployeesInfo/EmployeeID eq ServiceCalls/TechnicianCode and ServiceCalls/ServiceCallID eq $ot',
    );

    Map<String, dynamic>? detalles;
    String? error;
    bool sinDetalles = false;

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
        if (values is List && values.isNotEmpty && values.first is Map) {
          detalles = Map<String, dynamic>.from(values.first as Map);
        } else {
          // Antes se quedaba cargando para siempre en este caso.
          sinDetalles = true;
        }
      } else if (response.statusCode == 401) {
        // Antes este bloque estaba dentro del caso 200 y nunca se ejecutaba.
        // Igual que la lógica original: con código 301 o cualquier otro 401
        // se considera la sesión expirada y se vuelve al login.
        _goToLogin();
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
    } on SocketException {
      error = 'No se pudo conectar con el servidor. Revisa tu conexión.';
    } catch (e) {
      error = 'Ocurrió un error inesperado: $e';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      detallesOT = detalles;
      _error = error;
      _sinDetalles = sinDetalles;
    });
  }

  String _field(String entity, String key) {
    final obj = detallesOT?[entity];
    if (obj is! Map) return _sinDato;
    final value = obj[key];
    if (value == null || value.toString().trim().isEmpty) return _sinDato;
    return value.toString();
  }

  String _tecnico() {
    final emp = detallesOT?['EmployeesInfo'];
    if (emp is! Map) return _sinDato;
    final nombre = [emp['FirstName'], emp['LastName']]
        .where((v) => v != null && v.toString().trim().isNotEmpty)
        .join(' ');
    return nombre.isEmpty ? _sinDato : nombre;
  }

  Widget _backButton() {
    return OutlinedButton.icon(
      // Regresa a la lista de la que se vino (antes abría siempre la lista de
      // baterías, aun viniendo de cargadores, y apilaba pantallas).
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back),
      label: const Text('Regresar'),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sinDetalles || _error != null || detallesOT == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),
          EmptyState(
            message: _error ??
                'Llamada de servicio sin detalles.\n'
                    'La llamada de servicio no contiene detalles.',
            icon: _error != null ? Icons.error_outline : Icons.inbox_outlined,
            onRetry: _error != null ? _retry : null,
          ),
          _backButton(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Text(
          'Detalle de OT',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Número de OT: ${widget.ot}',
          style: const TextStyle(fontSize: 15, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                InfoRow(
                  label: 'Tipo de servicio',
                  value: _field('ServiceCallTypes', 'Name'),
                ),
                InfoRow(label: 'Técnico', value: _tecnico()),
                InfoRow(
                  label: 'Persona que reporta',
                  value: _field('ServiceCalls', 'U_PersonWhoReports'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _TextBlock(
          icon: Icons.report_problem_outlined,
          label: 'Falla',
          value: _field('ServiceCalls', 'Subject'),
        ),
        const SizedBox(height: 8),
        _TextBlock(
          icon: Icons.build_outlined,
          label: 'Trabajo realizado',
          value: _field('ServiceCalls', 'Resolution'),
        ),
        const SizedBox(height: 20),
        _backButton(),
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
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: const AppFooter(),
    );
  }
}

/// Bloque de texto largo (falla / trabajo realizado) con etiqueta arriba.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.orangeDark),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              value,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
