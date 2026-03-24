import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:rive/rive.dart';
import 'package:proyecto_qr/screens/escoger.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final FileLoader _riveLoader = FileLoader.fromAsset(
    'assets/cargando_imagen.riv',
    riveFactory: Factory.rive,
  );

  bool _showPassword = false;
  bool _isButtonDisabled = true;
  bool _isLoading = false;

  Widget _buildLoadingScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final size = (screenWidth * 0.75).clamp(280.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: size,
          height: screenHeight * 0.38,
          child: RiveWidgetBuilder(
            fileLoader: _riveLoader,
            builder: (context, state) {
              return switch (state) {
                RiveLoading() => const CircularProgressIndicator(),
                RiveFailed() =>
                  Text('Error al cargar animación: ${state.error}'),
                RiveLoaded() => Transform.scale(
                    scale: 1.6,
                    child: RiveWidget(
                      controller: state.controller,
                      fit: Fit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
              };
            },
          ),
        ),
      ),
    );
  }

  Future<void> _attemptLogin(
    AuthProvider authProvider,
    String username,
    String password,
    BuildContext context,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await authProvider.login(username, password, context);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const eleccion()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      String mensaje = 'Usuario y/o contraseña incorrectos.';

      if (e is UserNotFoundException) {
        mensaje = 'El usuario es incorrecto.';
      } else if (e is InvalidCredentialsException) {
        mensaje = 'La contraseña es incorrecta.';
      }

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error de inicio de sesión'),
            content: Text(mensaje),
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _riveLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return _isLoading
        ? _buildLoadingScreen()
        : Scaffold(
            backgroundColor: const Color.fromARGB(255, 247, 246, 244),
            body: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo_ipl_negro.png',
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
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                        cursorColor: const Color.fromARGB(255, 243, 138, 0),
                        onChanged: (value) {
                          setState(() {
                            _isButtonDisabled = value.isEmpty ||
                                _passwordController.text.isEmpty;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          prefixIcon: const Icon(
                            Icons.person,
                            color: Color.fromARGB(255, 29, 29, 27),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 243, 138, 0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                        cursorColor: const Color.fromARGB(255, 243, 138, 0),
                        onChanged: (value) {
                          setState(() {
                            _isButtonDisabled =
                                _usernameController.text.isEmpty ||
                                    value.isEmpty;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: const TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
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
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 243, 138, 0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
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
                                  return;
                                }

                                await _attemptLogin(
                                  authProvider,
                                  username,
                                  password,
                                  context,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 243, 138, 0),
                        ),
                        child: const Text(
                          'Iniciar Sesión',
                          style: TextStyle(color: Colors.black),
                        ),
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
                                      'Con fundamento en la Ley Federal de Protección de Datos Personales en Posesión de los Particulares...',
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
