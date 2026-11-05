import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:proyecto_qr/utils/popup_reportes.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class ReporteResultadosScreen extends StatefulWidget {
  final List<dynamic> resultados;
  final String clienteNombre;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String sucursal;

  const ReporteResultadosScreen({
    super.key,
    required this.resultados,
    required this.clienteNombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.sucursal,
  });

  @override
  State<ReporteResultadosScreen> createState() =>
      _ReporteResultadosScreenState();
}

class _ReporteResultadosScreenState extends State<ReporteResultadosScreen> {
  bool mostrarBarChart = true;
  late Map<String, Map<String, int>> groupedData;
  final Map<String, Color> tipoColores = {};
  final List<Color> coloresPredefinidos = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
    Colors.pink,
  ];

  // Calculados una sola vez (antes se recalculaban en cada build).
  late final List<String> _meses;
  late final List<String> _tipos;
  late final String _rangoFechas;

  @override
  void initState() {
    super.initState();
    groupedData = _agruparPorMesYTipo(widget.resultados);
    _asignarColoresPorTipo();
    _meses = _obtenerMesesOrdenados();
    _tipos = _obtenerTiposServicio();
    _rangoFechas = _formatearFechaRango(widget.fechaInicio, widget.fechaFin);
  }

  Map<String, Map<String, int>> _agruparPorMesYTipo(List<dynamic> data) {
    final Map<String, Map<String, int>> resultado = {};

    for (var item in data) {
      try {
        final DateTime fecha =
            DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
                .parse(item['createDate']);

        final String mes = DateFormat('yyyy-MM').format(fecha);
        final String tipo = item['Name']?.toString() ?? 'Desconocido';

        resultado[mes] ??= {};
        resultado[mes]![tipo] = (resultado[mes]![tipo] ?? 0) + 1;
      } catch (_) {
        // Ignora registros con fecha inválida para no romper la pantalla
      }
    }

    return resultado;
  }

  void _asignarColoresPorTipo() {
    final tipos = _obtenerTiposServicio();
    for (int i = 0; i < tipos.length; i++) {
      tipoColores[tipos[i]] =
          coloresPredefinidos[i % coloresPredefinidos.length];
    }
  }

  List<String> _obtenerMesesOrdenados() {
    final meses = groupedData.keys.toList();
    meses.sort();
    return meses;
  }

  List<String> _obtenerTiposServicio() {
    final Set<String> tipos = {};
    for (var mapa in groupedData.values) {
      tipos.addAll(mapa.keys);
    }
    return tipos.toList();
  }

  String _formatearFechaRango(DateTime inicio, DateTime fin) {
    final formato = DateFormat("dd 'de' MMMM 'de' yyyy", 'es_MX');
    return "Del ${formato.format(inicio)} al ${formato.format(fin)}";
  }

  String get _sucursalTexto =>
      widget.sucursal == "*" ? "Todas las sucursales (*)" : widget.sucursal;

  void _volverAlMenu() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const eleccion()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú',
          onPressed: _volverAlMenu,
        ),
        title: const Text('Resultados del Reporte'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune),
            tooltip: 'Opciones de reporte',
            onSelected: (value) {
              mostrarPopupReportes(
                context,
                clienteInicial: widget.clienteNombre,
                fechaInicioInicial: widget.fechaInicio,
                fechaFinInicial: widget.fechaFin,
                sucursalInicial: widget.sucursal,
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 1, child: Text("Cambiar cliente")),
              PopupMenuItem(value: 2, child: Text("Cambiar fechas")),
              PopupMenuItem(value: 3, child: Text("Cambiar sucursal")),
              PopupMenuItem(value: 4, child: Text("Cambiar todo")),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _buildResumen(),
            const SizedBox(height: 8),
            if (groupedData.isEmpty)
              const Card(
                child: EmptyState(
                  icon: Icons.insert_chart_outlined,
                  message: 'No se encontraron datos para mostrar',
                ),
              )
            else
              _buildGrafica(),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }

  Widget _buildResumen() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            InfoRow(label: 'Cliente', value: widget.clienteNombre),
            InfoRow(label: 'Sucursal', value: _sucursalTexto),
            InfoRow(label: 'Periodo', value: _rangoFechas),
            InfoRow(
              label: 'Registros',
              value: widget.resultados.length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafica() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Barras'),
                    icon: Icon(Icons.bar_chart),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Líneas'),
                    icon: Icon(Icons.show_chart),
                  ),
                ],
                selected: {mostrarBarChart},
                onSelectionChanged: (s) =>
                    setState(() => mostrarBarChart = s.first),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final e in tipoColores.entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: e.value,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 320,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartWidth = _meses.length * _tipos.length * 25.0;
                  final screenWidth = constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth > screenWidth ? chartWidth : screenWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8),
                        child: mostrarBarChart
                            ? _buildBarChart(_meses, _tipos)
                            : _buildLineChart(_meses, _tipos),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<String> meses, List<String> tipos) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                return idx < meses.length
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          meses[idx].substring(5),
                          style: const TextStyle(fontSize: 10),
                        ),
                      )
                    : const SizedBox();
              },
            ),
          ),
        ),
        barGroups: meses.asMap().entries.map((entry) {
          final idx = entry.key;
          final mes = entry.value;
          final data = groupedData[mes]!;

          return BarChartGroupData(
            x: idx,
            barsSpace: 4,
            barRods: tipos.map((tipo) {
              return BarChartRodData(
                toY: (data[tipo] ?? 0).toDouble(),
                width: 15,
                color: tipoColores[tipo],
                borderRadius: BorderRadius.circular(2),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<String> meses, List<String> tipos) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                return idx < meses.length
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          meses[idx].substring(5),
                          style: const TextStyle(fontSize: 10),
                        ),
                      )
                    : const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
        ),
        lineBarsData: tipos.map((tipo) {
          return LineChartBarData(
            isCurved: true,
            color: tipoColores[tipo],
            barWidth: 2,
            dotData: const FlDotData(show: true),
            spots: meses.asMap().entries.map((entry) {
              final idx = entry.key;
              final mes = entry.value;
              final y = groupedData[mes]?[tipo] ?? 0;
              return FlSpot(idx.toDouble(), y.toDouble());
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
