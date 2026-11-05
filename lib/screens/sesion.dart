import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/theme/app_theme.dart';
import 'package:rive/rive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  late final FileLoader _riveLoader = FileLoader.fromAsset(
    'assets/cargando_imagen.riv',
    riveFactory: Factory.rive,
  );

  bool _showPassword = false;
  bool _isLoading = false;

  bool get _canSubmit =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_isLoading;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    _riveLoader.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      try {
        await authProvider.login(username, password);
      } on PasswordTemporalException {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final cambiada = await _pedirCambioPassword(password);
        if (!cambiada || !mounted) {
          await authProvider.logout();
          return;
        }
        setState(() => _isLoading = true);
        await authProvider.cargarPermisos();
      }
      if (!mounted) return;
      // Única navegación tras el login (antes se hacía dos veces y
      // provocaba el error "_dependents.isEmpty").
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const eleccion()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String mensaje = 'Usuario y/o contraseña incorrectos.';
      if (e is AppException) {
        mensaje = e.message;
      }

      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.error_outline,
              color: AppColors.danger, size: 40),
          title: const Text('No se pudo iniciar sesión'),
          content: Text(mensaje, textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// La Intranet dio una contraseña temporal: hay que cambiarla antes de entrar.
  /// Devuelve true si se cambió.
  Future<bool> _pedirCambioPassword(String actual) async {
    final authProvider = context.read<AuthProvider>();
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    String? error;
    bool guardando = false;

    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> guardar() async {
            final nueva = nuevaCtrl.text;
            if (nueva.isEmpty || nueva != confirmarCtrl.text) {
              setDialogState(() => error = 'Las contraseñas no coinciden.');
              return;
            }
            setDialogState(() {
              guardando = true;
              error = null;
            });
            String? fallo;
            try {
              fallo = await authProvider.cambiarPassword(actual, nueva);
            } catch (e) {
              fallo = e is AppException ? e.message : 'No se pudo cambiar la contraseña.';
            }
            if (!dialogContext.mounted) return;
            if (fallo == null) {
              Navigator.of(dialogContext).pop(true);
            } else {
              setDialogState(() {
                guardando = false;
                error = fallo;
              });
            }
          }

          return AlertDialog(
            title: const Text('Cambia tu contraseña'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tienes una contraseña temporal. Escribe una nueva; es la '
                    'misma que usarás en la Intranet.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nuevaCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Contraseña nueva'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmarCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: guardando
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: guardando ? null : guardar,
                child: Text(guardando ? 'Guardando...' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );

    nuevaCtrl.dispose();
    confirmarCtrl.dispose();
    return resultado == true;
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'AVISO DE PRIVACIDAD INTEGRAL',
          style: TextStyle(color: AppColors.orangeDark, fontSize: 18),
        ),
        content: const SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              'Con fundamento en la Ley Federal de Protección de Datos '
              'Personales en Posesión de los Particulares...',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.75).clamp(240.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: size.height * 0.38,
              child: RiveWidgetBuilder(
                fileLoader: _riveLoader,
                builder: (context, state) => switch (state) {
                  RiveLoading() =>
                    const Center(child: CircularProgressIndicator()),
                  RiveFailed() =>
                    const Center(child: CircularProgressIndicator()),
                  RiveLoaded() => Transform.scale(
                      scale: 1.6,
                      child: RiveWidget(
                        controller: state.controller,
                        fit: Fit.contain,
                      ),
                    ),
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Iniciando sesión...',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/logo_ipl_negro.png',
                    height: 150,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inicia sesión para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _attemptLogin(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setState(
                                    () => _showPassword = !_showPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          ElevatedButton.icon(
                            onPressed: _canSubmit ? _attemptLogin : null,
                            icon: const Icon(Icons.login),
                            label: const Text('Iniciar sesión'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _showPrivacy,
                    child: const Text(
                      'Aviso de Privacidad',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
