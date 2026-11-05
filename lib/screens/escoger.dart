import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/lector_qr.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/theme/app_theme.dart';
import 'package:proyecto_qr/utils/popup_reportes.dart';
import 'lector_manual.dart';

class eleccion extends StatefulWidget {
  const eleccion({Key? key}) : super(key: key);

  @override
  State<eleccion> createState() => _eleccion();
}

class _eleccion extends State<eleccion> {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Limpiar el número de serie al entrar al menú (antes se hacía en build).
    context.read<SerialNumberModel>().setSerialNumber('');
  }

  void _open(Widget page) {
    context.read<AuthProvider>().resetSession();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _closing = true);
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final cerradoEnSap = await authProvider.logout();

    // Primero navegamos y después avisamos con un SnackBar global; así no
    // queda un diálogo encima de una pantalla que se está destruyendo.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(cerradoEnSap
            ? 'Sesión cerrada correctamente'
            : 'Sesión cerrada (sin respuesta del servidor)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reportes por cliente: solo con el permiso APP_MONTACARGAS_REPORTES de la Intranet
    final puedeReportes = context.select<AuthProvider, bool>(
      (p) => p.puedeReportes,
    );

    return PopScope(
      // Evita salir del menú con "atrás" por accidente.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLogout();
      },
      child: Scaffold(
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
                '¿Qué deseas hacer?',
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
                icon: Icons.qr_code_scanner,
                title: 'Leer QR',
                subtitle: 'Escanea la etiqueta del artículo',
                onTap: () => _open(const QRScannerPage()),
              ),
              MenuTile(
                icon: Icons.keyboard_alt_outlined,
                title: 'Ingresar artículo manualmente',
                subtitle: 'Escribe el número de serie',
                onTap: () => _open(const InputPage()),
              ),
              if (puedeReportes)
                MenuTile(
                icon: Icons.bar_chart_rounded,
                title: 'Reportes',
                subtitle: 'Consulta reportes por cliente',
                onTap: () {
                  context.read<AuthProvider>().resetSession();
                  mostrarPopupReportes(context);
                },
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _closing ? null : _confirmLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                ),
                icon: _closing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label: Text(_closing ? 'Cerrando sesión...' : 'Cerrar sesión'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppFooter(),
      ),
    );
  }
}
