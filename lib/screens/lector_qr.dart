import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_qr/providers/auth_provider.dart';
import 'package:proyecto_qr/providers/serial_number.dart';
import 'package:proyecto_qr/screens/menu_baterias.dart';
import 'package:proyecto_qr/screens/menu_cargadores.dart';
import 'package:proyecto_qr/screens/menu_equipos.dart';
import 'package:proyecto_qr/services/api.dart';
import 'package:proyecto_qr/theme/app_theme.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({Key? key}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

/// Destino al que lleva un artículo según su grupo.
enum _Destino { equipos, baterias, cargadores }

class _QRScannerPageState extends State<QRScannerPage>
    with WidgetsBindingObserver {
  static const _timeout = Duration(seconds: 25);

  final MobileScannerController controller = MobileScannerController();

  String numSerie = '';

  /// Se pone en true de forma síncrona en cuanto se detecta un código, para
  /// que las siguientes detecciones (llegan varias por segundo) se ignoren.
  bool _isProcessing = false;

  /// True mientras hay otra pantalla encima (menú) o un diálogo abierto.
  bool _hasNavigated = false;
  bool _dialogOpen = false;

  bool get _busy => _isProcessing || _hasNavigated || _dialogOpen;

  @override
  void initState() {
    super.initState();
    // Con un controlador propio, MobileScanner no gestiona el ciclo de vida
    // de la app: lo hacemos aquí para liberar la cámara en segundo plano.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.inactive:
        _stopCamera();
      case AppLifecycleState.resumed:
        // Solo reanudar si esta pantalla está visible y libre; si hay un
        // menú o un diálogo encima, la cámara debe seguir apagada.
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (!_busy && isCurrent) _startCamera();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller.dispose());
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (!mounted) return;
    try {
      await controller.start();
    } catch (e) {
      // start() lanza si ya está iniciando o si el controlador se liberó.
      debugPrint('QRScanner start: $e');
    }
  }

  Future<void> _stopCamera() async {
    try {
      await controller.stop();
    } catch (e) {
      debugPrint('QRScanner stop: $e');
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;

    for (final barcode in capture.barcodes) {
      final qrCodeContent =
          (barcode.rawValue ?? '').replaceAll('\n', '').trim();
      if (qrCodeContent.isNotEmpty) {
        _handleScannedCode(qrCodeContent);
        return;
      }
    }
  }

  Future<void> _handleScannedCode(String qrCodeContent) async {
    if (_busy || !mounted) return;

    // Todo lo que depende de context se lee antes del primer await.
    _isProcessing = true;
    context.read<SerialNumberModel>().setSerialNumber(qrCodeContent);
    context.read<AuthProvider>().resetSession();

    setState(() => numSerie = qrCodeContent);

    await _stopCamera();

    String? error;
    _Destino? destino;
    try {
      destino = await _fetchDestino(qrCodeContent);
      if (destino == null) error = 'Artículo no válido';
    } on TimeoutException {
      error = 'El servidor tardó demasiado en responder. Intenta de nuevo.';
    } on _HttpStatusException catch (e) {
      error = 'No fue posible consultar el artículo (código ${e.code}).';
    } on SocketException {
      error = 'No se pudo conectar con el servidor. Revisa tu conexión.';
    } catch (_) {
      error = 'Artículo no válido';
    }

    if (!mounted) return;

    if (destino != null) {
      await _navigate(destino);
    } else {
      await _mostrarError(error ?? 'Artículo no válido');
    }
  }

  /// Consulta el artículo (SAP, a través de la Intranet) y devuelve el menú a
  /// abrir, o null si no es válido.
  Future<_Destino?> _fetchDestino(String numSerie) async {
    final response = await Api.get(
      '/app-montacargas/articulo',
      {'serie': numSerie},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw _HttpStatusException(response.statusCode);
    }

    final decoded = json.decode(response.body);
    final values = decoded is Map ? decoded['value'] : null;
    if (values is! List) return null;

    for (final item in values) {
      if (item is! Map || item['ItemGroups'] == null) continue;

      final groups = item['ItemGroups'];
      final items = item['Items'];
      final tipo = groups is Map ? (groups['GroupName'] ?? '') : '';
      final assetGroup = items is Map ? (items['AssetGroup'] ?? '') : '';

      if (tipo == 'MONTACARGAS' || assetGroup == 'MO') {
        return _Destino.equipos;
      } else if (tipo == 'BATERIAS' || assetGroup == 'BAT') {
        return _Destino.baterias;
      } else if (tipo == 'CARGADORES' || assetGroup == 'CAR') {
        return _Destino.cargadores;
      }
    }
    return null;
  }

  Future<void> _navigate(_Destino destino) async {
    final Widget page = switch (destino) {
      _Destino.equipos => const menuEquipos(),
      _Destino.baterias => const menuBaterias(),
      _Destino.cargadores => const menuCargadores(),
    };

    _hasNavigated = true;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    // Al volver (si esta pantalla sigue viva) se reactiva el escáner.
    _resetScanner();
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _hasNavigated = false;
      _isProcessing = false;
      _dialogOpen = false;
      numSerie = '';
    });
    _startCamera();
  }

  Future<void> _mostrarError(String mensaje) async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
        title: const Text('Error'),
        content: Text(mensaje, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _resetScanner();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Liberar la cámara cuanto antes; dispose() se encarga del resto.
        if (didPop) _stopCamera();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Escanear QR'),
          actions: [_TorchButton(controller: controller)],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onDetect,
              // El overlay solo se pinta cuando hay vista previa (no encima
              // del mensaje de error).
              overlayBuilder: (context, constraints) =>
                  const IgnorePointer(child: _ScanFrameOverlay()),
              errorBuilder: (context, error) => _ScannerError(
                error: error,
                onRetry: _startCamera,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _StatusBanner(
                  numSerie: numSerie,
                  processing: _isProcessing,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HttpStatusException implements Exception {
  const _HttpStatusException(this.code);
  final int code;
}

/// Botón de linterna; se oculta si el dispositivo no tiene flash.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (!state.isInitialized ||
            !state.isRunning ||
            state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }
        final on = state.torchState == TorchState.on;
        return IconButton(
          tooltip: on ? 'Apagar linterna' : 'Encender linterna',
          icon: Icon(on ? Icons.flash_on : Icons.flash_off),
          onPressed: () async {
            try {
              await controller.toggleTorch();
            } catch (e) {
              debugPrint('QRScanner torch: $e');
            }
          },
        );
      },
    );
  }
}

