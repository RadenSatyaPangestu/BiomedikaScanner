import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  final String _defaultUrl = 'https://bme.aorukudomain.my.id';

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('base_url') ?? _defaultUrl;
    });
  }

  Future<void> _saveAndTestConnection() async {
    final newUrl = _urlController.text.trim();

    // Validasi basic
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL tidak boleh kosong')));
      return;
    }

    if (!newUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL harus diawali http:// atau https://'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Test koneksi (Ping sederhana)
      // Kita coba hit endpoint root atau api yang ringan.
      // Karena kita tidak tahu endpoint root, kita coba panggil login tanpa body
      // atau endpoint yang diharapkan selalu ada.
      // Namun aman-nya kita bisa request ke base url root (/)
      // Asumsi server Laravel menyala, hit '/' biasanya return welcome page atau 200.
      final uri = Uri.parse(newUrl);

      // Timeout 5 detik
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 500) {
        // Anggap sukses jika server merespon (bahkan 404 pun berarti server nyala,
        // tapi idealnya 200 OK. Laravel default '/' is 200 OK).

        // Simpan
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('base_url', newUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Koneksi Sukses! URL disimpan: $newUrl'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Kembali ke screen sebelumnya
        }
      } else {
        throw Exception('Server merespon dengan kode: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Koneksi Gagal'),
            content: Text(
              'Tidak dapat menghubungi server:\n$newUrl\n\nError: $e',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Server Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Konfigurasi Server",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Masukkan Base URL server Laravel Anda (termasuk port jika ada).",
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://bme.aorukudomain.my.id',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
                helperText: "Pastikan HP dan Laptop di jaringan yang sama",
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveAndTestConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading ? "Testing Koneksi..." : "Simpan & Test Koneksi",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
