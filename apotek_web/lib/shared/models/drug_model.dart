class DrugModel {
  final String id;
  final String name;
  final String? genericName;
  final String? activeIngredient;
  final String category;
  final String type;
  final String unit;
  final int minStock;
  final double sellPrice;
  final double buyPrice;
  final String? description;
  final List<BatchModel> batches;

  DrugModel({
    required this.id,
    required this.name,
    this.genericName,
    this.activeIngredient,
    required this.category,
    required this.type,
    required this.unit,
    required this.minStock,
    required this.sellPrice,
    required this.buyPrice,
    this.description,
    this.batches = const [],
  });

  factory DrugModel.fromJson(Map<String, dynamic> json) {
    return DrugModel(
      id: json['id'],
      name: json['name'],
      genericName: json['genericName'],
      activeIngredient: json['activeIngredient'],
      category: json['category'],
      type: json['type'],
      unit: json['unit'],
      minStock: json['minStock'],
      sellPrice: (json['sellPrice'] as num).toDouble(),
      buyPrice: (json['buyPrice'] as num).toDouble(),
      description: json['description'],
      batches: (json['batches'] as List<dynamic>? ?? [])
          .map((b) => BatchModel.fromJson(b))
          .toList(),
    );
  }

  // Total stok dari semua batch
  int get totalStock => batches.fold(0, (sum, b) => sum + b.stock);
}

class BatchModel {
  final String id;
  final String batchNumber;
  final int stock;
  final double buyPrice;
  final DateTime expiredDate;

  BatchModel({
    required this.id,
    required this.batchNumber,
    required this.stock,
    required this.buyPrice,
    required this.expiredDate,
  });

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    return BatchModel(
      id: json['id'],
      batchNumber: json['batchNumber'],
      stock: json['stock'],
      buyPrice: (json['buyPrice'] as num).toDouble(),
      expiredDate: DateTime.parse(json['expiredDate']),
    );
  }
}