import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_qr/screens/crud.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class crearUsuario extends StatefulWidget {
  final Function? onUsuarioAgregado;

  const crearUsuario({Key? key, this.onUsuarioAgregado}) : super(key: key);
  @override
  // ignore: library_private_types_in_public_api
  _crearUsuarioState createState() => _crearUsuarioState();
}

class _crearUsuarioState extends State<crearUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _pwdController = TextEditingController();

  String? selectedPerfil;
  String? selectedSocio;
  String? selectedSucursal;
  int selectedActivo = 1; // Por defecto, activo es 1 (activo)

  List<MapEntry<String, String>> perfiles = const [];
  List<MapEntry<String, String>> socios = const [];

  bool _cargandoCatalogos = true;
  String? _errorCatalogos;
  bool _guardando = false;
  bool _verPwd = false;

  /// Fuerza la reconstrucción de los dropdowns cuando llega el catálogo.
  int _formVersion = 0;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogos() async {
    setState(() {
      _cargandoCatalogos = true;
      _errorCatalogos = null;
    });
    try {
      final results = await Future.wait([obtenerPerfiles(), obtenerSocios()]);
      if (!mounted) return;
      setState(() {
        perfiles = results[0];
        socios = results[1];
        // Igual que antes: por defecto se elige el primer perfil / socio.
        selectedPerfil ??= perfiles.isNotEmpty ? perfiles.first.key : null;
        selectedSocio ??= socios.isNotEmpty ? socios.first.key : null;
        _cargandoCatalogos = false;
        _formVersion++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargandoCatalogos = false;
        _errorCatalogos = mensajeErrorUsuarios(e);
      });
    }
  }

  Future<List<MapEntry<String, String>>> obtenerPerfiles() async {
    final response = await http
        .get(Uri.parse('http://68.155.144.63:8081/api/perfiles'))
        .timeout(kUsuariosTimeout);
    if (response.statusCode != 200) {
      throw UsuariosApiException(
          'Error al cargar perfiles: ${response.statusCode}');
    }
    return opcionesCatalogo(decodificarListaJson(response), 'PERFIL');
  }

  Future<List<MapEntry<String, String>>> obtenerSocios() async {
    final response = await http
        .get(Uri.parse('http://68.155.144.63:8081/api/socios'))
        .timeout(kUsuariosTimeout);
    if (response.statusCode != 200) {
      throw UsuariosApiException(
          'Error al cargar socios: ${response.statusCode}');
    }
    return opcionesCatalogo(decodificarListaJson(response), 'SOCIO');
  }

  Future<void> agregarUsuario() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    // Construir el cuerpo de la solicitud
    final Map<String, dynamic> body = {
      'USUARIO': _usuarioController.text.trim(),
      'PWD': _pwdController.text,
      'PERFIL': selectedPerfil,
      'SOCIO': selectedSocio,
      'ACTIVO': selectedActivo,
      'SUCURSAL': selectedSucursal,
    };

    setState(() => _guardando = true);
    try {
      // Realizar la solicitud POST para agregar el usuario
      final response = await http
          .post(
            Uri.parse('http://68.155.144.63:8081/api/usuarios'),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(kUsuariosTimeout);

      if (response.statusCode == 200) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Usuario agregado')));
        final cb = widget.onUsuarioAgregado;
        if (cb != null) cb();
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      messenger.showSnackBar(SnackBar(
          content:
              Text('Error al agregar el usuario: ${response.statusCode}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Error al agregar el usuario. ${mensajeErrorUsuarios(e)}')));
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    final puedeGuardar = !_guardando && !_cargandoCatalogos;

    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          automaticallyImplyLeading: !_guardando,
          title: Image.asset('assets/logo ipl_BLANCO.png', height: 58),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const EncabezadoUsuarios(
                  titulo: 'Crear usuario',
                  subtitulo: 'Captura los datos del nuevo usuario',
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorCatalogos != null)
                            AvisoCatalogos(
                              mensaje: _errorCatalogos!,
                              onRetry: _cargarCatalogos,
                            ),
                          TextFormField(
                            controller: _usuarioController,
                            enabled: !_guardando,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Escribe el usuario'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _pwdController,
                            enabled: !_guardando,
                            obscureText: !_verPwd,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _verPwd
                                    ? 'Ocultar contraseña'
                                    : 'Mostrar contraseña',
                                icon: Icon(_verPwd
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _verPwd = !_verPwd),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Escribe la contraseña'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          CampoCatalogo(
                            label: 'Sucursal',
                            icon: Icons.store_mall_directory_outlined,
                            value: selectedSucursal,
                            opciones: opcionesSucursal,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => selectedSucursal = v),
                          ),
                          const SizedBox(height: 14),
                          CampoCatalogo(
                            key: ValueKey('perfil-$_formVersion'),
                            label: 'Perfil',
                            icon: Icons.badge_outlined,
                            value: selectedPerfil,
                            opciones: perfiles,
                            cargando: _cargandoCatalogos,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => selectedPerfil = v),
                          ),
                          const SizedBox(height: 14),
                          CampoCatalogo(
                            key: ValueKey('socio-$_formVersion'),
                            label: 'Socio',
                            icon: Icons.business_outlined,
                            value: selectedSocio,
                            opciones: socios,
                            cargando: _cargandoCatalogos,
                            onChanged: _guardando
                                ? null
                                : (v) => setState(() => selectedSocio = v),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Activo'),
                            subtitle: Text(selectedActivo == 1
                                ? 'El usuario podrá iniciar sesión'
                                : 'El usuario se creará desactivado'),
                            value: selectedActivo == 1,
                            onChanged: _guardando
                                ? null
                                : (value) => setState(
                                    () => selectedActivo = value ? 1 : 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: puedeGuardar ? agregarUsuario : null,
                  icon: _guardando
                      ? const BotonSpinner()
                      : const Icon(Icons.person_add_alt_1_outlined),
                  label:
                      Text(_guardando ? 'Guardando...' : 'Agregar usuario'),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed:
                      _guardando ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Regresar'),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const AppFooter(),
      ),
    );
  }
}
