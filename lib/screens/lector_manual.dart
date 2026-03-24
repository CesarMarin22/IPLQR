import 'package:flutter/material.dart';
import 'package:proyecto_qr/screens/escoger.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'dart:io';
import 'package:http/io_client.dart';
import 'dart:convert';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final TextEditingController serialNumberController = TextEditingController();
  final FocusNode serialFocusNode = FocusNode();

  bool botonHabilitado = false;
  bool _isLoading = false;

  String authToken = '';
  String tipo = '';
  String sessionCookie = '';
  String routeIdCoockie = '';

  @override
  void dispose() {
    serialNumberController.dispose();
    serialFocusNode.dispose();
    super.dispose();
  }

  void _showToast(
    String message, {
    Color backgroundColor = Colors.red,
    Color textColor = Colors.white,
  }) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontSize: 14,
    );
  }

  void navigateTomenuEquipos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuEquipos()),
    ).then((_) {
      _resetForm();
    });
  }

  void navigateTomenuBaterias() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuBaterias()),
    ).then((_) {
      _resetForm();
    });
  }

  void navigateTomenuCargadores() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const menuCargadores()),
    ).then((_) {
      _resetForm();
    });
  }

  void _resetForm() {
    serialNumberController.clear();
    setState(() {
      botonHabilitado = false;
      _isLoading = false;
    });
  }

  void mostrarErrorArticulo() {
    setState(() {
      _isLoading = false;
      botonHabilitado = serialNumberController.text.trim().isNotEmpty;
    });

    _showToast(
      'No se encontró un artículo válido con ese número de serie.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    sessionCookie = authProvider.sessionCookie;
    routeIdCoockie = authProvider.routeIdCookie;
    authToken = authProvider.authToken;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F4),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 243, 138, 0),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Image.asset(
          'assets/logo ipl_BLANCO.png',
          width: 60,
          height: 60,
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Búsqueda manual',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 29, 29, 27),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa el número de serie para localizar el equipo, batería o cargador.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(255, 90, 90, 90),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(20, 0, 0, 0),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Color.fromARGB(255, 243, 138, 0),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Número de serie',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color.fromARGB(255, 29, 29, 27),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: serialNumberController,
                          focusNode: serialFocusNode,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) {
                            setState(() {
                              botonHabilitado = value.trim().isNotEmpty;
                            });
                          },
                          onSubmitted: (value) {
                            if (!_isLoading && value.trim().isNotEmpty) {
                              _buscarSerie();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Ejemplo: ABC123456',
                            prefixIcon: const Icon(Icons.qr_code_2_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF7F7F7),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 220, 220, 220),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 243, 138, 0),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: (botonHabilitado && !_isLoading)
                                ? _buscarSerie
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color.fromARGB(255, 243, 138, 0),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.search),
                            label: const Text(
                              'Buscar equipo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Provider.of<SerialNumberModel>(
                                      context,
                                      listen: false,
                                    ).setSerialNumber('');

                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const eleccion(),
                                      ),
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  const Color.fromARGB(255, 29, 29, 27),
                              side: const BorderSide(
                                color: Color.fromARGB(255, 29, 29, 27),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text(
                              'Volver a escanear',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 248, 235),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color.fromARGB(255, 243, 138, 0),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color.fromARGB(255, 243, 138, 0),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Usa esta opción cuando el código QR no esté disponible o no pueda leerse correctamente.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 29, 29, 27),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: const Color.fromARGB(120, 255, 255, 255),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 243, 138, 0),
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
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Powered by IPL',
                  style: TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 12.0,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _buscarSerie() {
    final serie = serialNumberController.text.trim();

    if (serie.isEmpty || _isLoading) return;

    FocusScope.of(context).unfocus();

    Provider.of<SerialNumberModel>(context, listen: false)
        .setSerialNumber(serie);

    setState(() {
      _isLoading = true;
    });

    _fetchDataFromAPI(serie);
  }

  Future<void> _fetchDataFromAPI(String serie) async {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      return true;
    };

    final ioClient = IOClient(client);

    final apiUrl = Uri.parse(
      'https://68.155.144.63:50000/b1s/v1/\$crossjoin(Items,ItemGroups)?'
      '\$expand=Items(\$select=AssetGroup),'
      'ItemGroups(\$select=GroupName)&'
      '\$filter=Items/ItemsGroupCode eq ItemGroups/Number and Items/ForeignName eq \'$serie\'',
    );

    try {
      final response = await ioClient.get(
        apiUrl,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Cookie': 'B1SESSION=$sessionCookie; ROUTEID=$routeIdCoockie',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        bool articuloValido = false;

        for (var item in decodedResponse['value']) {
          if (item['ItemGroups'] != null) {
            articuloValido = true;

            final items = item['ItemGroups'];
            tipo = items['GroupName'] ?? '';
            final assetGroup = item['Items']['AssetGroup'] ?? '';

            if (tipo == 'MONTACARGAS' || assetGroup == 'MO') {
              setState(() => _isLoading = false);
              navigateTomenuEquipos();
              return;
            } else if (tipo == 'BATERIAS' || assetGroup == 'BAT') {
              setState(() => _isLoading = false);
              navigateTomenuBaterias();
              return;
            } else if (tipo == 'CARGADORES' || assetGroup == 'CAR') {
              setState(() => _isLoading = false);
              navigateTomenuCargadores();
              return;
            }
          }
        }

        if (!articuloValido) {
          mostrarErrorArticulo();
        } else {
          mostrarErrorArticulo();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showToast(
          'No fue posible consultar la información. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showToast('Ocurrió un error al consultar el número de serie.');
    }
  }
}
