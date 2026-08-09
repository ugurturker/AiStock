// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/api_services.dart';
import '../services/local_database_service.dart'; // Isar servis sınıfınızın yolu (projenize göre düzenleyebilirsiniz)

// Her bir ürün formunun kendi controller setini tutan yardımcı sınıf
class ProductFormItem {
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController buyPriceController;
  final TextEditingController marketPriceController;
  final TextEditingController shopSellPriceController;
  final TextEditingController stockController;
  double? confidenceScore;

  ProductFormItem({
    required String name,
    required String category,
    required String buyPrice,
    required String marketPrice,
    required String shopSellPrice,
    required String stock,
    this.confidenceScore,
  }) : nameController = TextEditingController(text: name),
       categoryController = TextEditingController(text: category),
       buyPriceController = TextEditingController(text: buyPrice),
       marketPriceController = TextEditingController(text: marketPrice),
       shopSellPriceController = TextEditingController(text: shopSellPrice),
       stockController = TextEditingController(text: stock);

  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    buyPriceController.dispose();
    marketPriceController.dispose();
    shopSellPriceController.dispose();
    stockController.dispose();
  }
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Çoklu ürün formları için liste yapısı
  List<ProductFormItem> _productForms = [];

  File? _selectedImage;
  bool _isLoadingAi = false;
  String? _analyzedAtTime;

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isLoadingAi = true;
        });

        dynamic aiResult;
        String? errorMessage;

        try {
          aiResult = await ApiService.predictProductFromImage(_selectedImage!);
        } catch (e) {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          print('TAM HATA MESAJI: $errorMessage');
        }

        setState(() {
          _isLoadingAi = false;

          for (var item in _productForms) {
            item.dispose();
          }
          _productForms = [];

          if (errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('AI Analiz Hatası: $errorMessage'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6),
              ),
            );
            return;
          }

          if (aiResult != null) {
            List<Map<String, dynamic>> itemsList = [];

            if (aiResult is List) {
              itemsList = aiResult
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            } else if (aiResult is Map) {
              itemsList = [Map<String, dynamic>.from(aiResult)];
            }

            if (itemsList.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Görselde herhangi bir ürün tespit edilemedi.'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            for (var productData in itemsList) {
              _productForms.add(
                ProductFormItem(
                  name: productData['name']?.toString() ?? '',
                  category: productData['category']?.toString() ?? '',
                  buyPrice: productData['buy_price']?.toString() ?? '0.0',
                  marketPrice: productData['market_price']?.toString() ?? '0.0',
                  shopSellPrice:
                      productData['shop_sell_price']?.toString() ?? '0.0',
                  stock: productData['stock']?.toString() ?? '1',
                  confidenceScore: productData['confidence'] != null
                      ? double.tryParse(productData['confidence'].toString())
                      : null,
                ),
              );
            }
            _analyzedAtTime = DateTime.now().toString().substring(11, 16);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AI analizi yanıt veremedi.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Görsel seçim veya AI analiz hatası: $e');
      setState(() => _isLoadingAi = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Kameradan Çek (Mobil)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndAnalyzeImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Galeriden / Dosyadan Seç (PC & Mobil)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAndAnalyzeImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    for (var item in _productForms) {
      item.dispose();
    }
    super.dispose();
  }

  // GÜNCELLENEN KISIM: Uzak sunucu yerine doğrudan Isar yerel veritabanına kayıt
  Future<void> _saveAllProducts() async {
    if (_formKey.currentState!.validate()) {
      int successCount = 0;

      try {
        List<Product> productsToSave = [];

        for (var item in _productForms) {
          final newProduct = Product(
            name: item.nameController.text,
            category: item.categoryController.text,
            buyPrice: double.tryParse(item.buyPriceController.text) ?? 0.0,
            marketPrice: double.tryParse(item.marketPriceController.text) ?? 0.0,
            shopSellPrice:
                double.tryParse(item.shopSellPriceController.text) ?? 0.0,
            stock: int.tryParse(item.stockController.text) ?? 1,
            createdAt: DateTime.now().toIso8601String(),
          );
          productsToSave.add(newProduct);
        }

        // Isar veritabanı yazma transaction bloğu
        await LocalDatabaseService.db.writeTxn(() async {
          for (var product in productsToSave) {
            await LocalDatabaseService.db.products.put(product);
            successCount++;
          }
        });
      } catch (e) {
        print('Isar Veritabanı Kayıt Hatası: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount/${_productForms.length} ürün başarıyla yerel Isar veritabanına kaydedildi!',
            ),
            backgroundColor: successCount > 0 ? Colors.green : Colors.red,
          ),
        );
        if (successCount > 0) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Destekli Çoklu Ürün Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            ),
                    ),
                    if (_isLoadingAi)
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showImageSourceDialog,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Ürün Görseli Yükle ve Analiz Et'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dinamik Olarak Üretilen Ürün Kartları ve Formları
              if (_productForms.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Henüz analiz edilen ürün yok.\nLütfen bir görsel yükleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                ..._productForms.asMap().entries.map((entry) {
                  int index = entry.key;
                  ProductFormItem item = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ürün #${index + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              if (item.confidenceScore != null)
                                Chip(
                                  backgroundColor: Colors.green[100],
                                  label: Text(
                                    'Güven: %${(item.confidenceScore! * 100).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_analyzedAtTime != null)
                            Text(
                              'Analiz Zamanı: $_analyzedAtTime',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          const Divider(),
                          const SizedBox(height: 8),

                          TextFormField(
                            controller: item.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Ürün Adı',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Ürün adı boş olamaz' : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: item.categoryController,
                            decoration: const InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Kategori boş olamaz' : null,
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: item.buyPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Alış Fiyatı (TL)',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Giriniz' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: item.marketPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Netten Tahmini Fiyat',
                                    border: OutlineInputBorder(),
                                    helperText: 'Diğer satıcıların fiyatı',
                                  ),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Giriniz' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: item.shopSellPriceController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Dükkan Satış Fiyatı',
                                    border: OutlineInputBorder(),
                                    helperText: 'Sizin satış fiyatınız',
                                  ),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Giriniz' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: item.stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Stok Adedi',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) =>
                                      value!.isEmpty ? 'Giriniz' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              if (_productForms.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saveAllProducts,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Tüm Ürünleri Veritabanına Kaydet (${_productForms.length} Adet)',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}