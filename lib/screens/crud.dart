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
  int? selectedActivo;
  List<dynamic> perfiles = [];
  List<dynamic> socios = [];

  bool isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    idusuario = widget.user['ID'];
    usuarioController.text = widget.user['USUARIO'];
    pwdController.text = widget.user['PWD'];
    selectedActivo = widget.user['ACTIVO'];
    selectedPerfil = widget.user['PERFIL'].toString();
    selectedSocio = widget.user['SOCIO'].toString();

    obtenerPerfiles();
    obtenerSocios();
    actualizarEstadoBoton();
  }

  @override
  void didUpdateWidget(DetalleUsuarioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      setState(() {
        idusuario = widget.user['ID'];
        usuarioController.text = widget.user['USUARIO'];
        pwdController.text = widget.user['PWD'];
        selectedActivo = widget.user['ACTIVO'];
        selectedPerfil = widget.user['PERFIL'].toString();
        selectedSocio = widget.user['SOCIO'].toString();

        obtenerPerfiles();
        obtenerSocios();
        actualizarEstadoBoton();
      });
    }
  }

  void actualizarEstadoBoton() {
    setState(() {
      isButtonEnabled =
          usuarioController.text.isNotEmpty && pwdController.text.isNotEmpty;
    });
  }

  Future<void> obtenerPerfiles() async {
    try {
      final response =
          await http.get(Uri.parse('http://20.97.20.115:8081/api/perfiles'));
      if (response.statusCode == 200) {
        setState(() {
          perfiles = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al cargar perfiles: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfiles: $e')));
    }
  }

  Future<void> obtenerSocios() async {
    try {
      final response =
          await http.get(Uri.parse('http://20.97.20.115:8081/api/socios'));
      if (response.statusCode == 200) {
        setState(() {
          socios = jsonDecode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al cargar socios: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cargar socios: $e')));
    }
  }

  Future<void> actualizarUsuario() async {
    int idUsuario = idusuario!;
    String usuario = usuarioController.text;
    String pwd = pwdController.text;
    int idPerfil = int.parse(selectedPerfil!);
    int idSocio = int.parse(selectedSocio!);
    int activo = selectedActivo!;

    Map<String, dynamic> body = {
      'ID': idUsuario,
      'USUARIO': usuario,
      'PWD': pwd,
      'PERFIL': idPerfil,
      'SOCIO': idSocio,
      'ACTIVO': activo,
    };

    try {
      final response = await http.put(
        Uri.parse('http://10.2.0.7:8081/api/usuarios/$idUsuario'),
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Usuario actualizado')));

        if (widget.onUsuarioActualizado != null) {
          widget.onUsuarioActualizado!();
        }

        // Navigate back to the AdminUsuarios screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminUsuarios()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error al actualizar el usuario: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el usuario: $e')));
    }
  }

  Future<void> eliminarUsuario() async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.2.0.7:8081/api/usuarios/${widget.user['ID']}'),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Usuario eliminado')));

        if (widget.onUsuarioActualizado != null) {
          widget.onUsuarioActualizado!();
        }

        // Navigate back to the AdminUsuarios screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminUsuarios()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Error al eliminar el usuario: ${response.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el usuario: $e')));
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
                    value: perfil['ID'].toString(),
                    child: Text(perfil['PERFIL']),
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
                    value: socio['ID'].toString(),
                    child: Text(socio['SOCIO']),
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
                    value: selectedActivo == 1,
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
                  Provider.of<SerialNumberModel>(context, listen: false)
                      .setSerialNumber('');
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
                  ),
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
