import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteUploadService {
  static const String _defaultUrl = 'https://aorukudomain.my.id';

  Future<String> _getUploadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String baseUrl = prefs.getString('base_url') ?? _defaultUrl;

    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    return '$baseUrl/api/remote-upload';
  }

  Future<bool> uploadImage(
    File imageFile,
    String qrToken,
    String authToken,
  ) async {
    try {
      final uploadUrl = await _getUploadUrl();
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Headers
      request.headers.addAll({
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
      });

      // Fields
      request.fields['token'] = qrToken;

      // File
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      print('🚀 Uploading to $uploadUrl ...');
      print('🔑 Token used: ${authToken.substring(0, 5)}...');
      print('📦 File path: ${imageFile.path}');

      // Send with explicit timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('❌ Upload Timeout after 60 seconds');
          throw Exception('Upload Timeout'); // Trigger catch block
        },
      );
      var response = await http.Response.fromStream(streamedResponse);

      print('📡 Response Status: ${response.statusCode}');
      print('📜 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('❌ Upload Failed: [${response.statusCode}] ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during upload: $e');
      return false;
    }
  }
}
