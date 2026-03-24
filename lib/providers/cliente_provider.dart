import 'package:flutter/material.dart';

class ClienteProvider with ChangeNotifier {
  String _cliente = '';

  String get cliente => _cliente;

  void setCliente(String nuevoCliente) {
    _cliente = nuevoCliente;
    notifyListeners();
  }

  void clearCliente() {
    _cliente = '';
    notifyListeners();
  }
}
