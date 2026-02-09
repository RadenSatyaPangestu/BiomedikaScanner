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
      'Authorization': 'Bearer $token',
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

  // Task 3: Add Create and Update methods
  // Method Helper untuk Multipart Request (Create/Update)
  Future<void> _submitMultipart({
    required String method, // 'POST' or 'PUT' (simulated)
    required String urlStr,
    required Map<String, dynamic> data,
    String? imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Token tidak ditemukan');

    var uri = Uri.parse(urlStr);
    var request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    // Handle Method Spoofing for PUT
    if (method == 'PUT') {
      request.fields['_method'] = 'PUT';
    }

    // Add Fields
    data.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // Add Image
    if (imagePath != null && imagePath.isNotEmpty) {
      // Cek apakah file benar-benar ada/valid local path
      if (!imagePath.startsWith('http')) {
        request.files.add(
          await http.MultipartFile.fromPath('image_path', imagePath),
        );
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error Upload: $e');
    }
  }

  Future<void> createItem(
    Map<String, dynamic> data, {
    String? imagePath,
  }) async {
    final baseUrl = await _getBaseUrl();
    await _submitMultipart(
      method: 'POST',
      urlStr: '$baseUrl/api/items',
      data: data,
      imagePath: imagePath,
    );
  }

  Future<void> updateItem(
    String id,
    Map<String, dynamic> data, {
    String? imagePath,
  }) async {
    final baseUrl = await _getBaseUrl();
    await _submitMultipart(
      method: 'PUT',
      urlStr: '$baseUrl/api/items/$id',
      data: data,
      imagePath: imagePath,
    );
  }

  Future<void> deleteItem(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Token tidak ditemukan');

    final baseUrl = await _getBaseUrl();
    final url = Uri.parse('$baseUrl/api/items/$id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Gagal hapus barang: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error Delete Item: $e');
    }
  }

  Future<List<dynamic>> getRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final baseUrl = await _getBaseUrl();

    final response = await http.get(
      Uri.parse('$baseUrl/api/rooms'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Adjust depending on whether API returns wrapped data or direct list
      if (json is Map && json.containsKey('data')) {
        return json['data'];
      } else if (json is List) {
        return json;
      }
      return [];
    }
    return [];
  }

  Future<List<dynamic>> fetchRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/rooms'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json.containsKey('data')) {
          return json['data'];
        } else if (json is List) {
          return json;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map && json.containsKey('data')) {
          return json['data'];
        } else if (json is List) {
          return json;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getItems({
    int page = 1,
    String search = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) throw Exception('Token tidak ditemukan');

    final baseUrl = await _getBaseUrl();
    final queryParams = {
      'page': page.toString(),
      if (search.isNotEmpty) 'search': search,
    };

    final url = Uri.parse(
      '$baseUrl/api/items',
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Handle Wrapped Response (e.g. { "success": true, "data": { "current_page": 1, ... } })
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final innerData = decoded['data'];

          // If 'data' is a Map, it IS the pagination object (wrapped)
          if (innerData is Map<String, dynamic>) {
            return innerData;
          }
          // If 'data' is a List, then the outer object IS the pagination wrapper (unwrapped/standard)
          return decoded;
        }

        return decoded;
      } else {
        throw Exception('Gagal load items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error Get Items: $e');
    }
  }
}
