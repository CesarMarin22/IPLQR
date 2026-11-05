import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/detalle_llamadas_equipos.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

const Color especialColor = Color(0xFFA9DFBF);
const Color correctivoColor = Color(0xFFFAD02E);
const Color preventivoColor = Color(0xFFE8DAEF);
const Color azulPastel = Color(0xFFADD8E6);
const Color rojopastel = Color(0xFFFFB6C1);

const _timeout = Duration(seconds: 25);

/// Color por tipo de servicio (nombres tal como los devuelve SAP).
Color _colorForServiceType(String tipoServicio) {
  switch (tipoServicio.trim().toUpperCase()) {
    case 'ESPECIAL':
      return especialColor;
    case 'CORRECTIVO':
      return correctivoColor;
    case 'PREVENTIVO':
    case 'PREVENTIVO EQUIPO':
      return preventivoColor;
    case 'DAÑO':
    case 'DAÑOS':
      return azulPastel;
    case 'DIAGNOSTICO':
    case 'DIAGNÓSTICO':
    case 'PREVENTIVO BATERIA':
    case 'PREVENTIVO BATERÍA':
      return rojopastel;
    default:
      return Colors.grey.shade400;
  }
}

/// Fecha "2024-01-31T00:00:00Z" -> "2024-01-31".
String _formatFecha(String fecha) {
  final i = fecha.indexOf('T');
  return i > 0 ? fecha.substring(0, i) : fecha;
}

class LlamadaServiciosEquipos extends StatefulWidget {
  const LlamadaServiciosEquipos({super.key});

  @override
  State<LlamadaServiciosEquipos> createState() =>
      _LlamadaServiciosEquiposState();
}

class _LlamadaServiciosEquiposState extends State<LlamadaServiciosEquipos> {
  bool isOption1Selected = true;
  Future<List<LlamadaServicio>>? futureCalls;
  String? selectedOT;

  /// Error amigable de la última consulta (null si fue correcta).
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
    // La consulta se hace UNA vez aquí (antes se lanzaba en cada build,
    // incluso al cambiar entre tabla y gráfica).
    futureCalls = fetchData();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  void _reload() {
    setState(() {
      futureCalls = fetchData();
    });
  }

  /// true durante el "deslizar para actualizar" (el propio RefreshIndicator
  /// muestra el progreso, así que no se reemplaza la lista por un spinner).
  bool _refreshing = false;

  Future<void> _refresh() async {
    final future = fetchData();
    setState(() {
      _refreshing = true;
      futureCalls = future;
    });
    try {
      await future;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<List<LlamadaServicio>> fetchData() async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;
    if (numSerie.isNotEmpty) {
      return fetchDataFromAPI(numSerie);
    }
    _error = null;
    return [];
  }

  Future<List<LlamadaServicio>> fetchDataFromAPI(String numSerie) async {
    final auth = context.read<AuthProvider>();
    final authToken = auth.authToken;
    final sessionCookie = auth.sessionCookie;
    final routeIdCookie = auth.routeIdCookie;
    _error = null;

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes)?'
      '\$expand=ServiceCalls(\$select=ServiceCallID, Subject, CreationDate),'
      'ServiceCallTypes(\$select=Name)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and ServiceCalls/ManufacturerSerialNum eq \'$numSerie\'&'
      '\$orderby=CreationDate desc',
    );

