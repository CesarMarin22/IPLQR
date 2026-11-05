import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/informacion_baterias.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_baterias.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class menuBaterias extends StatelessWidget {
  const menuBaterias({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // SerialNumberModel no notifica cambios; basta con leerlo una vez.
    final numSerie = context.read<SerialNumberModel>().serialNumber;

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
              'Baterías',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            if (numSerie.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Serie: $numSerie',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 20),
            MenuTile(
              icon: Icons.battery_charging_full,
              title: 'Información',
              subtitle: 'Datos de la batería',
              onTap: () => _open(context, const InformacionBaterias()),
            ),
            MenuTile(
              icon: Icons.history,
              title: 'Historial de servicios',
              subtitle: 'Llamadas de servicio de la batería',
              onTap: () => _open(context, const LlamadaServiciosBaterias()),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              // Vuelve al menú principal limpiando la pila (antes se apilaba
              // una nueva pantalla de elección cada vez).
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const eleccion()),
                (r) => false,
              ),
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
