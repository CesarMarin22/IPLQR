import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_qr/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Utilidades compartidas por las pantallas de administración de usuarios
// (admin_usuarios.dart, CrearUsuario.dart y este archivo).
// ---------------------------------------------------------------------------

/// Tiempo máximo de espera para las peticiones de usuarios.
const Duration kUsuariosTimeout = Duration(seconds: 25);

/// Sucursales disponibles: 'codigo' es lo que se envía, 'nombre' lo que se ve.
const List<Map<String, String>> sucursalesUsuario = [
  {'nombre': 'AGS', 'codigo': '87'},
  {'nombre': 'CLY', 'codigo': '82'},
  {'nombre': 'GDL', 'codigo': '88'},
  {'nombre': 'IRA', 'codigo': '89'},
  {'nombre': 'MEX', 'codigo': '83'},
  {'nombre': 'MTY', 'codigo': '85'},
  {'nombre': 'QRO', 'codigo': '86'},
  {'nombre': 'SLP', 'codigo': '90'},
  {'nombre': 'TOL', 'codigo': '84'},
  {'nombre': 'PUE', 'codigo': '374'},
];

/// Opciones de sucursal listas para un dropdown (codigo -> nombre).
final List<MapEntry<String, String>> opcionesSucursal = sucursalesUsuario
    .map((s) => MapEntry(s['codigo']!, s['nombre']!))
    .toList(growable: false);

/// Error con un mensaje ya pensado para mostrarse al usuario.
class UsuariosApiException implements Exception {
  const UsuariosApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Decodifica una respuesta que debe ser una lista JSON (en UTF-8 para
/// respetar acentos y ñ).
List<dynamic> decodificarListaJson(http.Response response) {
  final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
  if (data is List) return data;
  throw const FormatException('Respuesta inesperada del servidor');
}

/// Convierte cualquier error de red / parseo en un texto amigable.
String mensajeErrorUsuarios(Object error) {
  if (error is UsuariosApiException) return error.message;
  if (error is TimeoutException) {
    return 'El servidor tardó demasiado en responder. Intenta de nuevo.';
  }
  if (error is http.ClientException) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión.';
  }
  if (error is FormatException) {
    return 'El servidor envió una respuesta no válida.';
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}

/// Normaliza el campo ACTIVO (int, bool o texto) a 1 / 0.
int valorActivo(dynamic value) {
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value.toInt();
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true') return 1;
  return int.tryParse(text) ?? 0;
}

/// Construye opciones (ID -> etiqueta) para un dropdown a partir de un
/// catálogo JSON, ignorando registros inválidos e IDs repetidos (un valor
/// repetido haría fallar al DropdownButton).
List<MapEntry<String, String>> opcionesCatalogo(
  List<dynamic> data,
  String labelKey,
) {
  final vistos = <String>{};
  final opciones = <MapEntry<String, String>>[];
  for (final item in data) {
    if (item is! Map) continue;
    final id = item['ID'];
    if (id == null) continue;
    final idText = id.toString();
    if (!vistos.add(idText)) continue;
    opciones.add(MapEntry(idText, '${item[labelKey] ?? idText}'));
  }
  return opciones;
}

/// Devuelve el ID de [opciones] que corresponde a [value] o null si no hay.
/// Tolera diferencias de formato ("1", 1, "0x01").
String? idCoincidente(dynamic value, List<MapEntry<String, String>> opciones) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  for (final o in opciones) {
    if (o.key == text) return o.key;
  }
  final n1 = int.tryParse(text);
  final n2 = int.tryParse(text.replaceAll('0x', ''));
  for (final o in opciones) {
    final idNum = int.tryParse(o.key);
    if (idNum != null && (idNum == n1 || idNum == n2)) return o.key;
  }
  return null;
}

/// Dropdown de catálogo con estilo del tema y validación de obligatorio.
class CampoCatalogo extends StatelessWidget {
  const CampoCatalogo({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.opciones,
    required this.onChanged,
    this.cargando = false,
  });

