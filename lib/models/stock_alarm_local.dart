/// Lokal fiyat alarmı modeli (SharedPreferences için)
class StockAlarmLocal {
  final String id;
  final String symbol;
  final double targetPrice;
  /// true = fiyat yukarı çıkınca tetikle (hedef fiyat), false = aşağı inince tetikle (stop)
  final bool isAbove;
  final bool isActive;
  final DateTime createdAt;

  StockAlarmLocal({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.isAbove,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'targetPrice': targetPrice,
        'isAbove': isAbove,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockAlarmLocal.fromJson(Map<String, dynamic> json) => StockAlarmLocal(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        targetPrice: (json['targetPrice'] as num).toDouble(),
        isAbove: json['isAbove'] as bool,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  StockAlarmLocal copyWith({
    String? id,
    String? symbol,
    double? targetPrice,
    bool? isAbove,
    bool? isActive,
    DateTime? createdAt,
  }) =>
      StockAlarmLocal(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        targetPrice: targetPrice ?? this.targetPrice,
        isAbove: isAbove ?? this.isAbove,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt ?? this.createdAt,
      );
}
