import 'package:flutter/material.dart';
import 'package:stok_ai/services/local_database_service.dart'; // Servisi içeri aktarın
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Isar veritabanını uygulamayı ayağa kaldırmadan önce başlatıyoruz
  await LocalDatabaseService.initialize();

  runApp(const StokAiApp());
}

class StokAiApp extends StatelessWidget {
  const StokAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Stok Sistemi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}