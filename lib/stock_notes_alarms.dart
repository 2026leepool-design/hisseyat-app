// ========== NOT MODELİ ==========

class StockNote {
  final String id;
  final String userId;
  final String symbol;
  final String note;
  final DateTime createdAt;

  StockNote({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.note,
    required this.createdAt,
  });

  factory StockNote.fromJson(Map<String, dynamic> json) {
    return StockNote(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      symbol: json['symbol'] as String,
      note: json['note'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ========== ALARM MODELİ ==========

class StockAlarm {
  final String id;
  final String userId;
  final String symbol;
  final String alarmType; // 'target' veya 'stop'
  final double targetPrice;
  final bool isActive;
  final bool isTriggered;
  final DateTime? triggeredAt;
  final DateTime createdAt;

  StockAlarm({
    required this.id,
    required this.userId,
    required this.symbol,
    required this.alarmType,
    required this.targetPrice,
    required this.isActive,
    required this.isTriggered,
    this.triggeredAt,
    required this.createdAt,
  });

  factory StockAlarm.fromJson(Map<String, dynamic> json) {
    return StockAlarm(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      symbol: json['symbol'] as String,
      alarmType: json['alarm_type'] as String,
      targetPrice: (json['target_price'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      isTriggered: json['is_triggered'] as bool,
      triggeredAt: json['triggered_at'] != null
          ? DateTime.parse(json['triggered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
