import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Default jika belum disetting user
  static const String _defaultUrl = 'https://aorukudomain.my.id';

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Ambil dari storage, kalau null pakai default
    // Pastikan tidak ada trailing slash '/' di akhir biar rapi saat digabung
    String url = prefs.getString('base_url') ?? _defaultUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<String?> login(String email, String password) async {
    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/api/login');

    try {
      final response = await http.post(
        url,
        body: {'email': email, 'password': password},
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Task 1: Setup Token Storage
        // Simpan token ke local storage (SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        // Debug print untuk memastikan token tersimpan
        print(
          "✅ Login Berhasil. Token tersimpan: ${token.substring(0, 10)}...",
        );

        return token;
      } else {
        throw Exception(
          'Login gagal: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Gagal menghubungi server ($baseUrl): $e');
    }
  }

  // Task 2: Fix Scan Function (Add Auth Header)
  Future<Map<String, dynamic>> getItem(String serialNumber) async {
    // 1. Ambil token dari storage
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Token tidak ditemukan, silakan login ulang.');
    }

    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/api/scan/$serialNumber');

    // 2. Siapkan headers
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token', // <--- INI KUNCINYA
    };

    try {
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data'];
      } else if (response.statusCode == 401) {
        throw Exception('Sesi berakhir (401). Silakan login ulang.');
      } else if (response.statusCode == 404) {
        throw Exception('Barang tidak ditemukan.');
      } else {
        throw Exception('Gagal load barang: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Koneksi/API ($baseUrl): $e');
    }
  }
}