/// Máscara oscura con un recuadro central para orientar al técnico.
class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.biggest.shortestSide * 0.7).clamp(180.0, 300.0);
        final rect = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero) - const Offset(0, 30),
          width: side,
          height: side,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _FramePainter(rect)),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: (rect.top - 56).clamp(8.0, double.infinity),
              child: const Text(
                'Coloca el código QR dentro del recuadro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(mask, Paint()..color = const Color(0x99000000));

    // Esquinas naranjas.
    final paint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    final l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    canvas
      ..drawLine(Offset(l, t + len), Offset(l, t + 12), paint)
      ..drawArc(Rect.fromLTWH(l, t, 24, 24), 3.1416, 1.5708, false, paint)
      ..drawLine(Offset(l + 12, t), Offset(l + len, t), paint)
      ..drawLine(Offset(r - len, t), Offset(r - 12, t), paint)
      ..drawArc(Rect.fromLTWH(r - 24, t, 24, 24), -1.5708, 1.5708, false, paint)
      ..drawLine(Offset(r, t + 12), Offset(r, t + len), paint)
      ..drawLine(Offset(r, b - len), Offset(r, b - 12), paint)
      ..drawArc(Rect.fromLTWH(r - 24, b - 24, 24, 24), 0, 1.5708, false, paint)
      ..drawLine(Offset(r - 12, b), Offset(r - len, b), paint)
      ..drawLine(Offset(l + len, b), Offset(l + 12, b), paint)
      ..drawArc(Rect.fromLTWH(l, b - 24, 24, 24), 1.5708, 1.5708, false, paint)
      ..drawLine(Offset(l, b - 12), Offset(l, b - len), paint);
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.rect != rect;
}

/// Tarjeta inferior: "Escaneando..." o la serie que se está consultando.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.numSerie, required this.processing});

  final String numSerie;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (processing)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              const Icon(Icons.qr_code_scanner, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                numSerie.isEmpty
                    ? 'Escaneando...'
                    : (processing
                        ? 'Consultando serie: $numSerie'
                        : 'Serie: $numSerie'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje cuando la cámara no puede iniciarse (p. ej. permiso denegado).
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.background,
      child: EmptyState(
        icon: denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
        message: denied
            ? 'Sin permiso para usar la cámara.\nActívalo en los ajustes del teléfono.'
            : 'No se pudo iniciar la cámara.',
        onRetry: denied ? null : onRetry,
      ),
    );
  }
}
