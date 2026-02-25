import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;

  // Ukuran kotak scan
  final double _scanWindowSize = 300.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // 1. Reset logika loading jika 'nyangkut'
    setState(() {
      _isProcessing = false;
    });

    try {
      // 2. Restart Kamera
      await _controller.stop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Me-refresh kamera..."),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Beri jeda agar hardware kamera release
      await Future.delayed(const Duration(milliseconds: 200));
      await _controller.start();
    } catch (e) {
      debugPrint("Gagal refresh kamera: $e");
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue == null) return;

    // ---------------------------------------------------------
    // LOGIKA PARSING (SUDAH BENAR & KUAT)
    // ---------------------------------------------------------
    String sanitized = rawValue
        .replaceAll('\n', ' ')
        .replaceAll('\t', ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    final String serialNumber = sanitized.split(' ').last;

    debugPrint("📸 Raw Scan: '$rawValue'");
    debugPrint("🔍 Serial Final: '$serialNumber'");

    // DEBUG VISUAL: Tampilkan SnackBar agar terlihat di Layar HP
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Raw: '$rawValue'\nResult: '$serialNumber'"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    // ---------------------------------------------------------

    setState(() {
      _isProcessing = true;
    });

    try {
      // Tampilkan Loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      // Panggil API
      final data = await _apiService.getItem(serialNumber);

      if (mounted) {
        Navigator.pop(context); // Tutup Loading

        // DEBUG: Cek apa isi data sebenarnya dari API
        debugPrint("📦 API DATA: $data");

        // Simpan ke History
        await _saveToHistory(data);

        _showResultSheet(data); // Tampilkan Data
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup Loading

        // Cek jika error koneksi
        final errorMessage = e.toString();
        if (errorMessage.contains("SocketException") ||
            errorMessage.contains("Connection refused") ||
            errorMessage.contains("Error Koneksi") || // Dari ApiService
            errorMessage.contains("Gagal menghubungi server")) {
          _showConnectionErrorDialog(errorMessage);
        } else {
          // Error biasa
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: $errorMessage"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Beri jeda sedikit sebelum bisa scan lagi
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    }
  }

  void _showConnectionErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gagal Terhubung"),
        content: Text(
          "Tidak dapat menghubungi server.\nPastikan IP Server benar dan HP terhubung ke WiFi yang sama.\n\nDetail:\n$error",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tutup"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: const Text("Buka Settings"),
          ),
        ],
      ),
    );
  }

  // --- LOGIC HISTORY ---
  Future<void> _saveToHistory(Map<String, dynamic> item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList('scan_history') ?? [];

      // Encode item ke JSON String
      String jsonItem = jsonEncode(item);

      // Hapus jika duplikat (move to top)
      // Kita cek berdasarkan serial_number agar tidak duplikat
      history.removeWhere((element) {
        final decoded = jsonDecode(element);
        return decoded['serial_number'] == item['serial_number'];
      });

      // Insert ke paling atas
      history.insert(0, jsonItem);

      // Limit 50 item
      if (history.length > 50) {
        history = history.sublist(0, 50);
      }

      await prefs.setStringList('scan_history', history);
    } catch (e) {
      debugPrint("Gagal simpan history: $e");
    }
  }

  void _showHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('scan_history') ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Riwayat Scan",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Text(
                        "Belum ada riwayat scan",
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = jsonDecode(history[index]);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            child: const Icon(
                              Icons.qr_code_2,
                              color: Colors.indigo,
                            ),
                          ),
                          title: Text(
                            item['name'] ?? 'Unknown Item',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            "${item['serial_number']} • ${item['room'] ?? '-'}",
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(context); // Tutup history
                            _showResultSheet(item); // Buka detail
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // --- UI DETAIL BARANG ---
  void _showResultSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Content List
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        // --- IMAGE SECTION ---
                        Center(
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                (item['image_url'] == null ||
                                    item['image_url'].toString().isEmpty)
                                ? const Icon(
                                    Icons.image_not_supported,
                                    size: 80,
                                    color: Colors.grey,
                                  )
                                : GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => Dialog(
                                          backgroundColor: Colors.black,
                                          insetPadding: EdgeInsets.zero,
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: InteractiveViewer(
                                                  panEnabled: true,
                                                  minScale: 0.5,
                                                  maxScale: 4.0,
                                                  child: Image.network(
                                                    item['image_url'],
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 40,
                                                right: 20,
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 30,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        item['image_url'],
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        (loadingProgress
                                                                .expectedTotalBytes ??
                                                            1)
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.broken_image,
                                                size: 80,
                                                color: Colors.grey,
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                          ),
                        ),

                        // --- HEADER SECTION ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                "${item['name'] ?? 'Tidak Ada Nama'}",
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(item['status']),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- KEY INFO CARD (GRID) ---
                        Card(
                          elevation: 0,
                          color: Colors.grey.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildGridItem(
                                        'Serial Number',
                                        item['serial_number'],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildGridItem(
                                        'Asset Number',
                                        item['asset_number'],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildGridItem(
                                        'Ruangan',
                                        item['room'] ??
                                            item['room_name'] ??
                                            item['location'],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildGridItem(
                                        'Kondisi',
                                        item['condition'],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                        _buildSectionTitle("Detail Spesifikasi"),
                        const SizedBox(height: 8),

                        // --- DETAILED LIST ---
                        _buildDetailRow(
                          'Merk / Tipe',
                          "${item['brand'] ?? '-'} / ${item['type'] ?? '-'}",
                        ),
                        _buildDetailRow('Kategori', item['category']),
                        _buildDetailRow(
                          'Jumlah',
                          "${item['quantity'] ?? '0'} Unit",
                        ),

                        const SizedBox(height: 20),
                        _buildSectionTitle("Informasi Administratif"),
                        const SizedBox(height: 8),

                        _buildDetailRow(
                          'Tahun Perolehan',
                          item['acquisition_year'],
                        ),
                        _buildDetailRow('Sumber Dana', item['source']),
                        _buildDetailRow(
                          'Kelompok Fiskal',
                          item['fiscal_group'],
                        ),
                        _buildDetailRow(
                          'Tanggal Mulai Pakai',
                          item['usage_start_date'],
                        ),

                        const SizedBox(height: 30),

                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Tutup",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildGridItem(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 4),
        Text(
          "${value ?? '-'}",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2, // Label width
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3, // Value width
            child: Text(
              "${value ?? '-'}",
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    String text = status?.toLowerCase() ?? 'unknown';
    Color color;
    Color bgColor;

    if (text.contains('available')) {
      color = Colors.green.shade700;
      bgColor = Colors.green.shade50;
    } else if (text.contains('borrowed')) {
      color = Colors.red.shade700;
      bgColor = Colors.red.shade50;
    } else {
      color = Colors.orange.shade800;
      bgColor = Colors.orange.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status ?? 'Unknown',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Area kotak tengah untuk fokus scan
    final scanWindowRect = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: _scanWindowSize,
      height: _scanWindowSize,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Scanner',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black26,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: _showHistory,
            tooltip: 'Riwayat',
          ),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn ? Colors.amber : Colors.white,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. Full Screen Camera
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindowRect,
            onDetect: _onDetect,
          ),

          // 2. Modern Overlay (Glassmorphism Effect)
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

          // 3. UI Elements (Text Helper)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Arahkan kamera ke QR Code",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Tombol Refresh Floating Modern
                FloatingActionButton.small(
                  backgroundColor: Colors.white24,
                  elevation: 0,
                  onPressed: _handleRefresh,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),

          // 4. Loading Indicator Overlay
          if (_isProcessing)
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.7),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom Painter untuk Overlay Modern
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
    final double width = size.width;
    final double height = size.height;
    final double cutOutWidth = cutOutSize;
    final double cutOutHeight = cutOutSize;

    final Paint backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    // Path untuk background berlubang (Clip Operation)
    final Path backgroundPath = Path()
      ..fillType = PathFillType
          .evenOdd // Hapus bagian tengah
      ..addRect(Rect.fromLTWH(0, 0, width, height)) // Full screen
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(width / 2, height / 2),
            width: cutOutWidth,
            height: cutOutHeight,
          ),
          Radius.circular(borderRadius),
        ),
      );

    canvas.drawPath(backgroundPath, backgroundPaint);

    // Gambar Border (Sudut-sudut)
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round; // Ujung bulat biar modern

    final double halfWidth = cutOutWidth / 2;
    final double halfHeight = cutOutHeight / 2;
    final double centerX = width / 2;
    final double centerY = height / 2;

    // Kiri Atas
    canvas.drawPath(
      Path()
        ..moveTo(centerX - halfWidth, centerY - halfHeight + borderLength)
        ..lineTo(centerX - halfWidth, centerY - halfHeight + borderRadius)
        ..arcToPoint(
          Offset(centerX - halfWidth + borderRadius, centerY - halfHeight),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(centerX - halfWidth + borderLength, centerY - halfHeight),
      borderPaint,
    );

    // Kanan Atas
    canvas.drawPath(
      Path()
        ..moveTo(centerX + halfWidth - borderLength, centerY - halfHeight)
        ..lineTo(centerX + halfWidth - borderRadius, centerY - halfHeight)
        ..arcToPoint(
          Offset(centerX + halfWidth, centerY - halfHeight + borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(centerX + halfWidth, centerY - halfHeight + borderLength),
      borderPaint,
    );

    // Kanan Bawah
    canvas.drawPath(
      Path()
        ..moveTo(centerX + halfWidth, centerY + halfHeight - borderLength)
        ..lineTo(centerX + halfWidth, centerY + halfHeight - borderRadius)
        ..arcToPoint(
          Offset(centerX + halfWidth - borderRadius, centerY + halfHeight),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(centerX + halfWidth - borderLength, centerY + halfHeight),
      borderPaint,
    );

    // Kiri Bawah
    canvas.drawPath(
      Path()
        ..moveTo(centerX - halfWidth + borderLength, centerY + halfHeight)
        ..lineTo(centerX - halfWidth + borderRadius, centerY + halfHeight)
        ..arcToPoint(
          Offset(centerX - halfWidth, centerY + halfHeight - borderRadius),
          radius: Radius.circular(borderRadius),
          clockwise: true,
        )
        ..lineTo(centerX - halfWidth, centerY + halfHeight - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
