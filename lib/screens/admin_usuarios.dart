import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/CrearUsuario.dart';
import 'package:proyecto_qr/screens/crud.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'dart:math';

class AdminUsuarios extends StatefulWidget {
  const AdminUsuarios({Key? key}) : super(key: key);

  @override
  State<AdminUsuarios> createState() => _AdminUsuariosState();
}

class _AdminUsuariosState extends State<AdminUsuarios> {
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  Future<List<dynamic>> fetchUsers() async {
    final response =
        await http.get(Uri.parse('http://68.155.144.63:8081/api/usuarios'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  Color randomColor() {
    Random random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCookie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;
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
      body: FutureBuilder<List<dynamic>>(
        future: fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            List<dynamic> users = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Column(
                    children: [
                      const Text(
                        'USUARIOS',
                        style: TextStyle(fontSize: 40),
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(
                        16), // Añadir espacio alrededor del ListView
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        var user = users[index];
                        // Generar color aleatorio para el avatar
                        Color randomColor = Color.fromRGBO(
                          Random().nextInt(256),
                          Random().nextInt(256),
                          Random().nextInt(256),
                          1,
                        );
                        return Card(
                          elevation: 4, // Agregar sombra
                          margin: EdgeInsets.symmetric(
                              vertical: 8), // Espacio entre las tarjetas
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: randomColor,
                              child: Text(
                                user['USUARIO'][0].toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(user['USUARIO']),
                            subtitle: Text(
                              'Perfil: ${int.tryParse(user['PERFIL'].toString().replaceAll('0x', '')) ?? 0}',
                            ),
                            trailing: Icon(Icons.arrow_forward),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetalleUsuarioScreen(
                                    user: user,
                                    onUsuarioActualizado: () {
                                      setState(() {
                                        fetchUsers();
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButton: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin:
                    EdgeInsets.only(bottom: 16), // Espacio entre los botones
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => crearUsuario(
                          onUsuarioAgregado: () {
                            setState(() {
                              fetchUsers();
                            });
                          },
                        ),
                      ),
                    );
                  },
                  child: Icon(Icons.add),
                  backgroundColor: Colors.green,
                ),
              ),
              Container(
                margin:
                    EdgeInsets.only(bottom: 16), // Espacio entre los botones
                child: FloatingActionButton(
                  onPressed: () {
                    // Acción para regresar a otra pantalla
                    Provider.of<SerialNumberModel>(context, listen: false)
                        .setSerialNumber('');

                    // Navegar a la pantalla de escaneo (eleccion)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const eleccion(),
                      ),
                    );
                  },
                  child: Icon(Icons.arrow_back),
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
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
