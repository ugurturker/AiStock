import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@Collection()
@JsonSerializable()
class Product {
  Id id;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'category')
  final String category;

  @JsonKey(name: 'buy_price')
  final double buyPrice;

  @JsonKey(name: 'shop_sell_price')
  final double shopSellPrice; // Dükkan fiyatı (Manuel)

  @JsonKey(name: 'market_price')
  final double marketPrice; // Netten çekilen piyasa fiyatı

  @JsonKey(name: 'stock')
  final int stock;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  Product({
    this.id = Isar.autoIncrement,
    required this.name,
    required this.category,
    required this.buyPrice,
    required this.shopSellPrice,
    required this.marketPrice,
    required this.stock,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);
}