import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/detalle_llamadas_cargadores.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

const Color especialColor = Color(0xFFA9DFBF);
const Color correctivoColor = Color(0xFFFAD02E);
const Color preventivoColor = Color(0xFFE8DAEF);
const Color azulPastel = Color(0xFFADD8E6);
const Color rojopastel = Color(0xFFFFB6C1);

/// Color por tipo de servicio (mismo mapa que usaba la gráfica).
Color _colorForServiceType(String tipoServicio) {
  const colorMap = <String, Color>{
    'Especial': especialColor,
    'Correctivo': correctivoColor,
    'Preventivo Equipo': preventivoColor,
    'Daños': azulPastel,
    'Preventivo Bateria': rojopastel,
  };
  return colorMap[tipoServicio] ?? Colors.grey.shade400;
}

/// Error que se muestra en pantalla con opción de reintentar.
class _LoadException implements Exception {
  _LoadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LlamadaServiciosCargadores extends StatefulWidget {
  const LlamadaServiciosCargadores({super.key});

  @override
  State<LlamadaServiciosCargadores> createState() =>
      _LlamadaServiciosCargadoresState();
}

class _LlamadaServiciosCargadoresState
    extends State<LlamadaServiciosCargadores> {
  static const _timeout = Duration(seconds: 25);

  bool isOption1Selected = true;
  Future<List<LlamadaServicio>>? futureCalls;
  String? selectedOT;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    // Se consulta una sola vez; antes el FutureBuilder llamaba a fetchData()
    // en cada build (cada cambio de vista volvía a pedir los datos).
    futureCalls = fetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<List<LlamadaServicio>> fetchData() async {
    final numSerie = context.read<SerialNumberModel>().serialNumber;
    if (numSerie.isNotEmpty) {
      return fetchDataFromAPI(numSerie);
    }
    return [];
  }

  void _reload() {
    setState(() {
      futureCalls = fetchData();
    });
  }

  Future<void> _refresh() async {
    final future = fetchData();
    setState(() {
      futureCalls = future;
    });
    try {
      await future;
    } catch (_) {
      // El error se muestra en el FutureBuilder.
    }
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

  void _openDetail(LlamadaServicio llamada) {
    setState(() {
      selectedOT = llamada.serviceCallID.toString();
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetallesLlamadaServicioCargadores(
          ot: llamada.serviceCallID.toString(),
        ),
      ),
    );
  }

  Future<List<LlamadaServicio>> fetchDataFromAPI(String numSerie) async {
    context.read<AuthProvider>().resetSession();

    final http.Response response;
    try {
      response = await Api.get('/app-montacargas/llamadas', {'serie': numSerie}).timeout(_timeout);
    } on TimeoutException {
      throw _LoadException(
          'El servidor tardó demasiado en responder. Intenta de nuevo.');
    } catch (_) {
      throw _LoadException(
          'No se pudo obtener el historial. Revisa tu conexión.');
    }

    if (response.statusCode == 200) {
      try {
        final decoded = json.decode(response.body);
        final values = decoded is Map ? decoded['value'] : null;
        if (values is! List) return [];
        return values
            .whereType<Map>()
            .map((e) => LlamadaServicio.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        throw _LoadException('La respuesta del servidor no es válida.');
      }
    }

    if (response.statusCode == 401) {
      Map? err;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['error'] is Map) err = decoded['error'];
      } catch (_) {}
      if (err?['code'] == 301) {
        if (mounted) {
          _goToLogin(
              'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.');
        }
        return [];
      }
      final msg = err?['message'] is Map ? err!['message']['value'] : null;
      throw _LoadException('Error en la solicitud.\nCódigo de error: '
          '${err?['code'] ?? 401}${msg != null ? '\nMensaje: $msg' : ''}');
    }

    throw _LoadException(
        'Error en la solicitud.\nCódigo de error: ${response.statusCode}');
  }

  Widget _buildViewSelector() {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: true,
          icon: Icon(Icons.view_list_rounded),
          label: Text('Lista'),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.pie_chart),
          label: Text('Gráfica'),
        ),
      ],
      selected: {isOption1Selected},
      onSelectionChanged: (s) => setState(() => isOption1Selected = s.first),
    );
  }

  Widget _scrollableMessage(Widget child) {
    // Mantiene el pull-to-refresh disponible también en vacío / error.
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FutureBuilder<List<LlamadaServicio>>(
      future: futureCalls,
      builder: (context, snapshot) {
        // Al refrescar con datos previos se mantiene la lista visible.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _scrollableMessage(EmptyState(
            icon: Icons.cloud_off_outlined,
            message: snapshot.error.toString(),
            onRetry: _reload,
          ));
        }
        final llamadas = snapshot.data ?? const <LlamadaServicio>[];
        if (llamadas.isEmpty) {
          return _scrollableMessage(EmptyState(
            message: 'No se encontraron llamadas de servicio.',
            onRetry: _reload,
          ));
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
            PieChartSample2(touchedIndex: touchedIndex, llamadas: llamadas),
          ],
        );
      },
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Historial de servicios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildViewSelector(),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildContent(),
              ),
            ),
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

class _LlamadaCard extends StatelessWidget {
  const _LlamadaCard({required this.llamada, required this.onTap});

  final LlamadaServicio llamada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tipo = llamada.serviceCallTypeName;
    final fecha = llamada.creationDate.split('T').first;

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
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          fecha.isEmpty ? '—' : fecha,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      llamada.subject.isEmpty ? 'Sin descripción' : llamada.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.dark),
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
        json['ServiceCalls'] is Map ? json['ServiceCalls'] as Map : const {};
    final serviceCallTypes = json['ServiceCallTypes'] is Map
        ? json['ServiceCallTypes'] as Map
        : const {};
    final id = serviceCalls['ServiceCallID'];

    return LlamadaServicio(
      serviceCallID: id is num ? id.toInt() : int.tryParse('${id ?? ''}') ?? 0,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Se adapta a pantallas pequeñas (antes era fijo de 300 px).
                final size = constraints.maxWidth.clamp(180.0, 300.0);
                return Center(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 0,
                        sectionsSpace: 3,
                        borderData: FlBorderData(show: false),
                        sections: _generatePieChartSections(counts, size / 2),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildIndicators(counts),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicators(Map<String, int> counts) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: counts.entries
          .map((e) => _buildIndicator(
                _colorForServiceType(e.key),
                '${e.key.isEmpty ? 'Sin tipo' : e.key} (${e.value})',
              ))
          .toList(),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13)),
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
        titlePositionPercentageOffset: 0.6,
        titleStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.dark,
        ),
      );
    }).toList();
  }
}
