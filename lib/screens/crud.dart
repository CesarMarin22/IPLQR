import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/admin_usuarios.dart';

class DetalleUsuarioScreen extends StatefulWidget {
  final dynamic user;
  final Function? onUsuarioActualizado;

  const DetalleUsuarioScreen(
      {Key? key, required this.user, this.onUsuarioActualizado})
      : super(key: key);

  @override
  _DetalleUsuarioScreenState createState() => _DetalleUsuarioScreenState();
}

class _DetalleUsuarioScreenState extends State<DetalleUsuarioScreen> {
  int? idusuario;
  TextEditingController usuarioController = TextEditingController();
  TextEditingController pwdController = TextEditingController();
  String? selectedPerfil;
  String? selectedSocio;
  int selectedActivo = 0; // Por defecto, activo es 0
  List<dynamic> perfiles = [];
  List<dynamic> socios = [];
  int? activoDB;

  bool isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    idusuario = widget.user['id_Usuario'];
    // Inicializar los controladores con los datos del usuario actual
    usuarioController.text = widget.user['usuario'];
    pwdController.text = widget.user['pwd'];
    activoDB = widget.user['activo'];

    // Obtener los perfiles disponibles
    obtenerPerfiles();

    // Obtener los socios disponibles
    obtenerSocios();

    // Verificar si los campos iniciales no están vacíos
    actualizarEstadoBoton();
  }

  void actualizarEstadoBoton() {
    setState(() {
      isButtonEnabled = usuarioController.text.isNotEmpty &&
          pwdController.text.isNotEmpty; // Verificar ambos campos
    });
  }

  Future<void> obtenerPerfiles() async {
    http.Response response =
        await http.get(Uri.parse('http://20.97.20.115:85/api/Perfiles'));
    if (response.statusCode == 200) {
      setState(() {
        perfiles = jsonDecode(response.body);
        selectedPerfil = widget.user['idPerfil'].toString();
      });
    }
  }

  Future<void> obtenerSocios() async {
    http.Response response =
        await http.get(Uri.parse('http://20.97.20.115:85/api/Socios'));
    if (response.statusCode == 200) {
      setState(() {
        socios = jsonDecode(response.body);
        selectedSocio = widget.user['idSocio'].toString();
      });
    }
  }

  Future<void> actualizarUsuario() async {
    // Obtener los datos actualizados del usuario
    int idUsuario = (idusuario!);
    String usuario = usuarioController.text;
    String pwd = pwdController.text;
    int idPerfil = int.parse(selectedPerfil!);
    int idSocio = int.parse(selectedSocio!);

    // Construir el cuerpo de la solicitud
    Map<String, dynamic> body = {
      'id_Usuario': idUsuario,
      'usuario': usuario,
      'pwd': pwd,
      'idPerfil': idPerfil,
      'idSocio': idSocio,
      'activo': selectedActivo,
    };

    // Realizar la solicitud PUT para actualizar el usuario
    http.Response response = await http.put(
      Uri.parse('http://20.97.20.115:85/api/Usuarios/${idUsuario}'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 204) {
      // Usuario actualizado correctamente
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Usuario actualizado')));
      if (widget.onUsuarioActualizado != null) {
        widget.onUsuarioActualizado!();
      }
      // Regresar a la pantalla anterior
      Navigator.pop(context);
    } else {
      // Error al actualizar el usuario
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el usuario')));
    }
  }

  Future<void> eliminarUsuario() async {
    // Realizar la solicitud DELETE para eliminar el usuario
    http.Response response = await http.delete(
      Uri.parse(
          'http://20.97.20.115:85/api/Usuarios/${widget.user['id_Usuario']}'),
    );

    if (response.statusCode == 204) {
      // Usuario eliminado correctamente
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Usuario eliminado')));
      if (widget.onUsuarioActualizado != null) {
        widget.onUsuarioActualizado!();
      }
      Navigator.pop(context); // Volver a la pantalla anterior
    } else {
      // Error al eliminar el usuario
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el usuario')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 243, 138, 0),
        toolbarHeight: 80,
        title: Center(
          child: Image.asset(
            'assets/logo ipl_BLANCO.png',
            width: 70,
            height: 70,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Column(
                  children: [
                    const Text(
                      'ELIMINAR Y MODIFICAR',
                      style: TextStyle(fontSize: 30),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                  ],
                ),
              ),
              TextField(
                controller: usuarioController,
                onChanged: (value) {
                  actualizarEstadoBoton();
                },
                onEditingComplete: () {
                  actualizarEstadoBoton();
                },
                decoration: InputDecoration(
                  labelText: 'Usuario',
                  labelStyle:
                      const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: pwdController,
                onChanged: (value) {
                  actualizarEstadoBoton();
                },
                onEditingComplete: () {
                  actualizarEstadoBoton();
                },
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle:
                      const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedPerfil,
                onChanged: (newValue) {
                  setState(() {
                    selectedPerfil = newValue;
                  });
                },
                items: perfiles.map<DropdownMenuItem<String>>((perfil) {
                  return DropdownMenuItem<String>(
                    value: perfil['id_Perfil'].toString(),
                    child: Text(perfil['perfil']),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Perfil',
                  labelStyle:
                      const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: selectedSocio,
                onChanged: (newValue) {
                  setState(() {
                    selectedSocio = newValue;
                  });
                },
                items: socios.map<DropdownMenuItem<String>>((socio) {
                  return DropdownMenuItem<String>(
                    value: socio['id_Socio'].toString(),
                    child: Text(socio['nombreSocio']),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Socio',
                  labelStyle:
                      const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('Activo:'),
                  Switch(
                    value: activoDB == 1,
                    activeColor: Color.fromARGB(255, 243, 138, 0),
                    onChanged: (value) {
                      setState(() {
                        selectedActivo = value ? 1 : 0;
                      });
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: isButtonEnabled ? actualizarUsuario : null,
                child: Text(
                  'Actualizar Usuario',
                  style: TextStyle(color: Colors.black),
                ),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    isButtonEnabled
                        ? Color.fromARGB(255, 243, 138, 0)
                        : Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: eliminarUsuario,
                child: Text(
                  'Eliminar Usuario',
                  style: TextStyle(color: Colors.black),
                ),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Color.fromARGB(255, 243, 138, 0),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
// Resetear el número de serie al hacer clic en "SCANEAR"
                  Provider.of<SerialNumberModel>(context, listen: false)
                      .setSerialNumber('');
                  // Navegar a la pantalla de escaneo (eleccion)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminUsuarios(),
                    ),
                  );
                },
                child: Text(
                  'REGRESAR',
                  style: TextStyle(color: Colors.black),
                ),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Colors.red,
                  ), // Color de fondo del botón
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomAppBar(
        color: Color.fromARGB(255, 29, 29, 27),
        shape: CircularNotchedRectangle(),
        child: SizedBox(
          height: 50,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Copyright ©2023, Todos los Derechos Reservados.',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
                Text(
                  'Powered by IPL',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
