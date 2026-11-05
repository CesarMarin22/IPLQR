import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:proyecto_qr/screens/CrearUsuario.dart';
import 'package:proyecto_qr/screens/crud.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class AdminUsuarios extends StatefulWidget {
  const AdminUsuarios({Key? key}) : super(key: key);

  @override
  State<AdminUsuarios> createState() => _AdminUsuariosState();
}

class _AdminUsuariosState extends State<AdminUsuarios> {
  final _busquedaController = TextEditingController();
  late Future<List<Map>> _usuariosFuture;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    // La petición se hace una sola vez aquí (antes se repetía en cada build).
    _usuariosFuture = fetchUsers();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<List<Map>> fetchUsers() async {
    final response = await http
        .get(Uri.parse('http://68.155.144.63:8081/api/usuarios'))
        .timeout(kUsuariosTimeout);
    if (response.statusCode == 200) {
      return decodificarListaJson(response).whereType<Map>().toList();
    }
    throw UsuariosApiException(
        'No se pudieron cargar los usuarios (código ${response.statusCode}).');
  }

  /// Vuelve a pedir la lista. Sirve para el "jalar para actualizar" y tras
  /// crear / editar / eliminar.
  Future<void> _recargar() async {
    if (!mounted) return;
    final future = fetchUsers();
    setState(() => _usuariosFuture = future);
    try {
      await future;
    } catch (_) {
      // El error lo muestra el FutureBuilder.
    }
  }

  Future<void> _abrirCrear() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => crearUsuario(onUsuarioAgregado: _recargar),
      ),
    );
  }

  Future<void> _abrirDetalle(Map user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleUsuarioScreen(
          user: user,
          onUsuarioActualizado: _recargar,
        ),
      ),
    );
  }

  List<Map> _filtrar(List<Map> users) {
    final q = _filtro.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users
        .where((u) => '${u['USUARIO'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  /// Lista desplazable siempre, para que el RefreshIndicator funcione
  /// también en estados vacíos o de error.
  Widget _scrollableMessage(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 32),
        child,
      ],
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
        child: FutureBuilder<List<Map>>(
          future: _usuariosFuture,
          builder: (context, snapshot) {
            final users = snapshot.data;
            final cargando =
                snapshot.connectionState == ConnectionState.waiting;

            Widget contenido;
            if (users == null && cargando) {
              contenido = const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError && !cargando) {
              contenido = _scrollableMessage(
                EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: mensajeErrorUsuarios(snapshot.error!),
                  onRetry: _recargar,
                ),
              );
            } else {
              final filtrados = _filtrar(users ?? const []);
              if (filtrados.isEmpty) {
                contenido = _scrollableMessage(
                  EmptyState(
                    icon: Icons.person_search_outlined,
                    message: _filtro.trim().isEmpty
                        ? 'No hay usuarios registrados'
                        : 'Ningún usuario coincide con "${_filtro.trim()}"',
                  ),
                );
              } else {
                contenido = ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Espacio inferior para que el FAB no tape el último.
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final user = filtrados[index];
                    return _UsuarioCard(
                      user: user,
                      onTap: () => _abrirDetalle(user),
                    );
                  },
                );
              }
            }

            final total = users?.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: EncabezadoUsuarios(
                    titulo: 'Usuarios',
                    subtitulo: total == null
                        ? 'Administra altas, bajas y permisos'
                        : '$total usuario${total == 1 ? '' : 's'} registrado${total == 1 ? '' : 's'}',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _busquedaController,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _filtro = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _filtro.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() => _filtro = '');
                              },
                            ),
                    ),
                  ),
                ),
                if (cargando && users != null)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _recargar,
                    child: contenido,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCrear,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBar: const AppFooter(),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({required this.user, required this.onTap});

  final Map user;
  final VoidCallback onTap;

  static String? _nombreSucursal(dynamic codigo) {
    final id = idCoincidente(codigo, opcionesSucursal);
    if (id == null) return null;
    return opcionesSucursal.firstWhere((o) => o.key == id).value;
  }

  @override
  Widget build(BuildContext context) {
    final nombre = '${user['USUARIO'] ?? ''}'.trim();
    final perfil =
        int.tryParse('${user['PERFIL']}'.replaceAll('0x', '')) ?? 0;
    final activo = valorActivo(user['ACTIVO']) == 1;
    final sucursal = _nombreSucursal(user['SUCURSAL']);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: activo ? AppColors.orange : Colors.black12,
          foregroundColor: AppColors.dark,
          child: Text(
            nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          nombre.isEmpty ? '(sin nombre)' : nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Perfil: $perfil'),
              if (sucursal != null) Text('· $sucursal'),
              _EstadoChip(activo: activo),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