  final String label;
  final IconData icon;
  final String? value;
  final List<MapEntry<String, String>> opciones;
  final ValueChanged<String?>? onChanged;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      onChanged: cargando ? null : onChanged,
      validator: (v) => v == null ? 'Selecciona ${label.toLowerCase()}' : null,
      items: opciones
          .map(
            (o) => DropdownMenuItem<String>(
              value: o.key,
              child: Text(o.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: cargando
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
    );
  }
}

/// Aviso de error al cargar perfiles/socios con botón de reintento.
class AvisoCatalogos extends StatelessWidget {
  const AvisoCatalogos({super.key, required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudieron cargar perfiles/socios. $mensaje',
              style: const TextStyle(fontSize: 13, color: AppColors.dark),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// Encabezado de sección de las pantallas de usuarios.
class EncabezadoUsuarios extends StatelessWidget {
  const EncabezadoUsuarios({super.key, required this.titulo, this.subtitulo});

  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitulo!,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ],
    );
  }
}

/// Spinner pequeño para botones mientras se guarda.
class BotonSpinner extends StatelessWidget {
  const BotonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla: modificar / eliminar usuario
// ---------------------------------------------------------------------------

enum _Accion { actualizando, eliminando }

class DetalleUsuarioScreen extends StatefulWidget {
  final dynamic user;
  final Function? onUsuarioActualizado;

  const DetalleUsuarioScreen(
      {Key? key, required this.user, this.onUsuarioActualizado})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DetalleUsuarioScreenState createState() => _DetalleUsuarioScreenState();
}

class _DetalleUsuarioScreenState extends State<DetalleUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController pwdController = TextEditingController();

  int? idusuario;
  String? selectedPerfil;
  String? selectedSocio;
  int selectedActivo = 0;
  String? selectedSucursal;

  // Valores originales del usuario (se emparejan cuando llega el catálogo).
  dynamic _perfilOriginal;
  dynamic _socioOriginal;

  List<MapEntry<String, String>> perfiles = const [];
  List<MapEntry<String, String>> socios = const [];

  bool _cargandoCatalogos = true;
  String? _errorCatalogos;
  _Accion? _accion;
  bool _verPwd = false;

  /// Se incrementa cuando cambian los valores iniciales de los dropdowns
  /// para que se reconstruyan con el nuevo valor.
  int _formVersion = 0;

  bool get _ocupado => _accion != null;

  Map get _user => widget.user is Map ? widget.user as Map : const {};

  @override
  void initState() {
    super.initState();
    _cargarDesdeUsuario();
    _cargarCatalogos();
  }

  @override
  void didUpdateWidget(DetalleUsuarioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _cargarDesdeUsuario();
      _emparejarCatalogos();
      _formVersion++;
    }
  }

