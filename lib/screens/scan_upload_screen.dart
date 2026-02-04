import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/remote_upload_service.dart';

class ScanUploadScreen extends StatefulWidget {
  const ScanUploadScreen({super.key});

  @override
  State<ScanUploadScreen> createState() => _ScanUploadScreenState();
}

class _ScanUploadScreenState extends State<ScanUploadScreen> {
  // State 1: Scanning, 2: Capture/Compress, 3: Uploading, 4: Success
  int _currentState = 1;
  String? _qrToken;
  File? _compressedImage;
  final RemoteUploadService _uploadService = RemoteUploadService();
  bool _isProcessing = false;

  // Gunakan GlobalKey untuk mengakses controller jika perlu, atau manage di sini.
  // MobileScannerController sebaiknya di-recreate jika ngadat, tapi start/stop cukup biasanya.
  late MobileScannerController controller;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _restartCamera() async {
    await controller.stop();
    // Beri jeda sedikit agar resource kamera release
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      // Opsional: dispose dan buat baru jika benar-benar macet/hitam
      // controller.dispose();
      // _initializeController();
      // setState(() {});
      await controller.start();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        _handleQrCode(code);
      }
    }
  }

  Future<void> _handleQrCode(String rawCode) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Decode JSON: {"action":"upload", "token":"UUID..."}
      final Map<String, dynamic> data = jsonDecode(rawCode);

      if (data['action'] == 'upload' && data['token'] != null) {
        _qrToken = data['token'];
        // Stop kamera sebelum pindah ke Image Picker agar tidak konflik resource kamera
        await controller.stop();

        // Lanjut ke State 2: Capture
        if (mounted) {
          await _captureImage();
        }
      } else {
        _showErrorSnackBar('QR Code tidak valid untuk upload.');
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Format QR Code salah: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _captureImage() async {
    setState(() {
      _currentState = 2; // State Capture & Compress
    });

    try {
      final ImagePicker picker = ImagePicker();
      // Otomatis buka kamera
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        await _compressImage(File(photo.path));
      } else {
        // User cancel foto, restart scanner lagi
        setState(() {
          _currentState = 1;
          _isProcessing = false;
        });
        // Restart scanner camera
        await controller.start();
      }
    } catch (e) {
      _showErrorSnackBar('Gagal membuka kamera: $e');
      setState(() {
        _currentState = 1;
        _isProcessing = false;
      });
      await controller.start();
    }
  }

  Future<void> _compressImage(File file) async {
    try {
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = path.join(
        dir.absolute.path,
        "temp_${DateTime.now().millisecondsSinceEpoch}.jpg",
      );

      var result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 800,
        minHeight: 800,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        _compressedImage = File(result.path);
        // Langsung upload tanpa menunggu user
        await _uploadImage();
      } else {
        throw Exception("Gagal kompresi gambar.");
      }
    } catch (e) {
      _showErrorSnackBar('Error kompresi: $e');
      setState(() {
        _currentState = 1;
        _isProcessing = false;
      });
      await controller.start();
    }
  }

  Future<void> _uploadImage() async {
    setState(() {
      _currentState = 3; // State Uploading
    });

    if (_compressedImage != null && _qrToken != null) {
      // 1. Ambil Token Autentikasi
      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString('token');

      if (authToken == null) {
        if (!mounted) return;
        _showErrorSnackBar('Sesi berakhir (Token null). Silakan login ulang.');

        setState(() {
          _currentState = 1;
          _isProcessing = false;
        });
        await controller.start();
        return;
      }

      bool success = await _uploadService.uploadImage(
        _compressedImage!,
        _qrToken!,
        authToken,
      );

      if (!mounted) return;

      if (success) {
        if (!mounted) return;
        // Jika user sudah cancel/pindah state saat nunggu, abaikan
        if (_currentState != 3) return;

        setState(() {
          _currentState = 4; // State Success
        });
      } else {
        if (!mounted) return;
        if (_currentState != 3) return;
        _showRetryDialog();
      }
    }
  }

  void _showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User harus pilih aksi
      builder: (context) => AlertDialog(
        title: const Text('Gagal Upload'),
        content: const Text(
          'Terjadi kesalahan saat mengupload gambar. Coba lagi atau foto ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              // Kembali ke scan mode
              setState(() {
                _currentState = 1;
                _isProcessing = false;
              });
              await controller.start();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              // Coba upload ulang file yang sama (Retry Network)
              await _uploadImage();
            },
            child: const Text('Coba Upload Lagi'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR & Upload"),
        actions: [
          // Tombol Refresh Kamera
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Kamera",
            onPressed: _restartCamera,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentState) {
      case 1: // Scanning
        return Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onDetect),
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Arahkan ke QR Code di Laptop",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 2: // Capture & Compress (Loading)
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Memproses Gambar..."),
            ],
          ),
        );
      case 3: // Uploading
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text("Mengupload ke Laptop..."),
              const SizedBox(height: 8),
              const Text(
                "Mohon tunggu sebentar",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  // User memaksa batal
                  setState(() {
                    _currentState = 1;
                    _isProcessing = false;
                  });
                  controller.start();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Batalkan"),
              ),
            ],
          ),
        );
      case 4: // Success
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text(
                "Upload Berhasil!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "File sudah diterima di laptop.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Reset ke awal (Scan lagi)
                    setState(() {
                      _currentState = 1;
                      _isProcessing = false;
                      _qrToken = null;
                      _compressedImage = null;
                    });
                    controller.start();
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("Upload Lagi"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Selesai (Kembali)"),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
