class AppData {
  static final AppData _instance = AppData._internal();
  factory AppData() => _instance;

  AppData._internal();

  String numSerie = '';
}
