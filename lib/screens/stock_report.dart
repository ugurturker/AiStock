import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:stok_ai/services/local_database_service.dart';
import '../models/product.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  late Future<List<Product>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = LocalDatabaseService.db.products.where().findAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok ve Finansal Rapor'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Product>>(
        future: _futureProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Rapor oluşturulacak veri bulunamadı.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final products = snapshot.data!;

          // İstatistik Hesaplamaları (Güncellenen Fiyat Alanları ile)
          int totalVariety = products.length;
          int totalStockCount = products.fold<int>(0, (sum, item) => sum + item.stock);
          double totalBuyValue = products.fold<double>(0.0, (sum, item) => sum + (item.buyPrice * item.stock));
          
          // Dükkan satış fiyatı üzerinden ciro hesabı:
          double totalShopSellValue = products.fold<double>(0.0, (sum, item) => sum + (item.shopSellPrice * item.stock));
          
          // Opsiyonel: Net piyasa fiyatı üzerinden toplam piyasa değeri hesabı
          double totalMarketValue = products.fold<double>(0.0, (sum, item) => sum + (item.marketPrice * item.stock));
          
          // Kritik Stoktakiler (Stok <= 5)
          final criticalProducts = products.where((p) => p.stock <= 5).toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Özet Kartları
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard('Ürün Çeşitliliği', '$totalVariety Çeşit', Icons.category, Colors.blue),
                  _buildStatCard('Toplam Stok', '$totalStockCount Adet', Icons.inventory, Colors.orange),
                  _buildStatCard('Toplam Maliyet', '₺${totalBuyValue.toStringAsFixed(2)}', Icons.money_off, Colors.red),
                  _buildStatCard('Dükkan Ciro Hedefi', '₺${totalShopSellValue.toStringAsFixed(2)}', Icons.trending_up, Colors.green),
                ],
              ),
              const SizedBox(height: 16),

              // İsteğe Bağlı: Net Piyasa Değeri Bilgi Kartı
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.public, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Net Piyasa Değeri Toplamı: ₺${totalMarketValue.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Kritik Stok Uyarısı Başlığı
              Text(
                'Kritik Stok Uyarıları (${criticalProducts.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 8),

              criticalProducts.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Kritik seviyede azalan ürün bulunmuyor.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: criticalProducts.length,
                      itemBuilder: (context, index) {
                        final cp = criticalProducts[index];
                        return Card(
                          color: Colors.red[50],
                          child: ListTile(
                            leading: const Icon(Icons.warning, color: Colors.red),
                            title: Text(cp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Kategori: ${cp.category} | Dükkan Satış: ₺${cp.shopSellPrice}'),
                            trailing: Text(
                              'Kalan: ${cp.stock}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}