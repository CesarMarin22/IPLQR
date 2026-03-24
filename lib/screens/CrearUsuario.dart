import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/admin_usuarios.dart';

class crearUsuario extends StatefulWidget {
  final Function? onUsuarioAgregado;

  const crearUsuario({Key? key, this.onUsuarioAgregado}) : super(key: key);
  @override
  _crearUsuarioState createState() => _crearUsuarioState();
}

class _crearUsuarioState extends State<crearUsuario> {
  String usuario = '';
  String pwd = '';
  String? selectedPerfil;
  String? selectedSocio;
  String? selectedSucursal;
  int selectedActivo = 1; // Por defecto, activo es 1 (activo)

  List<dynamic> perfiles = [];
  List<dynamic> socios = [];

  List<Map<String, String>> sucursales = [
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

  @override
  void initState() {
    super.initState();
    // Obtener los perfiles disponibles
    obtenerPerfiles();
    // Obtener los socios disponibles
    obtenerSocios();
  }

  Future<void> obtenerPerfiles() async {
    http.Response response =
        await http.get(Uri.parse('http://68.155.144.63:8081/api/perfiles'));
    if (response.statusCode == 200) {
      setState(() {
        perfiles = jsonDecode(response.body);
        selectedPerfil =
            perfiles.isNotEmpty ? perfiles[0]['ID'].toString() : null;
      });
    }
  }

  Future<void> obtenerSocios() async {
    http.Response response =
        await http.get(Uri.parse('http://68.155.144.63:8081/api/socios'));
    if (response.statusCode == 200) {
      setState(() {
        socios = jsonDecode(response.body);
        selectedSocio = socios.isNotEmpty ? socios[0]['ID'].toString() : null;
      });
    }
  }

  Future<void> agregarUsuario() async {
    // Construir el cuerpo de la solicitud
    Map<String, dynamic> body = {
      'USUARIO': usuario,
      'PWD': pwd,
      'PERFIL': selectedPerfil,
      'SOCIO': selectedSocio,
      'ACTIVO': selectedActivo,
      'SUCURSAL': selectedSucursal,
    };

    // Realizar la solicitud POST para agregar el usuario
    http.Response response = await http.post(
      Uri.parse('http://68.155.144.63:8081/api/usuarios'),
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Usuario agregado correctamente
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Usuario agregado')));
      if (widget.onUsuarioAgregado != null) {
        widget.onUsuarioAgregado!();
      }
      Navigator.pop(context); // Volver a la pantalla anterior
    } else {
      // Error al agregar el usuario
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al agregar el usuario')));
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(
                    children: [
                      const Text(
                        'CREAR USUARIO',
                        style: TextStyle(fontSize: 40),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                    ],
                  ),
                ),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      usuario = value;
                    });
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
                              color: Color.fromARGB(255, 243, 138, 0)))),
                ),
                SizedBox(height: 10),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      pwd = value;
                    });
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
                              color: Color.fromARGB(255, 243, 138, 0)))),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedSucursal,
                  onChanged: (newValue) {
                    setState(() {
                      selectedSucursal = newValue;
                    });
                  },
                  items: sucursales.map((sucursal) {
                    return DropdownMenuItem<String>(
                      value: sucursal['codigo'], // lo que se enviará
                      child: Text(sucursal['nombre']!), // lo que se mostrará
                    );
                  }).toList(),
                  decoration: InputDecoration(
                    labelText: 'Sucursal',
                    labelStyle:
                        const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                          color: Color.fromARGB(255, 243, 138, 0)),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(
                          color: Color.fromARGB(255, 243, 138, 0)),
                    ),
                  ),
                ),
                SizedBox(height: 10),
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
                        labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0)),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 243, 138, 0),
                          ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                                color: Color.fromARGB(255, 243, 138, 0))))),
                SizedBox(height: 10),
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
                              color: Color.fromARGB(255, 243, 138, 0)))),
                ),
                SizedBox(height: 10),
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
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: usuario.isNotEmpty && pwd.isNotEmpty
                      ? agregarUsuario
                      : null,
                  child: Text(
                    'Agregar Usuario',
                    style: TextStyle(color: Colors.black),
                  ),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(
                      usuario.isNotEmpty && pwd.isNotEmpty
                          ? Color.fromARGB(255, 243, 138, 0)
                          : Colors.grey,
                    ),
                  ),
                ),
                SizedBox(height: 10),
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
                        Colors.red), // Color de fondo del botón
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
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                  Text(
                    'Powered by IPL',
                    style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 12.0,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
