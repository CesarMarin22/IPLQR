import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/screens/escoger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isButtonDisabled = true;

  Future<void> _attemptLogin(
    AuthProvider authProvider,
    String username,
    String password,
    BuildContext context,
  ) async {
    try {
      await authProvider.login(username, password, context);

      // Después de un inicio de sesión exitoso, verifica si el usuario está autenticado
      if (authProvider.authenticatedUser != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const eleccion()),
        );
      } else {
        throw Exception('Error de inicio de sesión');
      }
    } catch (e) {
      if (e is UserNotFoundException) {
        print(e);
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: const Text('El usuario es incorrecto.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else if (e is InvalidCredentialsException) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: const Text('La contraseña es incorrecta.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error de inicio de sesión'),
              content: const Text('Usuario y/o contraseña incorrectos.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 247, 246, 244),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_ipl_negro.png', // Reemplaza con la ruta correcta de la imagen
                  width: 200,
                  height: 200,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Inicio de Sesión',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 243, 138, 0),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  cursorColor: const Color.fromARGB(255, 0, 0, 0),
                  onChanged: (value) {
                    setState(() {
                      _isButtonDisabled =
                          value.isEmpty || _passwordController.text.isEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    labelStyle:
                        const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    prefixIcon: const Icon(
                      Icons.person,
                      color: Color.fromARGB(255, 29, 29, 27),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(
                          color: Color.fromARGB(255, 243, 138, 0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                          const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  cursorColor: const Color.fromARGB(255, 0, 0, 0),
                  onChanged: (value) {
                    setState(() {
                      _isButtonDisabled = _usernameController.text.isEmpty;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle:
                        const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Color.fromARGB(255, 29, 29, 27),
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                      child: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(
                          color: Color.fromARGB(255, 243, 138, 0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide:
                          const BorderSide(color: Color.fromARGB(255, 0, 0, 0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 20.0,
                      horizontal: 10.0,
                    ),
                  ),
                  obscureText: !_showPassword,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isButtonDisabled
                      ? null
                      : () async {
                          final username = _usernameController.text;
                          final password = _passwordController.text;

                          if (username.isEmpty || password.isEmpty) {
                            return; // Mostrar mensaje de campos vacíos
                          } else {
                            await _attemptLogin(
                              authProvider,
                              username,
                              password,
                              context,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 243, 138, 0),
                  ),
                  child: const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding:
                              const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          title: const Text(
                            'AVISO DE PRIVACIDAD INTEGRAL',
                            style: TextStyle(
                              color: Color.fromARGB(255, 243, 138, 0),
                              fontSize: 20,
                            ),
                          ),
                          content: const SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: Text(
                                'Con fundamento en la Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 6, 8, 15, 16 y 17 le informamos que INTER PRICE LOGISTICA S.A. DE C.V., es una empresa legalmente constituida de conformidad con las leyes mexicanas, con domicilio en Carretera Federal 57. KM 183 Numero 950, S/N Código Postal 78426, San Luis Potosí, S.L.P, México, será responsable de los datos personales que le son proporcionados por sus clientes, empleados, proveedores, y cualquier otra persona con los que mantenga o haya mantenido una relación comercial, laboral, patrimonial o de negocios que se requiera para cumplir con las obligaciones derivadas de diversos contratos y convenios celebrados entre los particulares e INTER PRICE LOGISTICA S.A. DE C.V, y serán tratados de conformidad con la Ley Federal de Protección de Datos Personales en Posesión de los Particulares y su Reglamento.\n\nINTER PRICE LOGISTICA S.A. DE CV. cuenta con mecanismos para asegurar la confidencialidad de los datos personales que le sean proporcionados, quedando éstos protegidos por medidas de seguridad para evitar su daño, pérdida, alteración, destrucción, uso, acceso o divulgación indebida.\n\nINTER PRICE LOGISTICA S.A. DE C.V. Es responsable de la información y datos personales que posee, recaba o recabará para la prestación de los servicios que se le ha requerido mediante contratos, así como para la celebración de los demás actos que pueda realizar conforme a las leyes aplicables y a sus estatutos. Los datos personales recabados o que se recaban podrán incluir los siguientes:\n\n• Datos de identificación y de contacto del solicitante: nombre completo, dirección, teléfono, R.F.C, correo electrónico, estado civil, nacionalidad, fecha de nacimiento, cualquier dato consistente en las generales.\n\n• Datos de identificación y de contacto de las personas de contacto: nombre completo, dirección, teléfono, R.F.C., correo electrónico.\n\n• Nombre completo, dirección, teléfono, R.F.C, correo electrónico y datos fiscales del Representante Legal de la Empresa.\n\nDe conformidad en lo señalado en la Ley se le informa que los datos personales que se recaben, serán utilizados para las siguientes finalidades:\n\n• La realización de todas y cada una de las operaciones y la celebración de los demás actos que INTER PRICE LOGISTICA S.A. DE C.V. Pueda realizar conforme a la legislación aplicable a la misma.\n\n• La publicidad, promoción o recomendación entre diversas Empresas de la misma actividad comercial que INTER PRICE LOGISTICA S.A. DE C.V.\n\n• La atención de requerimientos de cualquier autoridad competente conforme a la legislación aplicable a INTER PRICE LOGISTICA S.A. DE C.V.\n\n• La comunicación con sus clientes, proveedores, empleados, actuales o anteriores, para tratar cualquier tema relacionado con asuntos contractuales, comerciales y/o laborales.\n\n• La generación de gestiones internas necesarias, así como las consultas, investigaciones y revisiones en relación a cualquier queja y/o aclaración.\n\n• Consultas y Registro en la Base de Datos de las Sociedades de Información Crediticia respecto al historial crediticio del Representante Legal y/o la Empresa a la que representa.\n\n• La gestión de cobranza buscando la recuperación de cartera vencida, así como para realizar acciones preventivas en este sentido, incluyendo la venta de cartera.\n\n• Publicidad, promoción y/o telemarketing de los productos y servicios que sean ofrecidos por INTER PRICE LOGISTICA S.A. DE CV. por cualquier medio material o electrónico.\n\nINTER PRICE LOGISTICA S.A. DE C.V. puede transmitir los datos personales del solicitante, del Representante Legal y/o de las personas de contacto, cuando ceda, transfiera, y/o negocie, en cualquier forma, los derechos de crédito que se registren en el convenio de apertura celebrado por los mismos, así como el pagaré suscrito al amparo del mismo; cuando la transferencia sea obligatoria, necesaria o conveniente en relación a los Derechos de Crédito a cualquiera de los terceros que brinden algún producto y/o servicio relacionado con los que se le solicita a INTER PRICE LOGISTICA S.A. DE CV. o se relacionen con el Crédito.\n\nLos datos personales recabados serán tratados de acuerdo a la legislación antes citada, por lo que le informamos que usted tiene en todo momento los derechos ARCO (Acceder, Rectificar, Cancelar, Oponerse) mismo que podrá hacer valer a través de la Gerencia Administrativa o bien, si requieren alguna ayuda o asesoría podrán comunicarse directamente a INTER PRICE LOGISTICA S.A. DE C.V, servicio via telefónica de lunes a viernes de 08:00 a 14:00 horas y de 16:00 a 20:00 horas, Sábados de 10:00 a 14:00 horas al teléfono 4448119412 o directamente enviando un correo a la dirección: abogados@abogadosbaez.com.mx. En donde podrán obtener los formatos correspondientes, los cuales deberán hacerle llegar a INTER PRICE LOGISTICA S.A. DE C.V. por los medios aplicables. A través de estos medios, el Solicitante podrá actualizar sus datos y especificar el medio por el cual desea recibir información, ya que, en caso de no contar con esta especificación de su parte, INTER PRICE LOGISTICA S.A. DE CV. establecerá libremente el medio que considere pertinente para enviarle información.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Aceptar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text(
                    'Aviso de Privacidad',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Color.fromARGB(255, 243, 138, 0),
                    ),
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
