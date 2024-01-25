import 'package:flutter/foundation.dart';

class SerialNumberModel extends ChangeNotifier {
  String serialNumber;

  SerialNumberModel(this.serialNumber);

  void setSerialNumber(String number) {
    serialNumber = number;
  }
}
