import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:stok_ai/services/local_database_service.dart';
import '../models/product.dart';
// unused api_services import'u kaldırıldı

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late Future<List<Product>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    setState(() {
      _futureProducts = LocalDatabaseService.db.products.where().findAll();
    });
  }

  // TEKİL ÜRÜN SİLME METODU
  Future<void> _deleteProduct(int id) async {
    await LocalDatabaseService.db.writeTxn(() async {
      await LocalDatabaseService.db.products.delete(id);
    });
    _loadProducts(); // Listeyi yenile
  }

  // TÜM ÜRÜNLERİ TEMİZLEME METODU
  Future<void> _clearAllProducts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Ürünleri Sil'),
        content: const Text('Veritabanındaki tüm ürünler kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hepsini Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalDatabaseService.db.writeTxn(() async {
        await LocalDatabaseService.db.products.clear();
      });
      _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tüm ürünler başarıyla temizlendi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Listesi ve Stok'),
        actions: [
          // TÜMÜNÜ TEMİZLE BUTONU
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: _clearAllProducts,
            tooltip: 'Tümünü Temizle',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Listeyi Yenile',
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _futureProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz kayıtlı ürün bulunmuyor.\nYeni Ürün ekleyerek başlayın.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final products = snapshot.data!;

          return ListView.builder(
            itemCount: products.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final product = products[index];
              
              // YANA KAYDIRARAK SİLME İÇİN DISMISSIBLE
              return Dismissible(
                key: Key(product.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Ürünü Sil'),
                        content: Text('${product.name} adlı ürünü silmek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Sil'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  _deleteProduct(product.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} silindi.')),
                  );
                },
                child: Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: const Icon(Icons.inventory_2, color: Colors.blue),
                    ),
                    title: Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Kategori: ${product.category}\nAlış: ₺${product.buyPrice} | Dükkan Satış: ₺${product.shopSellPrice}\nNetten Piyasa: ₺${product.marketPrice}',
                    ),
                    isThreeLine: true,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: product.stock > 5
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: product.stock > 5 ? Colors.green : Colors.red,
                        ),
                      ),
                      child: Text(
                        'Stok: ${product.stock}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: product.stock > 5
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}