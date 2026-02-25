import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'batch_result_screen.dart';

class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({super.key});

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ApiService _apiService = ApiService();

  Set<String> scannedIds = {};
  bool _isLoading = false;

  final double _scanWindowSize = 300.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isLoading) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    // Parsing logic sama seperti scan reguler
    String sanitized = rawValue
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final String serialNumber = sanitized.split(' ').last;

    if (!scannedIds.contains(serialNumber)) {
      setState(() {
        scannedIds.add(serialNumber);
      });

      // Haptic feedback & visual feedback
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${scannedIds.length} QR Terscan: $serialNumber"),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processBatch() async {
    if (scannedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Belum ada QR Code yang di-scan."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Menjalankan fetch API secara paralel (Future.wait)
      List<Future<Map<String, dynamic>?>> fetchTasks = scannedIds.map((
        id,
      ) async {
        try {
          return await _apiService.getItem(id);
        } catch (e) {
          debugPrint("Gagal fetch ID $id: $e");
          return null; // Ignore errors atau handle gracefully jika barang kosong
        }
      }).toList();

      final results = await Future.wait(fetchTasks);

      // Filter out barang yang null (gagal di proses / tidak ketemu)
      final validItems = results.whereType<Map<String, dynamic>>().toList();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (validItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Semua ID tidak ditemukan atau gagal diambil."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Buka layar result dengan data list barang
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BatchResultScreen(items: validItems),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowRect = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: _scanWindowSize,
      height: _scanWindowSize,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Batch Scan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black45,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Reset Data',
            onPressed: () {
              setState(() {
                scannedIds.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Daftar scan di-reset!"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindowRect,
            onDetect: _onDetect,
          ),

          // Modern Overlay Glassmorphism Template (sama dari fitur lama)
          CustomPaint(
            painter: ModernScannerOverlayPainter(
              borderColor: Colors.white,
              borderRadius: 24,
              borderLength: 40,
              borderWidth: 4,
              cutOutSize: _scanWindowSize,
              overlayColor: const Color.fromRGBO(0, 0, 0, 0.6),
            ),
            child: Container(),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      "Memproses data...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processBatch,
                  icon: const Icon(
                    Icons.auto_awesome_motion,
                    color: Colors.white,
                  ),
                  label: Text(
                    "Tampilkan Data (${scannedIds.length} item)",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                ),
              ),
            ),
    );
  }
}

// Custom Painter untuk Overlay Modern (Disesuaikan dari versi Scan Screen reguler)
class ModernScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  ModernScannerOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.overlayColor,
    required this.borderRadius,
    required this.borderLength,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = overlayColor;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      );

    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutOutPath,
    );
    canvas.drawPath(path, backgroundPaint);

    final borderRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );
    final borderPath = Path();

    // Top left
    borderPath.moveTo(borderRect.left, borderRect.top + borderLength);
    borderPath.lineTo(borderRect.left, borderRect.top + borderRadius);
    borderPath.arcTo(
      Rect.fromCircle(
        center: Offset(
          borderRect.left + borderRadius,
          borderRect.top + borderRadius,
        ),
        radius: borderRadius,
      ),
      180 * (3.14159 / 180),
      90 * (3.14159 / 180),
      false,
    );
    borderPath.lineTo(borderRect.left + borderLength, borderRect.top);

    // Top right
    borderPath.moveTo(borderRect.right - borderLength, borderRect.top);
    borderPath.lineTo(borderRect.right - borderRadius, borderRect.top);
    borderPath.arcTo(
      Rect.fromCircle(
        center: Offset(
          borderRect.right - borderRadius,
          borderRect.top + borderRadius,
        ),
        radius: borderRadius,
      ),
      270 * (3.14159 / 180),
      90 * (3.14159 / 180),
      false,
    );
    borderPath.lineTo(borderRect.right, borderRect.top + borderLength);

    // Bottom right
    borderPath.moveTo(borderRect.right, borderRect.bottom - borderLength);
    borderPath.lineTo(borderRect.right, borderRect.bottom - borderRadius);
    borderPath.arcTo(
      Rect.fromCircle(
        center: Offset(
          borderRect.right - borderRadius,
          borderRect.bottom - borderRadius,
        ),
        radius: borderRadius,
      ),
      0,
      90 * (3.14159 / 180),
      false,
    );
    borderPath.lineTo(borderRect.right - borderLength, borderRect.bottom);

    // Bottom left
    borderPath.moveTo(borderRect.left + borderLength, borderRect.bottom);
    borderPath.lineTo(borderRect.left + borderRadius, borderRect.bottom);
    borderPath.arcTo(
      Rect.fromCircle(
        center: Offset(
          borderRect.left + borderRadius,
          borderRect.bottom - borderRadius,
        ),
        radius: borderRadius,
      ),
      90 * (3.14159 / 180),
      90 * (3.14159 / 180),
      false,
    );
    borderPath.lineTo(borderRect.left, borderRect.bottom - borderLength);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
