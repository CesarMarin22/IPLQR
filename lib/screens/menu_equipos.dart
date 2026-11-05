import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/informacion_equipos.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_equipos.dart';
import 'package:proyecto_qr/screens/reporte_instalacion.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class menuEquipos extends StatefulWidget {
  const menuEquipos({super.key});

  @override
  State<menuEquipos> createState() => _MenuEquiposState();
}

class _MenuEquiposState extends State<menuEquipos> {
  String _serie = '';

  @override
  void initState() {
    super.initState();
    // Se lee una sola vez (antes se leía AuthProvider con listen:true en build).
    _serie = context.read<SerialNumberModel>().serialNumber;
  }

  void _open(Widget page) {
    context.read<AuthProvider>().resetSession();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _escanearOtro() {
    context.read<SerialNumberModel>().setSerialNumber('');
    // Volvemos al menú principal limpiando la pila (antes se apilaba un
    // nuevo menú encima de las pantallas anteriores en cada escaneo).
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const eleccion()),
      (route) => false,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Text(
              'Equipos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            if (_serie.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Serie: $_serie',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            MenuTile(
              icon: Icons.info_outline,
              title: 'Información',
              subtitle: 'Datos técnicos del equipo',
              onTap: () => _open(const HomePage()),
            ),
            MenuTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Reporte de instalación',
              subtitle: 'Documento PDF del equipo',
              onTap: () => _open(const FileViewerFromAPI()),
            ),
            MenuTile(
              icon: Icons.history,
              title: 'Historial de servicios',
              subtitle: 'Órdenes de trabajo del equipo',
              onTap: () => _open(const LlamadaServiciosEquipos()),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _escanearOtro,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear otro artículo'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PdfViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de PDF'),
      ),
      body: SafeArea(
        child: PDFView(
          filePath: pdfPath,
        ),
      ),
    );
  }
}
