import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/detalle_llamadas_baterias.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

const Color especialColor = Color(0xFFA9DFBF);
const Color correctivoColor = Color(0xFFFAD02E);
const Color preventivoColor = Color(0xFFE8DAEF);
const Color azulPastel = Color(0xFFADD8E6);
const Color rojopastel = Color(0xFFFFB6C1);

/// Colores por tipo de servicio (nombres tal como llegan de SAP).
const Map<String, Color> _serviceTypeColors = {
  'Especial': especialColor,
  'Correctivo': correctivoColor,
  'Preventivo Equipo': preventivoColor,
  'Daños': azulPastel,
  'Preventivo Bateria': rojopastel,
};

Color _colorForServiceType(String tipoServicio) =>
    _serviceTypeColors[tipoServicio] ?? Colors.grey;

/// Excepción interna: la sesión de SAP expiró y ya se redirigió al login.
class _SessionExpired implements Exception {}

class LlamadaServiciosBaterias extends StatefulWidget {
  const LlamadaServiciosBaterias({super.key});

  @override
  State<LlamadaServiciosBaterias> createState() =>
      _LlamadaServiciosBateriasState();
}

class _LlamadaServiciosBateriasState extends State<LlamadaServiciosBaterias> {
  static const _timeout = Duration(seconds: 25);

  late final IOClient _ioClient = IOClient(
    HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true,
  );

  bool isOption1Selected = true;
  late Future<List<LlamadaServicio>> futureCalls;
  int touchedIndex = -1;
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  @override
  void initState() {
    super.initState();
    // La consulta se hace una sola vez aquí (antes se repetía en cada build).
    futureCalls = fetchData();
  }

  @override
  void dispose() {
    _ioClient.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = fetchData();
    setState(() => futureCalls = future);
    try {
      await future;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
  }

  Future<List<LlamadaServicio>> fetchData() async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;
    if (numSerie.isNotEmpty) {
      final authProvider = context.read<AuthProvider>();
      sessionCookie = authProvider.sessionCookie;
      routeIdCookie = authProvider.routeIdCookie;
      authToken = authProvider.authToken;
      return fetchDataFromAPI(numSerie);
    }
    return [];
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

  Future<List<LlamadaServicio>> fetchDataFromAPI(String numSerie) async {
    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes)?'
      '\$expand=ServiceCalls(\$select=ServiceCallID, Subject, CreationDate),'
      'ServiceCallTypes(\$select=Name)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and ServiceCalls/ManufacturerSerialNum eq \'$numSerie\'&'
      '\$orderby=CreationDate desc',
    );