  @override
  void dispose() {
    usuarioController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  void _cargarDesdeUsuario() {
    final u = _user;
    final id = u['ID'];
    idusuario = id is int ? id : int.tryParse('${id ?? ''}');
    usuarioController.text = '${u['USUARIO'] ?? ''}';
    pwdController.text = '${u['PWD'] ?? ''}';
    selectedActivo = valorActivo(u['ACTIVO']);
    selectedSucursal = idCoincidente(u['SUCURSAL'], opcionesSucursal);
    _perfilOriginal = u['PERFIL'];
    _socioOriginal = u['SOCIO'];
  }

  void _emparejarCatalogos() {
    selectedPerfil = idCoincidente(_perfilOriginal, perfiles);
    selectedSocio = idCoincidente(_socioOriginal, socios);
  }

  Future<void> _cargarCatalogos() async {
    setState(() {
      _cargandoCatalogos = true;
      _errorCatalogos = null;
    });
    try {
      final results = await Future.wait([
        obtenerPerfiles(),
        obtenerSocios(),
      ]);
      if (!mounted) return;
      setState(() {
        perfiles = results[0];
        socios = results[1];
        _emparejarCatalogos();
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

  void _notificarCambio() {
    final cb = widget.onUsuarioActualizado;
    if (cb != null) cb();
  }

  Future<void> actualizarUsuario() async {
    if (_ocupado) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    final idUsuario = idusuario;
    if (idUsuario == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se puede actualizar: el usuario no tiene ID')));
      return;
    }
    final idPerfil = int.tryParse(selectedPerfil ?? '');
    final idSocio = int.tryParse(selectedSocio ?? '');
    if (idPerfil == null || idSocio == null || selectedSucursal == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Revisa perfil, socio y sucursal')));
      return;
    }
    FocusScope.of(context).unfocus();

    final Map<String, dynamic> body = {
      'ID': idUsuario,
      'USUARIO': usuarioController.text,
      'PWD': pwdController.text,
      'PERFIL': idPerfil,
      'SOCIO': idSocio,
      'ACTIVO': selectedActivo,
      'SUCURSAL': selectedSucursal!,
    };

    setState(() => _accion = _Accion.actualizando);
    try {
      final response = await http
          .put(
            Uri.parse('http://68.155.144.63:8081/api/usuarios/$idUsuario'),
            body: jsonEncode(body),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(kUsuariosTimeout);

      if (response.statusCode == 200) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Usuario actualizado')));
        _notificarCambio();
        // Regresamos a la lista existente en lugar de apilar otra nueva.
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      messenger.showSnackBar(SnackBar(
          content:
              Text('Error al actualizar el usuario: ${response.statusCode}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Error al actualizar el usuario. ${mensajeErrorUsuarios(e)}')));
    }
    if (mounted) setState(() => _accion = null);
  }

  Future<bool> _confirmarEliminar() async {
    final nombre = usuarioController.text.trim();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppColors.danger, size: 40),
        title: const Text('Eliminar usuario'),
        content: Text(
          nombre.isEmpty
              ? '¿Seguro que deseas eliminar este usuario? Esta acción no se puede deshacer.'
              : '¿Seguro que deseas eliminar a "$nombre"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Future<void> eliminarUsuario() async {
    if (_ocupado) return;
    if (!await _confirmarEliminar() || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _accion = _Accion.eliminando);
    try {
      final response = await http
          .delete(
            Uri.parse(
                'http://68.155.144.63:8081/api/usuarios/${_user['ID']}'),
          )
          .timeout(kUsuariosTimeout);

      if (response.statusCode == 200) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
        _notificarCambio();
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      messenger.showSnackBar(SnackBar(
          content:
              Text('Error al eliminar el usuario: ${response.statusCode}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Error al eliminar el usuario. ${mensajeErrorUsuarios(e)}')));
    }
    if (mounted) setState(() => _accion = null);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${_user['USUARIO'] ?? ''}';
    final puedeGuardar = !_ocupado && !_cargandoCatalogos;

    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          automaticallyImplyLeading: !_ocupado,
          title: Image.asset('assets/logo ipl_BLANCO.png', height: 58),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EncabezadoUsuarios(
                  titulo: 'Modificar o eliminar',
                  subtitulo: nombre.isEmpty ? null : 'Usuario: $nombre',
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
                            controller: usuarioController,
                            enabled: !_ocupado,
                            textInputAction: TextInputAction.next,
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
                            controller: pwdController,
                            enabled: !_ocupado,
                            obscureText: !_verPwd,
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
                            key: ValueKey('sucursal-$_formVersion'),
                            label: 'Sucursal',
                            icon: Icons.store_mall_directory_outlined,
                            value: selectedSucursal,
                            opciones: opcionesSucursal,
                            onChanged: _ocupado
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
                            onChanged: _ocupado
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
                            onChanged: _ocupado
                                ? null
                                : (v) => setState(() => selectedSocio = v),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Activo'),
                            subtitle: Text(selectedActivo == 1
                                ? 'El usuario puede iniciar sesión'
                                : 'El usuario está desactivado'),
                            value: selectedActivo == 1,
                            onChanged: _ocupado
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
                  onPressed: puedeGuardar ? actualizarUsuario : null,
                  icon: _accion == _Accion.actualizando
                      ? const BotonSpinner()
                      : const Icon(Icons.save_outlined),
                  label: Text(_accion == _Accion.actualizando
                      ? 'Actualizando...'
                      : 'Actualizar usuario'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : eliminarUsuario,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                  ),
                  icon: _accion == _Accion.eliminando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.danger),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(_accion == _Accion.eliminando
                      ? 'Eliminando...'
                      : 'Eliminar usuario'),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed:
                      _ocupado ? null : () => Navigator.of(context).pop(),
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
