import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';

class LocalDatabaseService {
  static late Isar _isar;

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ProductSchema],
      directory: dir.path,
      inspector: true, // Geliştirme aşamasında Isar Inspector için
    );
  }

  static Isar get db => _isar;
}