    final http.Response response;
    try {
      response = await _ioClient.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      ).timeout(_timeout);
    } on TimeoutException {
      throw 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } on SocketException {
      throw 'No se pudo conectar con el servidor. Revisa tu conexión.';
    } catch (e) {
      throw 'Ocurrió un error inesperado: $e';
    }

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final values = decoded is Map ? decoded['value'] : null;
      if (values is! List) return [];
      return values
          .whereType<Map>()
          .map((m) => LlamadaServicio.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else if (response.statusCode == 401) {
      dynamic err;
      try {
        final decoded = json.decode(response.body);
        err = decoded is Map ? decoded['error'] : null;
      } catch (_) {}
      if (err is Map && err['code'] == 301) {
        _goToLogin();
        throw _SessionExpired();
      }
      final msg =
          err is Map && err['message'] is Map ? err['message']['value'] : null;
      throw 'Error en la solicitud.\n'
          'Código de error: ${err is Map ? err['code'] : 401}'
          '${msg != null ? '\nMensaje: $msg' : ''}';
    }
    throw 'Error en la solicitud.\nCódigo de error: ${response.statusCode}';
  }

  void _openDetail(LlamadaServicio llamada) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetallesLlamadaServicioBaterias(
          ot: llamada.serviceCallID.toString(),
        ),
      ),
    );
  }

  Widget _scrollableMessage(Widget child) {
    // Scroll siempre activo para que funcione "deslizar para actualizar".
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [const SizedBox(height: 32), child],
    );
  }

  Widget _buildContent(AsyncSnapshot<List<LlamadaServicio>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      if (snapshot.error is _SessionExpired) return const SizedBox.shrink();
      return _scrollableMessage(
        EmptyState(
          message: snapshot.error.toString(),
          icon: Icons.error_outline,
          onRetry: _refresh,
        ),
      );
    }
    final llamadas = snapshot.data ?? const <LlamadaServicio>[];
    if (llamadas.isEmpty) {
      return _scrollableMessage(
        EmptyState(
          message: 'No se encontraron llamadas de servicio.',
          onRetry: _refresh,
        ),
      );
    }

    if (isOption1Selected) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: llamadas.length,
        itemBuilder: (context, i) => _LlamadaCard(
          llamada: llamadas[i],
          onTap: () => _openDetail(llamadas[i]),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PieChartSample2(
              touchedIndex: touchedIndex,
              llamadas: llamadas,
            ),
          ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial de servicios',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.list_alt),
                          label: Text('Lista'),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.pie_chart),
                          label: Text('Gráfica'),
                        ),
                      ],
                      selected: {isOption1Selected},
                      onSelectionChanged: (s) =>
                          setState(() => isOption1Selected = s.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppColors.orange,
                        selectedForegroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<LlamadaServicio>>(
                  future: futureCalls,
                  builder: (context, snapshot) => _buildContent(snapshot),
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

class _LlamadaCard extends StatelessWidget {
  const _LlamadaCard({required this.llamada, required this.onTap});

  final LlamadaServicio llamada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fecha = llamada.creationDate.split('T').first;
    final tipo = llamada.serviceCallTypeName;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'O.T. ${llamada.serviceCallID}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const Spacer(),
                        if (fecha.isNotEmpty)
                          Text(
                            fecha,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      llamada.subject.isEmpty
                          ? 'Sin descripción'
                          : llamada.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (tipo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _colorForServiceType(tipo),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tipo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class LlamadaServicio {
  final int serviceCallID;
  final String subject;
  final String creationDate;
  final String serviceCallTypeName;

  LlamadaServicio({
    required this.serviceCallID,
    required this.subject,
    required this.creationDate,
    required this.serviceCallTypeName,
  });

  factory LlamadaServicio.fromJson(Map<String, dynamic> json) {
    final serviceCalls =
        json['ServiceCalls'] is Map ? json['ServiceCalls'] : {};
    final serviceCallTypes =
        json['ServiceCallTypes'] is Map ? json['ServiceCallTypes'] : {};
    final id = serviceCalls['ServiceCallID'];

    return LlamadaServicio(
      serviceCallID: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      subject: serviceCalls['Subject']?.toString() ?? '',
      creationDate: serviceCalls['CreationDate']?.toString() ?? '',
      serviceCallTypeName: serviceCallTypes['Name']?.toString() ?? '',
    );
  }
}

class PieChartSample2 extends StatelessWidget {
  final int touchedIndex;
  final List<LlamadaServicio> llamadas;

  const PieChartSample2({
    super.key,
    required this.touchedIndex,
    required this.llamadas,
  });

  Map<String, int> _counts() {
    final Map<String, int> serviceTypeCounts = {};
    for (final llamada in llamadas) {
      final tipoServicio = llamada.serviceCallTypeName;
      serviceTypeCounts[tipoServicio] =
          (serviceTypeCounts[tipoServicio] ?? 0) + 1;
    }
    return serviceTypeCounts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ajusta el tamaño de la gráfica al ancho disponible.
        final size = constraints.maxWidth.clamp(180.0, 300.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 0,
                  sectionsSpace: 4,
                  borderData: FlBorderData(show: false),
                  sections: _generatePieChartSections(counts, size / 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildIndicators(counts),
          ],
        );
      },
    );
  }

  Widget _buildIndicators(Map<String, int> counts) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: counts.entries.map((entry) {
        return _buildIndicator(
          _colorForServiceType(entry.key),
          '${entry.key.isEmpty ? 'Sin tipo' : entry.key} (${entry.value})',
        );
      }).toList(),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    );
  }

  List<PieChartSectionData> _generatePieChartSections(
    Map<String, int> counts,
    double radius,
  ) {
    return counts.entries.map((entry) {
      final int cantidad = entry.value;
      final double porcentaje = (cantidad / llamadas.length) * 100;
      return PieChartSectionData(
        color: _colorForServiceType(entry.key),
        value: cantidad.toDouble(),
        title: '($cantidad)\n${porcentaje.toStringAsFixed(2)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.dark,
        ),
      );
    }).toList();
  }

  Color getColorForServiceType(String tipoServicio) =>
      _colorForServiceType(tipoServicio);
}