    try {
      final response = await _http.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie',
        },
      ).timeout(_timeout);
      if (!mounted) return [];

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        if (values is! List) return [];
        return values
            .whereType<Map<String, dynamic>>()
            .map(LlamadaServicio.fromJson)
            .toList();
      } else if (response.statusCode == 401) {
        final err = _parseError(response.body);
        if (err.$1 == 301) {
          _sessionExpired();
          return [];
        }
        _error = 'Error en la solicitud (código ${err.$1 ?? 401}).'
            '${err.$2 != null ? '\n${err.$2}' : ''}';
      } else {
        _error = 'Error en la solicitud (código ${response.statusCode}).';
      }
    } on TimeoutException {
      _error = 'El servidor tardó demasiado en responder.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    } catch (e) {
      debugPrint('Error llamadas_servicio_equipos: $e');
      _error = 'No se pudo conectar con el servidor.\n'
          'Revisa tu conexión e inténtalo de nuevo.';
    }
    return [];
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

  void _openDetalle(LlamadaServicio llamada) {
    selectedOT = llamada.serviceCallID.toString();
    context.read<AuthProvider>().resetSession();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetallesLlamadaServicioEquipos(ot: selectedOT!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de servicios')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.view_list_outlined),
                      label: Text('Lista'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.pie_chart_outline),
                      label: Text('Gráfica'),
                    ),
                  ],
                  selected: {isOption1Selected},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => isOption1Selected = s.first),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LlamadaServicio>>(
                future: futureCalls,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !_refreshing) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final llamadas = snapshot.data ?? const <LlamadaServicio>[];
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildContent(llamadas),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildContent(List<LlamadaServicio> llamadas) {
    if (_error != null || llamadas.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          EmptyState(
            message: _error ?? 'No se encontraron llamadas de servicio.',
            icon: _error != null
                ? Icons.cloud_off_outlined
                : Icons.inbox_outlined,
            onRetry: _reload,
          ),
        ],
      );
    }

    if (!isOption1Selected) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PieChartSample2(touchedIndex: -1, llamadas: llamadas),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: llamadas.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4),
            child: Text(
              '${llamadas.length} '
              '${llamadas.length == 1 ? 'orden de trabajo' : 'órdenes de trabajo'}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          );
        }
        return _LlamadaCard(
          llamada: llamadas[index - 1],
          onTap: _openDetalle,
        );
      },
    );
  }
}

class _LlamadaCard extends StatelessWidget {
  const _LlamadaCard({required this.llamada, required this.onTap});

  final LlamadaServicio llamada;
  final ValueChanged<LlamadaServicio> onTap;

  @override
  Widget build(BuildContext context) {
    final tipo = llamada.serviceCallTypeName;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(llamada),
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
                          'OT ${llamada.serviceCallID}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.dark,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatFecha(llamada.creationDate),
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
                      style:
                          const TextStyle(fontSize: 14, color: AppColors.dark),
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
    final serviceCalls = json['ServiceCalls'];
    final serviceCallTypes = json['ServiceCallTypes'];
    final sc = serviceCalls is Map ? serviceCalls : const {};
    final sct = serviceCallTypes is Map ? serviceCallTypes : const {};
    final id = sc['ServiceCallID'];

    return LlamadaServicio(
      serviceCallID: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      subject: sc['Subject']?.toString() ?? '',
      creationDate: sc['CreationDate']?.toString() ?? '',
      serviceCallTypeName: sct['Name']?.toString() ?? '',
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
      final tipo = llamada.serviceCallTypeName.isEmpty
          ? 'Sin tipo'
          : llamada.serviceCallTypeName;
      serviceTypeCounts[tipo] = (serviceTypeCounts[tipo] ?? 0) + 1;
    }
    return serviceTypeCounts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts();
    final total = llamadas.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth.clamp(160.0, 280.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: size,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: size * 0.18,
                  sectionsSpace: 2,
                  borderData: FlBorderData(show: false),
                  sections: _generatePieChartSections(counts, total, size),
                ),
              ),
            ),
            const SizedBox(height: 20),
            for (final entry in counts.entries)
              _buildIndicator(
                getColorForServiceType(entry.key),
                entry.key,
                entry.value,
                total,
              ),
          ],
        );
      },
    );
  }

  /// Se conserva por compatibilidad; las secciones ahora se basan en el
  /// conteo por tipo (antes se agregaban secciones duplicadas con 0 %).
  List<PieChartSectionData> showingSections(List<LlamadaServicio> llamadas) =>
      _generatePieChartSections(_counts(), llamadas.length, 280);

  Widget _buildIndicator(Color color, String text, int cantidad, int total) {
    final porcentaje = total == 0 ? 0 : cantidad / total * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppColors.dark),
            ),
          ),
          Text(
            '$cantidad · ${porcentaje.toStringAsFixed(1)} %',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generatePieChartSections(
    Map<String, int> counts,
    int total,
    double size,
  ) {
    final radius = size / 2 - size * 0.18 - 4;
    return [
      for (final entry in counts.entries)
        PieChartSectionData(
          color: getColorForServiceType(entry.key),
          value: entry.value.toDouble(),
          title: total == 0
              ? ''
              : '${(entry.value / total * 100).toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.dark,
          ),
        ),
    ];
  }

  Color getColorForServiceType(String tipoServicio) =>
      _colorForServiceType(tipoServicio);
}
