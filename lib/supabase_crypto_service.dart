import 'package:supabase_flutter/supabase_flutter.dart';

/// Kripto portföy ve işlemleri – sadece crypto_portfolios, crypto_portfolio, crypto_transactions tablolarını kullanır.
/// Hisse (portfolios/portfolio/transactions) tablolarına dokunmaz.
class SupabaseCryptoService {
  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _userId => _client.auth.currentUser?.id;

  // ========== PORTFÖYLER ==========

  static Future<List<CryptoPortfolio>> portfoyleriYukle() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('crypto_portfolios')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List).map((e) => CryptoPortfolio.fromJson(e as Map<String, dynamic>)).toList();

      if (list.isEmpty) {
        final def = await portfoyOlustur('Ana Kripto Portföy');
        return [def];
      }

      list.sort((a, b) {
        if (a.name == 'Ana Kripto Portföy') return -1;
        if (b.name == 'Ana Kripto Portföy') return 1;
        return 0;
      });
      return list;
    } catch (e) {
      try {
        final def = await portfoyOlustur('Ana Kripto Portföy');
        return [def];
      } catch (_) {
        rethrow;
      }
    }
  }

  static Future<CryptoPortfolio> portfoyOlustur(String name) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final response = await _client.from('crypto_portfolios').insert({
      'user_id': userId,
      'name': name,
    }).select().single();

    return CryptoPortfolio.fromJson(response);
  }

  static Future<String?> anaPortfoyId() async {
    final list = await portfoyleriYukle();
    if (list.isEmpty) return null;
    try {
      return list.firstWhere((p) => p.name == 'Ana Kripto Portföy').id;
    } catch (_) {
      return list.first.id;
    }
  }

  static Future<void> portfoySil(String portfolioId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    await _client.from('crypto_portfolios').delete().eq('id', portfolioId).eq('user_id', userId);
  }

  // ========== POZİSYONLAR ==========

  static Future<List<CryptoPortfolioRow>> portfoyYukle({String? portfolioId}) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      var query = _client.from('crypto_portfolio').select().eq('user_id', userId);
      if (portfolioId != null) query = query.eq('portfolio_id', portfolioId);
      final response = await query.order('symbol');
      final rows = (response as List).map((e) => CryptoPortfolioRow.fromJson(e as Map<String, dynamic>)).toList();

      if (portfolioId == null && rows.isNotEmpty) {
        final anaId = await anaPortfoyId();
        if (anaId != null) {
          for (var i = 0; i < rows.length; i++) {
            if (rows[i].portfolioId == null) {
              rows[i] = CryptoPortfolioRow(
                symbol: rows[i].symbol,
                name: rows[i].name,
                totalQuantity: rows[i].totalQuantity,
                averageCost: rows[i].averageCost,
                portfolioId: anaId,
              );
            }
          }
        }
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  // ========== ALIM ==========

  static Future<void> alimEkle({
    required String symbol,
    required String name,
    required int quantity,
    required double price,
    DateTime? islemTarihi,
    String? portfolioId,
    double commissionRate = 0.001,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final effectivePortfolioId = portfolioId ?? await anaPortfoyId();
    if (effectivePortfolioId == null) throw Exception('Kripto portföy bulunamadı. Önce portföy oluşturun.');

    final mevcut = await _client
        .from('crypto_portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', effectivePortfolioId)
        .maybeSingle();

    final brutTutar = quantity * price;
    final komisyon = brutTutar * commissionRate;
    final netMaliyet = brutTutar + komisyon;
    final efektifMaliyetBirim = netMaliyet / quantity;

    double yeniToplamAdet = quantity.toDouble();
    double yeniOrtMaliyet = efektifMaliyetBirim;

    if (mevcut != null) {
      final eskiAdet = (mevcut['total_quantity'] as num).toDouble();
      final eskiOrt = (mevcut['average_cost'] as num).toDouble();
      yeniToplamAdet = eskiAdet + quantity;
      yeniOrtMaliyet = (eskiAdet * eskiOrt + netMaliyet) / yeniToplamAdet;
    }

    await _client.from('crypto_portfolio').delete().eq('user_id', userId).eq('symbol', symbol).eq('portfolio_id', effectivePortfolioId);
    await _client.from('crypto_portfolio').insert({
      'user_id': userId,
      'symbol': symbol,
      'name': name,
      'total_quantity': yeniToplamAdet,
      'average_cost': yeniOrtMaliyet,
      'portfolio_id': effectivePortfolioId,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _client.from('crypto_transactions').insert({
      'user_id': userId,
      'symbol': symbol,
      'type': 'buy',
      'quantity': quantity,
      'price': price,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
      'portfolio_id': effectivePortfolioId,
      'commission': komisyon,
    });
  }

  /// Varlığı bir portföyden diğerine taşır (tüm pozisyon). Hedefte aynı sembol varsa birleştirir.
  static Future<void> varlikPortfoyDegistir({
    required String symbol,
    required String name,
    required String fromPortfolioId,
    required String toPortfolioId,
    required double quantity,
    required double averageCost,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    if (fromPortfolioId == toPortfolioId) throw Exception('Kaynak ve hedef portföy aynı olamaz.');

    final mevcutHedef = await _client
        .from('crypto_portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', toPortfolioId)
        .maybeSingle();

    double yeniAdet = quantity;
    double yeniOrt = averageCost;
    if (mevcutHedef != null) {
      final eskiAdet = (mevcutHedef['total_quantity'] as num).toDouble();
      final eskiOrt = (mevcutHedef['average_cost'] as num).toDouble();
      yeniAdet = eskiAdet + quantity;
      yeniOrt = (eskiAdet * eskiOrt + quantity * averageCost) / yeniAdet;
    }

    await _client.from('crypto_portfolio').delete().eq('user_id', userId).eq('symbol', symbol).eq('portfolio_id', fromPortfolioId);
    await _client.from('crypto_portfolio').delete().eq('user_id', userId).eq('symbol', symbol).eq('portfolio_id', toPortfolioId);
    await _client.from('crypto_portfolio').insert({
      'user_id': userId,
      'symbol': symbol,
      'name': name,
      'total_quantity': yeniAdet,
      'average_cost': yeniOrt,
      'portfolio_id': toPortfolioId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ========== SATIM ==========

  static Future<void> satimEkle({
    required String symbol,
    required String name,
    required double quantity,
    required double price,
    DateTime? islemTarihi,
    String? portfolioId,
    double commissionRate = 0.001,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final effectivePortfolioId = portfolioId ?? await anaPortfoyId();
    if (effectivePortfolioId == null) throw Exception('Kripto portföy bulunamadı.');

    final mevcut = await _client
        .from('crypto_portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', effectivePortfolioId)
        .maybeSingle();
    if (mevcut == null) throw Exception('Pozisyon bulunamadı.');

    final ortalamaMaliyet = (mevcut['average_cost'] as num).toDouble();
    final mevcutAdet = (mevcut['total_quantity'] as num).toDouble();
    final portId = effectivePortfolioId;

    if (quantity > mevcutAdet) throw Exception('Yetersiz miktar.');

    final brutGelir = quantity * price;
    final komisyon = brutGelir * commissionRate;
    final netGelir = brutGelir - komisyon;
    final maliyetDeger = quantity * ortalamaMaliyet;
    final satisKari = netGelir - maliyetDeger;
    final efektifSatis = price * (1 - commissionRate);
    final satisKarYuzde = ortalamaMaliyet > 0 ? ((efektifSatis - ortalamaMaliyet) / ortalamaMaliyet) * 100 : null;

    final yeniAdet = mevcutAdet - quantity;
    if (yeniAdet <= 0) {
      await _client.from('crypto_portfolio').delete().eq('user_id', userId).eq('symbol', symbol).eq('portfolio_id', portId);
    } else {
      await _client.from('crypto_portfolio').update({
        'total_quantity': yeniAdet,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId).eq('symbol', symbol).eq('portfolio_id', portId);
    }

    await _client.from('crypto_transactions').insert({
      'user_id': userId,
      'symbol': symbol,
      'type': 'sell',
      'quantity': quantity,
      'price': price,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
      'portfolio_id': portId,
      'commission': komisyon,
      'satis_kari': satisKari,
      'satis_kar_yuzde': satisKarYuzde,
    });
  }

  // ========== İŞLEMLER ==========

  static Future<List<CryptoTransactionRow>> islemleriYukle({
    String? portfolioId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      var query = _client.from('crypto_transactions').select().eq('user_id', userId);
      if (portfolioId != null) query = query.eq('portfolio_id', portfolioId);
      if (startDate != null) query = query.gte('created_at', startDate.toUtc().toIso8601String());
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((e) => CryptoTransactionRow.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Seçilen tarihe kadar (dahil) işlemleri işleyerek o tarihteki adetleri döner
  static Future<Map<String, double>> portfoyAdetleriHesapla(DateTime secilenTarih, {String? portfolioId}) async {
    final islemler = await islemleriYukle(portfolioId: portfolioId, endDate: secilenTarih.add(const Duration(days: 1)));
    final secilenGun = DateTime(secilenTarih.year, secilenTarih.month, secilenTarih.day);
    final adetler = <String, double>{};
    final sirali = List<CryptoTransactionRow>.from(islemler)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final t in sirali) {
      final tGun = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      if (tGun.isAfter(secilenGun)) continue;
      final sym = t.symbol;
      final qty = t.quantity;
      if (t.type == 'buy') {
        adetler[sym] = (adetler[sym] ?? 0) + qty;
      } else {
        adetler[sym] = (adetler[sym] ?? 0) - qty;
      }
    }
    return Map.fromEntries(adetler.entries.where((e) => e.value > 0));
  }
}

// ========== MODELLER ==========

class CryptoPortfolio {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  final bool isShared;

  CryptoPortfolio({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.isShared = false,
  });

  factory CryptoPortfolio.fromMap(Map<String, dynamic> map) {
    return CryptoPortfolio(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isShared: map['is_shared'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'is_shared': isShared,
    };
  }

  factory CryptoPortfolio.fromJson(Map<String, dynamic> json) => CryptoPortfolio.fromMap(json);

  Map<String, dynamic> toJson() => toMap();
}

class CryptoPortfolioRow {
  final String symbol;
  final String name;
  final double totalQuantity;
  final double averageCost;
  final String? portfolioId;

  CryptoPortfolioRow({
    required this.symbol,
    required this.name,
    required this.totalQuantity,
    required this.averageCost,
    this.portfolioId,
  });

  double get toplamDeger => totalQuantity * averageCost;

  factory CryptoPortfolioRow.fromJson(Map<String, dynamic> json) {
    return CryptoPortfolioRow(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      totalQuantity: (json['total_quantity'] as num).toDouble(),
      averageCost: (json['average_cost'] as num).toDouble(),
      portfolioId: json['portfolio_id'] as String?,
    );
  }
}

class CryptoTransactionRow {
  final String id;
  final String symbol;
  final String type; // 'buy' | 'sell'
  final double quantity;
  final double price;
  final DateTime createdAt;
  final String? portfolioId;
  final double? satisKari;
  final double? satisKarYuzde;

  CryptoTransactionRow({
    required this.id,
    required this.symbol,
    required this.type,
    required this.quantity,
    required this.price,
    required this.createdAt,
    this.portfolioId,
    this.satisKari,
    this.satisKarYuzde,
  });

  double get toplamTutar => quantity * price;

  factory CryptoTransactionRow.fromJson(Map<String, dynamic> json) {
    return CryptoTransactionRow(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      portfolioId: json['portfolio_id'] as String?,
      satisKari: json['satis_kari'] != null ? (json['satis_kari'] as num).toDouble() : null,
      satisKarYuzde: json['satis_kar_yuzde'] != null ? (json['satis_kar_yuzde'] as num).toDouble() : null,
    );
  }
}
