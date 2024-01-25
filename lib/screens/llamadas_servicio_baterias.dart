import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:proyecto_qr/screens/detalle_llamadas_baterias.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/sesion.dart';
import 'package:fluttertoast/fluttertoast.dart';

Color especialColor = Color(0xFFA9DFBF);
Color correctivoColor = Color(0xFFFAD02E);
Color preventivoColor = Color(0xFFE8DAEF);
Color azulPastel = Color(0xFFADD8E6);
Color rojopastel = Color(0xFFFFB6C1);

class LlamadaServiciosBaterias extends StatefulWidget {
  const LlamadaServiciosBaterias({Key? key});

  @override
  State<LlamadaServiciosBaterias> createState() =>
      _LlamadaServiciosBateriasState();
}

class _LlamadaServiciosBateriasState extends State<LlamadaServiciosBaterias> {
  bool isOption1Selected = true;
  Future<List<LlamadaServicio>>? futureCalls;
  String? selectedOT;
  int touchedIndex = -1;
  Map<String, int> serviceTypeCounts = {};
  String authToken = ''; // Token de autenticación
  String sessionCookie = '';
  String routeIdCookie = '';

  @override
  void initState() {
    super.initState();
    fetchData();
    // Selecciona la primera opción (información) por defecto
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<List<LlamadaServicio>> fetchData() async {
    final numSerie =
        Provider.of<SerialNumberModel>(context, listen: false).serialNumber;
    if (numSerie != "" && numSerie.isNotEmpty) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      sessionCookie = authProvider.sessionCookie;
      routeIdCookie = authProvider.routeIdCookie;
      authToken = authProvider.authToken;

      print('authToken: $authToken');
      print('sessionCookie: $sessionCookie');
      print('routeIdCookie: $routeIdCookie');

      return fetchDataFromAPI(numSerie);
    }
    return [];
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
            'assets/logo_ipl_negro.png',
            width: 70,
            height: 70,
          ),
        ),
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Column(
                children: [
                  const Text(
                    'HISTORIAL DE SERVICIOS',
                    style: TextStyle(fontSize: 30),
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                  ToggleButtons(
                    selectedColor: Colors.white,
                    fillColor: Color.fromARGB(255, 243, 138, 0),
                    borderWidth: 3,
                    selectedBorderColor: Color.fromARGB(255, 243, 138, 0),
                    borderRadius: BorderRadius.circular(50),
                    isSelected: [isOption1Selected, !isOption1Selected],
                    onPressed: (index) {
                      setState(() {
                        isOption1Selected = index == 0;
                      });
                    },
                    children: [
                      FaIcon(FontAwesomeIcons.table),
                      Icon(Icons.pie_chart),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 60),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: FutureBuilder<List<LlamadaServicio>>(
                  future: fetchData(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                          child:
                              Text('No se encontraron llamadas de servicio.'));
                    } else if (isOption1Selected) {
                      return DataTable(
                        columns: <DataColumn>[
                          DataColumn(label: Text('O.T.')),
                          DataColumn(label: Text('FALLA')),
                          DataColumn(label: Text('FECHA')),
                          DataColumn(label: Text('TIPO DE SERVICIO')),
                        ],
                        rows: snapshot.data!
                            .map((llamada) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(llamada.serviceCallID.toString()),
                                      onTap: () {
                                        setState(() {
                                          selectedOT =
                                              llamada.serviceCallID.toString();
                                        });
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DetallesLlamadaServicioBaterias(
                                              ot: llamada.serviceCallID
                                                  .toString(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    DataCell(Text(llamada.subject)),
                                    DataCell(Text(llamada.creationDate)),
                                    DataCell(Text(llamada.serviceCallTypeName)),
                                  ],
                                ))
                            .toList(),
                      );
                    } else {
                      return PieChartSample2(
                        touchedIndex: touchedIndex,
                        llamadas: snapshot.data!,
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 18.0),
          SizedBox(
            width: 200,
            height: 90,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const menuBaterias()));
              },
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  backgroundColor: const Color.fromARGB(255, 250, 2, 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.black, width: 5))),
              child: const Text(
                'REGRESAR',
                style: TextStyle(fontSize: 20, color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
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
      ),
    );
  }

  Widget _buildIndicators(List<LlamadaServicio> llamadas) {
    final Map<String, int> serviceTypeCounts = {};

    for (final llamada in llamadas) {
      final tipoServicio = llamada.serviceCallTypeName;
      serviceTypeCounts[tipoServicio] =
          (serviceTypeCounts[tipoServicio] ?? 0) + 1;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: serviceTypeCounts.entries.map((entry) {
        return _buildIndicator(getColorForServiceType(entry.key), entry.key);
      }).toList(),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: color,
          ),
        ),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  List<PieChartSectionData> _generatePieChartSections(
    List<LlamadaServicio> llamadas,
  ) {
    final Map<String, int> serviceTypeCounts = {};

    for (final llamada in llamadas) {
      final tipoServicio = llamada.serviceCallTypeName;
      serviceTypeCounts[tipoServicio] =
          (serviceTypeCounts[tipoServicio] ?? 0) + 1;
    }

    final List<PieChartSectionData> sections = [];

    serviceTypeCounts.entries.forEach((entry) {
      final String tipoServicio = entry.key;
      final int cantidad = entry.value;
      final double porcentaje = (cantidad / llamadas.length) * 100;

      final String label =
          '(${cantidad.toString()})\n${porcentaje.toStringAsFixed(2)}%';

      final PieChartSectionData section = PieChartSectionData(
        color: getColorForServiceType(tipoServicio),
        value: cantidad.toDouble(),
        title: label,
        radius: 150,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );

      sections.add(section);
    });

    return sections;
  }

  Color getColorForServiceType(String tipoServicio) {
    Map<String, Color> colorMap = {
      'ESPECIAL': especialColor,
      'CORRECTIVO': correctivoColor,
      'PREVENTIVO': preventivoColor,
      'DAÑO': azulPastel,
      'DIAGNOSTICO': rojopastel,
    };

    return colorMap[tipoServicio] ?? Colors.grey;
  }

  Future<List<LlamadaServicio>> fetchDataFromAPI(String numSerie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true; // Permite certificados autofirmados
    };

    final ioClient = IOClient(client);

    final apiUrl = Uri.parse(
      'https://52.152.107.200:50000/b1s/v1/\$crossjoin(ServiceCalls,ServiceCallTypes)?'
      '\$expand=ServiceCalls(\$select=ServiceCallID, Subject, CreationDate),'
      'ServiceCallTypes(\$select=Name)&'
      '\$filter=ServiceCalls/CallType eq ServiceCallTypes/CallTypeID and ServiceCalls/ManufacturerSerialNum eq \'$numSerie\'&'
      '\$orderby=CreationDate desc',
    );

    try {
      final response = await ioClient.get(
        apiUrl,
        headers: {
          'Authorization':
              'Bearer $authToken', // Incluye el token de autenticación
          'Cookie':
              'B1SESSION=$sessionCookie; ROUTEID=$routeIdCookie', // Agrega las cookies a la solicitud
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = json.decode(response.body);

        final List<LlamadaServicio> llamadas =
            (decodedResponse['value'] as List<dynamic>)
                .map((dynamic json) => LlamadaServicio.fromJson(json))
                .toList();
        print('Datos recibidos: $llamadas');
        print('Número de llamadas recibidas: ${llamadas.length}');

        return llamadas;
      } else if (response.statusCode == 401) {
        final decodedResponse = json.decode(response.body);
        final error = decodedResponse['error'];
        if (error['code'] == 301) {
          // Mostrar el FlutterToast indicando que la sesión ha expirado
          showToast(
              'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.');
          // Redirigir al inicio de sesión
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    LoginScreen()), // Reemplaza 'LoginPage' con la clase de tu pantalla de inicio de sesión
          ); // Ajusta la ruta según tu aplicación
        } else {
          // Mostrar el AlertDialog con el mensaje de error
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Error en la solicitud'),
                content: Text(
                    'Código de error: ${error['code']}\nMensaje: ${error['message']['value']}'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Mostrar el AlertDialog con el mensaje de error
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error en la solicitud'),
              content: Text('Código de error: ${response.statusCode}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('Ocurrió un error inesperado: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
    return [];
  }
}

class LlamadaServicio {
  final int serviceCallID;
  final String subject;
  final String creationDate;
  final String serviceCallTypeName;

  LlamadaServicio({
    required this.serviceCallID,
    required this.subject,
    required this.creationDate,
    required this.serviceCallTypeName,
  });

  factory LlamadaServicio.fromJson(Map<String, dynamic> json) {
    final serviceCalls = json['ServiceCalls'];
    final serviceCallTypes = json['ServiceCallTypes'];

    return LlamadaServicio(
      serviceCallID: serviceCalls['ServiceCallID'] ?? 0,
      subject: serviceCalls['Subject'] ?? '',
      creationDate: serviceCalls['CreationDate'] ?? '',
      serviceCallTypeName: serviceCallTypes['Name'] ?? '',
    );
  }
}

class PieChartSample2 extends StatelessWidget {
  final int touchedIndex;
  final List<LlamadaServicio> llamadas;

  const PieChartSample2({
    required this.touchedIndex,
    required this.llamadas,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 300,
          height: 300,
          child: Center(
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 0,
                sectionsSpace: 4,
                borderData: FlBorderData(show: false),
                sections: [
                  ...showingSections(llamadas),
                  ..._generatePieChartSections(llamadas)
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 30,
        ),
        _buildIndicators(llamadas),
      ],
    );
  }

  List<PieChartSectionData> showingSections(List<LlamadaServicio> llamadas) {
    final List<PieChartSectionData> sections = [];
    final Map<String, int> serviceTypeCounts = {};

    // Calcular porcentajes fuera del bucle
    final Map<String, double> porcentajes = {};

    serviceTypeCounts.entries.forEach((entry) {
      final String tipoServicio = entry.key;
      final int cantidad = entry.value;
      final double porcentaje = (cantidad / llamadas.length) * 100;
      porcentajes[tipoServicio] = porcentaje;
    });

    // Usar porcentajes dentro del bucle para crear las secciones
    llamadas.forEach((llamada) {
      final isTouched = llamadas.indexOf(llamada) == touchedIndex;
      final fontSize = isTouched ? 25.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;
      const shadows = [Shadow(color: Colors.black, blurRadius: 2)];

      final double porcentaje = porcentajes[llamada.serviceCallTypeName] ?? 0.0;

      sections.add(
        PieChartSectionData(
          color: getColorForServiceType(llamada.serviceCallTypeName),
          value: porcentaje, // Utiliza el porcentaje calculado previamente
          title:
              '${llamada.serviceCallTypeName}\n${porcentaje.toStringAsFixed(2)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color:
                Colors.white, // Cambia a blanco para que el texto sea visible
            shadows: shadows,
          ),
        ),
      );
    });

    return sections;
  }

  Widget _buildIndicators(List<LlamadaServicio> llamadas) {
    final Map<String, int> serviceTypeCounts = {};

    for (final llamada in llamadas) {
      final tipoServicio = llamada.serviceCallTypeName;
      serviceTypeCounts[tipoServicio] =
          (serviceTypeCounts[tipoServicio] ?? 0) + 1;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: serviceTypeCounts.entries.map((entry) {
        return _buildIndicator(getColorForServiceType(entry.key), entry.key);
      }).toList(),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: color,
          ),
        ),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  List<PieChartSectionData> _generatePieChartSections(
    List<LlamadaServicio> llamadas,
  ) {
    final Map<String, int> serviceTypeCounts = {};

    for (final llamada in llamadas) {
      final tipoServicio = llamada.serviceCallTypeName;
      serviceTypeCounts[tipoServicio] =
          (serviceTypeCounts[tipoServicio] ?? 0) + 1;
    }

    final List<PieChartSectionData> sections = [];

    serviceTypeCounts.entries.forEach((entry) {
      final String tipoServicio = entry.key;
      final int cantidad = entry.value;
      final double porcentaje = (cantidad / llamadas.length) * 100;

      final String label =
          '(${cantidad.toString()})\n${porcentaje.toStringAsFixed(2)}%';

      final PieChartSectionData section = PieChartSectionData(
        color: getColorForServiceType(tipoServicio),
        value: cantidad.toDouble(),
        title: label,
        radius: 150,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );

      sections.add(section);
    });

    print('Secciones de la gráfica de pastel: ${sections.length}');

    return sections;
  }

  Color getColorForServiceType(String tipoServicio) {
    Map<String, Color> colorMap = {
      'Especial': especialColor,
      'Correctivo': correctivoColor,
      'Preventivo Equipo': preventivoColor,
      'Daños': azulPastel,
      'Preventivo Bateria': rojopastel,
    };

    return colorMap[tipoServicio] ?? Colors.grey;
  }
}
