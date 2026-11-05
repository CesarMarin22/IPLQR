import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/informacion_cargadores.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_cargadores.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class menuCargadores extends StatelessWidget {
  const menuCargadores({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Regresa al menú principal (eleccion) sin apilar una nueva copia de él.
  /// eleccion es la ruta raíz tras el login (pushReplacement).
  void _backToMain(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 76,
        title: Image.asset('assets/logo ipl_BLANCO.png', height: 58),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Text(
              'Cargadores',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecciona una opción',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            MenuTile(
              icon: Icons.info_outline,
              title: 'Información',
              subtitle: 'Marca, modelo, voltaje y amperaje',
              onTap: () => _open(context, const InformacionCargadores()),
            ),
            MenuTile(
              icon: Icons.history,
              title: 'Historial de servicios',
              subtitle: 'Órdenes de trabajo del cargador',
              onTap: () => _open(context, const LlamadaServiciosCargadores()),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _backToMain(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Regresar'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}
