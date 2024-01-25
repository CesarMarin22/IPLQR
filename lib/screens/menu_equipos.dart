import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/informacion_equipos.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:proyecto_qr/screens/llamadas_servicio_equipos.dart';
import 'package:proyecto_qr/screens/reporte_instalacion.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:proyecto_qr/providers/serial_number.dart';

class menuEquipos extends StatefulWidget {
  const menuEquipos({super.key});

  @override
  State<menuEquipos> createState() => _menuEquipos();
}

class _menuEquipos extends State<menuEquipos> {
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
        ),
//////////// cuerpo de la aplicacion/////////////////////////
        body: Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Column(
            children: [
              const Text(
                'EQUIPOS',
                style: TextStyle(fontSize: 40),
              ),
              const SizedBox(
                height: 70,
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
                            builder: (context) => const HomePage()));
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
/////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 25,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
///////////////boton reporte de instalacion//////////////////////////////////////////////

              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FileViewerFromAPI(),
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
                    'REPORTE DE INSTALACIÓN',
                    style: TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
/////////////////////////Termino boton Reporte de instalacion/////////////////////////
              ////////////////espaciado entre botones///////////////////////////////////////////////////
              const SizedBox(
                height: 25,
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
                        builder: (context) => const LlamadaServiciosEquipos(),
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
                height: 50,
              ),

////////////////////termino Espaciado entre botones////////////////////////////////////
              ///
/////////////////////boton REGRESAR //////////////////////////////////////////////
              SizedBox(
                width: 200,
                height: 90,
                child: ElevatedButton(
                  onPressed: () {
                    // Resetear el número de serie al hacer clic en "SCANEAR"
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
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.black, width: 5),
                    ),
                  ),
                  child: const Text(
                    'SCANEAR',
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

class PdfViewerScreen extends StatelessWidget {
  final String pdfPath;

  const PdfViewerScreen({super.key, required this.pdfPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de PDF'),
      ),
      body: PDFView(
        filePath: pdfPath,
      ),
    );
  }
}
