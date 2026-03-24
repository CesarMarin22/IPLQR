import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:proyecto_qr/utils/popup_reportes.dart';
import 'package:proyecto_qr/screens/escoger.dart';

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

  @override
  void initState() {
    super.initState();
    groupedData = _agruparPorMesYTipo(widget.resultados);
    _asignarColoresPorTipo();
  }

  Map<String, Map<String, int>> _agruparPorMesYTipo(List<dynamic> data) {
    final Map<String, Map<String, int>> resultado = {};

    for (var item in data) {
      try {
        final DateTime fecha =
            DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
                .parse(item['createDate']);

        final String mes = DateFormat('yyyy-MM').format(fecha);
        final String tipo = item['Name'] ?? 'Desconocido';

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

  @override
  Widget build(BuildContext context) {
    final meses = _obtenerMesesOrdenados();
    final tipos = _obtenerTiposServicio();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const eleccion()),
              (route) => false,
            );
          },
        ),
        title: const Text('Resultados del Reporte'),
        backgroundColor: const Color.fromARGB(255, 243, 138, 0),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.refresh),
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
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: Text("Cambiar cliente")),
              const PopupMenuItem(value: 2, child: Text("Cambiar fechas")),
              const PopupMenuItem(value: 3, child: Text("Cambiar sucursal")),
              const PopupMenuItem(value: 4, child: Text("Cambiar todo")),
            ],
          ),
        ],
      ),
      body: groupedData.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.insert_chart_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontraron datos para mostrar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliente: ${widget.clienteNombre}\n'
                      'Sucursal: ${widget.sucursal}\n'
                      '${_formatearFechaRango(widget.fechaInicio, widget.fechaFin)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = meses.length * tipos.length * 25.0;
                final screenWidth = constraints.maxWidth;

                return Column(
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Cliente: ${widget.clienteNombre}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sucursal: ${widget.sucursal == "*" ? "Todas las sucursales (*)" : widget.sucursal}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatearFechaRango(
                              widget.fechaInicio,
                              widget.fechaFin,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Barras'),
                        Switch(
                          value: mostrarBarChart,
                          onChanged: (value) =>
                              setState(() => mostrarBarChart = value),
                        ),
                        const Text('Líneas'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: tipoColores.entries.map((e) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 12, height: 12, color: e.value),
                            const SizedBox(width: 4),
                            Text(
                              e.key,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth > screenWidth
                              ? chartWidth
                              : screenWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: mostrarBarChart
                                ? _buildBarChart(meses, tipos)
                                : _buildLineChart(meses, tipos),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
