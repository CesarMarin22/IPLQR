import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class apiService {
  static const String PDF_URL = "https://www.ibm.com/downloads/cas/GJ5QVQ7X";

  static Future<String> loadPDF() async {
    var pdfUri = Uri.parse(PDF_URL);
    var response = await http.get(pdfUri);

    var dir = await getTemporaryDirectory();
    File file = File("${dir.path}/data.pdf");

    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file.path;
  }
}
