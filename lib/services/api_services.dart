// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/product.dart';

class ApiService {
  static const String _defaultBaseUrl = 'https://geminibackend.uoturker.workers.dev';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static final http.Client _client = () {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true;
      };
    return IOClient(ioClient);
  }();

  static String get _cleanBaseUrl {
    final url = baseUrl.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<dynamic> predictProductFromImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Seçilen görsel dosyası boş (0 byte). Lütfen tekrar deneyin.');
      }

      print('Yüklenecek dosya boyutu: ${bytes.length} bytes');

      final String base64Image = base64Encode(bytes);

      String mimeType = 'image/jpeg';
      final pathLower = imageFile.path.toLowerCase();
      if (pathLower.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (pathLower.endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      // Doğrudan /predict endpoint'i çağrılır
      final Uri targetUri = Uri.parse('$_cleanBaseUrl/predict');
      print('İstek atılan adres: $targetUri');

      final response = await _client.post(
        targetUri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'mime_type': mimeType,
        }),
      );

      print('Prediction response status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        String errorMessage;
        try {
          final errorJson = jsonDecode(response.body);
          errorMessage = errorJson['error'] ?? 'Sunucu Hatası';
        } catch (_) {
          errorMessage = 'Sunucu Hata Döndürdü (${response.statusCode}): ${response.body}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('AI Tahmin Hatası: $e');
      rethrow;
    }
  }

  static Future<bool> createProduct(Product product) async {
    try {
      final Uri targetUri = Uri.parse('$_cleanBaseUrl/products');

      final response = await _client.post(
        targetUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(product.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Ürün Kaydetme Hatası: $e');
      return false;
    }
  }

  static Future<List<Product>> getProducts() async {
    try {
      final Uri targetUri = Uri.parse('$_cleanBaseUrl/products');

      final response = await _client.get(targetUri);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded.map((json) => Product.fromJson(json)).toList();
        }

        if (decoded is Map && decoded['products'] is List) {
          return (decoded['products'] as List)
              .map((json) => Product.fromJson(json))
              .toList();
        }
      }

      print('Ürünler getirilemedi. Durum kodu: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Ürün Listeleme Hatası: $e');
      return [];
    }
  }
}