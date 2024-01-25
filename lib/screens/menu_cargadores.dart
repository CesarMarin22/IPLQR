import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/informacion_cargadores.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_cargadores.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';

class menuCargadores extends StatefulWidget {
  const menuCargadores({super.key});

  @override
  State<menuCargadores> createState() => _menuCargadoresState();
}

class _menuCargadoresState extends State<menuCargadores> {
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

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
              'assets/logo_ipl_negro.png',
              width: 70,
              height: 70,
            ),
          ),
        ), // cuerpo de la aplicacion/////////////////////////
        body: Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Column(
            children: [
              const Text(
                'CARGADORES',
                style: TextStyle(fontSize: 40),
              ),
              const SizedBox(
                height: 100,
              ),

////////////////////////////boton informacion////////////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const InformacionCargadores()));
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 243, 138, 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                              const BorderSide(color: Colors.black, width: 5))),
                  child: const Text(
                    'INFORMACIÓN',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
/////////////////Termino de boton informacion////////////////////////////////////////////
              ///
              ////////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 65,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
//////////////////boton historia de servicios//////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const LlamadaServiciosCargadores(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 243, 138, 0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                              const BorderSide(color: Colors.black, width: 5))),
                  child: const Text(
                    'HISTORIAL DE SERVICIOS',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
///////////////////////fin boton historial de servicios/////////////////////////////
////////////////////////////Termino boton Reporte de instalacion/////////////////////////
              ////////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 80,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
/////////////////////boton REGRESAR //////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 90,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const eleccion()));
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                              const BorderSide(color: Colors.black, width: 5))),
                  child: const Text(
                    'REGRESAR',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
///////////////////////fin boton historial de servicios/////////////////////////////
            ],
          ),
        )),
/////////////////configuracion Fotter/////////////////////////////////////////////////////
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
        )
        ///////////////// fin de configuracion Fotter/////////////////////////////////////////////////////
        );
  }
}
