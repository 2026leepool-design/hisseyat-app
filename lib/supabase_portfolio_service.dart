import 'package:supabase_flutter/supabase_flutter.dart';
import 'stock_notes_alarms.dart';

/// Kullanıcının portföyünü ve işlemlerini Supabase'de yönetir.
class SupabasePortfolioService {
  static SupabaseClient get _client => Supabase.instance.client;

  static String? get _userId => _client.auth.currentUser?.id;

  // ========== PORTFÖY YÖNETİMİ ==========

  /// Tüm portföyleri yükler (sahip olunan + paylaşılan).
  /// [assetType]: 'stock' = hisse (varsayılan), 'crypto' = kripto
  static Future<List<Portfolio>> portfoyleriYukle({String assetType = 'stock'}) async {
    final userId = _userId;
    if (userId == null) return [];

    final isCrypto = assetType == 'crypto';
    final defaultName = isCrypto ? 'Ana Kripto Portföy' : 'Ana Portföy';

    try {
      var query = _client
          .from('portfolios')
          .select()
          .eq('user_id', userId);
      if (assetType == 'crypto') {
        query = query.eq('asset_type', 'crypto');
      } else {
        query = query.or('asset_type.eq.stock,asset_type.is.null');
      }
      final ownedResponse = await query.order('created_at', ascending: false);

      final ownedIds = <String>{};
      try {
        final ownerShares = await _client
            .from('portfolio_shares')
            .select('portfolio_id')
            .eq('owner_user_id', userId);
        for (final s in ownerShares as List) {
          ownedIds.add(s['portfolio_id'] as String);
        }
      } catch (_) {}
      final portfoyler = (ownedResponse as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
        m['has_shares'] = ownedIds.contains(m['id'] as String?);
        return Portfolio.fromJson(m);
      }).toList();

      // Paylaşılan portföyleri ekle (her zaman readonly)
      try {
        final sharesResponse = await _client
            .from('portfolio_shares')
            .select('portfolio_id')
            .eq('shared_with_user_id', userId);
        for (final s in sharesResponse as List) {
          final pid = s['portfolio_id'] as String;
          if (portfoyler.any((p) => p.id == pid)) continue;
          final pResponse = await _client
              .from('portfolios')
              .select()
              .eq('id', pid)
              .maybeSingle();
          if (pResponse != null) {
            final m = pResponse;
            m['is_shared_with_me'] = true;
            m['share_permission'] = 'readonly';
            final ownerId = m['user_id'] as String?;
            if (ownerId != null) {
              try {
                final prof = await _client.from('profiles').select('email').eq('id', ownerId).maybeSingle();
                final email = prof != null && prof['email'] != null ? (prof['email'] as String) : '';
                final local = email.contains('@') ? email.split('@').first : email;
                final harfler = local.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                m['owner_email_hint'] = harfler.length >= 3 ? '${harfler.substring(0, 3)}***' : '***';
              } catch (_) {
                m['owner_email_hint'] = ownerId.length >= 3 ? '${ownerId.substring(0, 3)}***' : '***';
              }
            }
            portfoyler.add(Portfolio.fromJson(m));
          }
        }
      } catch (_) {
        // portfolio_shares tablosu yoksa veya hata varsa devam et
      }

      // Eğer hiç portföy yoksa, default oluştur
      if (portfoyler.isEmpty) {
        try {
          final defaultPortfoy = await portfoyOlustur(defaultName, assetType: assetType ?? 'stock');
          return [defaultPortfoy];
        } catch (_) {
          return [];
        }
      }

      // Ana Portföy/Kripto'yu listenin başına taşı
      portfoyler.sort((a, b) {
        if (a.name == defaultName && a.userId == userId) return -1;
        if (b.name == defaultName && b.userId == userId) return 1;
        if (!a.isSharedWithMe && b.isSharedWithMe) return -1;
        if (a.isSharedWithMe && !b.isSharedWithMe) return 1;
        return 0;
      });
      return portfoyler;
    } catch (e) {
      try {
        final defaultPortfoy = await portfoyOlustur(defaultName, assetType: assetType ?? 'stock');
        return [defaultPortfoy];
      } catch (_) {
        return [];
      }
    }
  }

  /// Yeni portföy oluşturur
  static Future<Portfolio> portfoyOlustur(String name, {String assetType = 'stock'}) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    try {
      final response = await _client.from('portfolios').insert({
        'user_id': userId,
        'name': name,
        'asset_type': assetType,
      }).select().single();

      return Portfolio.fromJson(response);
    } catch (e) {
      // Daha açıklayıcı hata mesajı
      final errorMsg = e.toString().toLowerCase();
      if ((errorMsg.contains('portfolios') || errorMsg.contains('pgrst205')) && 
          (errorMsg.contains('not found') || errorMsg.contains('could not find'))) {
        throw Exception(
          'portfolios tablosu bulunamadı.\n\n'
          'Çözüm: Supabase Dashboard > SQL Editor\'e gidin ve\n'
          'supabase_migration_v2.sql dosyasını çalıştırın.\n\n'
          'Bu dosya portfolios tablosunu oluşturur.'
        );
      }
      rethrow;
    }
  }

  /// Tek portföy getirir (komisyon oranı dahil). Sahip veya paylaşılan kullanıcı çağırabilir.
  static Future<Portfolio?> portfoyGetir(String portfolioId) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      var response = await _client
          .from('portfolios')
          .select()
          .eq('id', portfolioId)
          .eq('user_id', userId)
          .maybeSingle();
      if (response != null) return Portfolio.fromJson(response);
      final share = await _client
          .from('portfolio_shares')
          .select('permission')
          .eq('portfolio_id', portfolioId)
          .eq('shared_with_user_id', userId)
          .maybeSingle();
      if (share == null) return null;
      response = await _client
          .from('portfolios')
          .select()
          .eq('id', portfolioId)
          .maybeSingle();
      if (response == null) return null;
      final m = response;
      m['is_shared_with_me'] = true;
      m['share_permission'] = share['permission'] as String?;
      return Portfolio.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// Portföy varsayılan komisyon oranını günceller
  static Future<void> portfoyKomisyonOranGuncelle(String portfolioId, double rate) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    await _client
        .from('portfolios')
        .update({'commission_rate': rate})
        .eq('id', portfolioId)
        .eq('user_id', userId);
  }

  // ========== PORTFÖY PAYLAŞIMI ==========

  /// E-posta ile kullanıcı arar (profiles tablosundan, paylaşım için)
  static Future<List<Map<String, dynamic>>> kullaniciEmailIleAra(String query) async {
    final userId = _userId;
    if (userId == null) return [];
    if (query.trim().length < 2) return [];
    try {
      final response = await _client
          .from('profiles')
          .select('id, email')
          .ilike('email', '%${query.trim()}%')
          .neq('id', userId)
          .limit(20);
      return (response as List)
          .map((e) => {'user_id': e['id'] as String, 'email': e['email'] as String? ?? ''})
          .where((e) => (e['email'] as String).isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Portföyü kullanıcıyla paylaşır
  static Future<void> portfoyPaylas({
    required String portfolioId,
    required String sharedWithUserId,
    String permission = 'readonly',
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    await _client.from('portfolio_shares').insert({
      'portfolio_id': portfolioId,
      'owner_user_id': userId,
      'shared_with_user_id': sharedWithUserId,
      'permission': permission,
    });
  }

  /// Portföyün paylaşım listesini getirir (sadece sahip çağırabilir)
  static Future<List<Map<String, dynamic>>> portfoyPaylasimlariniGetir(String portfolioId) async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final response = await _client
          .from('portfolio_shares')
          .select()
          .eq('portfolio_id', portfolioId)
          .eq('owner_user_id', userId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }

  /// Paylaşımı kaldırır (sahip: başkasının erişimini kaldırır, paylaşılan: kendi erişimini kaldırır)
  static Future<void> portfoyPaylasimiKaldir({
    required String portfolioId,
    required String sharedWithUserId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    await _client
        .from('portfolio_shares')
        .delete()
        .eq('portfolio_id', portfolioId)
        .eq('shared_with_user_id', sharedWithUserId);
  }

  /// Paylaşım üzerinden kendi erişimimi kaldırır
  static Future<void> paylasimErisimimiKaldir(String portfolioId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    await _client
        .from('portfolio_shares')
        .delete()
        .eq('portfolio_id', portfolioId)
        .eq('shared_with_user_id', userId);
  }

  /// Portföy siler. Önce tüm paylaşımları kaldırır.
  static Future<void> portfoySil(String portfolioId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    await _client
        .from('portfolio_shares')
        .delete()
        .eq('portfolio_id', portfolioId)
        .eq('owner_user_id', userId);
    await _client
        .from('portfolios')
        .delete()
        .eq('id', portfolioId)
        .eq('user_id', userId);
  }

  /// Portföyü siler; tüm portföy ve işlemleri Ana Portföy'e taşır, sonra portföyü siler.
  /// Ana Portföy silinemez, bu durumda Exception fırlatır.
  static Future<void> cuzdanTasimaVeSil(String portfolioId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final anaId = await anaPortfoyId();
    if (anaId == null) throw Exception('Ana Portföy bulunamadı.');

    final portfoyler = await portfoyleriYukle();
    final silinecek = portfoyler.where((p) => p.id == portfolioId).toList();
    if (silinecek.isEmpty) throw Exception('Portföy bulunamadı.');
    if (silinecek.first.name == 'Ana Portföy') {
      throw Exception('Ana Portföy silinemez.');
    }

    if (portfolioId == anaId) return;

    await _client.from('portfolio').update({'portfolio_id': anaId}).eq('portfolio_id', portfolioId).eq('user_id', userId);
    await _client.from('transactions').update({'portfolio_id': anaId}).eq('portfolio_id', portfolioId).eq('user_id', userId);
    await portfoySil(portfolioId);
  }

  /// Hisseyi bir portföyden diğerine taşır.
  /// Hedef portföyde aynı hisse varsa miktarlar birleştirilir, ortalama maliyet yeniden hesaplanır.
  static Future<void> hisseTasima({
    required String symbol,
    required String name,
    required String fromPortfolioId,
    required String toPortfolioId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');
    if (fromPortfolioId == toPortfolioId) return;

    // Kaynak portföy satırını al
    dynamic kaynak = await _client
        .from('portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', fromPortfolioId)
        .maybeSingle();

    if (kaynak == null) throw Exception('Hisse bulunamadı.');

    final miktar = (kaynak['total_quantity'] as num).toDouble();
    final maliyet = (kaynak['average_cost'] as num).toDouble();
    final toplamDeger = miktar * maliyet;

    // Hedef portföyde aynı hisse var mı?
    dynamic hedef = await _client
        .from('portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', toPortfolioId)
        .maybeSingle();

    // Önce kaynağı sil (eski PK (user_id, symbol) kullanan şemalarda duplicate key önlemek için)
    await _client
        .from('portfolio')
        .delete()
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', fromPortfolioId);

    if (hedef != null) {
      // Birleştir: hedefe güncelle (kaynak zaten silindi)
      final hedefMiktar = (hedef['total_quantity'] as num).toDouble();
      final hedefMaliyet = (hedef['average_cost'] as num).toDouble();
      final hedefDeger = hedefMiktar * hedefMaliyet;
      final yeniToplamMiktar = hedefMiktar + miktar;
      final yeniOrtMaliyet = yeniToplamMiktar > 0
          ? (hedefDeger + toplamDeger) / yeniToplamMiktar
          : maliyet;

      await _client
          .from('portfolio')
          .update({
            'total_quantity': yeniToplamMiktar,
            'average_cost': yeniOrtMaliyet,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('symbol', symbol)
          .eq('portfolio_id', toPortfolioId);
    } else {
      // Hedefe yeni satır ekle (kaynak zaten silindi, PK çakışması olmaz)
      await _client.from('portfolio').insert({
        'user_id': userId,
        'symbol': symbol,
        'name': name,
        'total_quantity': miktar,
        'average_cost': maliyet,
        'portfolio_id': toPortfolioId,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // Bu hisseye ait işlemleri kaynak portföyden hedefe taşı.
    // Eski kayıtlarda Ana Portföy işlemleri portfolio_id = null olabilir;
    // bu durumda da aynı hisseyi hedef portföye güncelle.
    final anaId = await anaPortfoyId();
    final kaynakAnaPortfoyMu = anaId != null && fromPortfolioId == anaId;

    await _client
        .from('transactions')
        .update({'portfolio_id': toPortfolioId})
        .eq('user_id', userId)
        .eq('symbol', symbol)
        .eq('portfolio_id', fromPortfolioId);

    if (kaynakAnaPortfoyMu) {
      try {
        await _client
            .from('transactions')
            .update({'portfolio_id': toPortfolioId})
            .eq('user_id', userId)
            .eq('symbol', symbol)
            .filter('portfolio_id', 'is', null);
      } catch (_) {
        // portfolio_id kolonu eski şemada yoksa sessizce geç
      }
    }
  }

  /// "Ana Portföy" ID'sini döndürür (adı "Ana Portföy/Ana Kripto Portföy" olan veya ilk portföy).
  static Future<String?> anaPortfoyId({String assetType = 'stock'}) async {
    final list = await portfoyleriYukle(assetType: assetType);
    if (list.isEmpty) return null;
    final defaultName = assetType == 'crypto' ? 'Ana Kripto Portföy' : 'Ana Portföy';
    try {
      return list.firstWhere((p) => p.name == defaultName).id;
    } catch (_) {
      return list.first.id;
    }
  }

  // ========== PORTFÖY İÇERİĞİ ==========

  /// Portföy sahibinin user_id'sini döndürür (paylaşılan portföylerde sahip, kendi portföylerinde mevcut kullanıcı)
  static Future<String?> _portfoySahipUserId(String? portfolioId) async {
    final userId = _userId;
    if (userId == null || portfolioId == null) return userId;
    try {
      final p = await _client.from('portfolios').select('user_id').eq('id', portfolioId).maybeSingle();
      if (p == null) return userId;
      final ownerId = p['user_id'] as String;
      if (ownerId == userId) return userId;
      final share = await _client
          .from('portfolio_shares')
          .select()
          .eq('portfolio_id', portfolioId)
          .eq('shared_with_user_id', userId)
          .maybeSingle();
      return share != null ? ownerId : null;
    } catch (_) {
      return userId;
    }
  }

  /// Kullanıcının portföyünü yükler (filtreli veya tümü).
  /// [assetType]: 'stock' veya 'crypto' – "Tümü" görünümünde sadece bu tür portföyler
  static Future<List<PortfolioRow>> portfoyYukle({String? portfolioId, String assetType = 'stock'}) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      String? effectiveUserId = userId;
      if (portfolioId != null) {
        effectiveUserId = await _portfoySahipUserId(portfolioId) ?? userId;
      }

      var query = _client
          .from('portfolio')
          .select()
          .eq('user_id', effectiveUserId);

      if (portfolioId != null) {
        query = query.eq('portfolio_id', portfolioId);
      }

      var response = await query.order('symbol');
      var rows = (response as List)
          .map((e) => PortfolioRow.fromJson(e as Map<String, dynamic>))
          .toList();

      // "Tümü" görünümünde sadece bu asset type'a ait portföylerin satırları
      if (portfolioId == null) {
        final portfoyler = await portfoyleriYukle(assetType: assetType);
        final validIds = portfoyler.map((p) => p.id).toSet();
        rows = rows.where((r) => r.portfolioId == null || validIds.contains(r.portfolioId)).toList();
      }

      // "Tümü" görünümünde paylaşılan portföylerin holding'lerini de ekle (aynı asset type)
      if (portfolioId == null) {
        try {
          final sharesResponse = await _client
              .from('portfolio_shares')
              .select('portfolio_id')
              .eq('shared_with_user_id', userId);
          final sharedIds = <String>{};
          for (final s in sharesResponse as List) {
            sharedIds.add(s['portfolio_id'] as String);
          }
          if (sharedIds.isNotEmpty) {
            final portfoyler = await portfoyleriYukle(assetType: assetType);
            final validSharedIds = sharedIds.intersection(portfoyler.map((p) => p.id).toSet()).toList();
            if (validSharedIds.isNotEmpty) {
              final sharedResponse = await _client
                  .from('portfolio')
                  .select()
                  .inFilter('portfolio_id', validSharedIds)
                  .order('symbol');
              for (final e in sharedResponse as List) {
                rows.add(PortfolioRow.fromJson(e as Map<String, dynamic>));
              }
            }
          }
        } catch (_) {}
      }

      // "Tümü" görünümünde portfolio_id null olanları Ana Portföy'e ata
      if (portfolioId == null && rows.isNotEmpty) {
        final anaId = await anaPortfoyId(assetType: assetType);
        if (anaId != null) {
          for (var i = 0; i < rows.length; i++) {
            if (rows[i].portfolioId == null) {
              rows[i] = PortfolioRow(
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
    } catch (e) {
      return [];
    }
  }

  /// Hisse/kripto alımı ekler - portfolio güncellenir, transaction kaydı oluşturulur.
  /// portfolioId null ise "Ana Portföy" veya "Ana Kripto Portföy" kullanılır.
  static Future<void> alimEkle({
    required String symbol,
    required String name,
    required int quantity,
    required double price,
    DateTime? islemTarihi,
    String? portfolioId,
    String assetType = 'stock',
    double commissionRate = 0.001,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final effectivePortfolioId = portfolioId ?? await anaPortfoyId(assetType: assetType);
    if (effectivePortfolioId == null) throw Exception('Portföy bulunamadı. Önce bir portföy oluşturun.');

    final effectiveUserId = await _portfoySahipUserId(effectivePortfolioId) ?? userId;

    final mevcut = await _client
        .from('portfolio')
        .select()
        .eq('user_id', effectiveUserId)
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
      final eskiAdet = (mevcut['total_quantity'] as num?)?.toDouble() ?? 0;
      final eskiOrt = (mevcut['average_cost'] as num?)?.toDouble() ?? 0;
      final eskiDeger = eskiAdet * eskiOrt;
      yeniToplamAdet = eskiAdet + quantity;
      yeniOrtMaliyet = (eskiDeger + netMaliyet) / yeniToplamAdet;
    }

    final portfolioData = {
      'user_id': effectiveUserId,
      'symbol': symbol,
      'name': name,
      'total_quantity': yeniToplamAdet,
      'average_cost': yeniOrtMaliyet,
      'updated_at': DateTime.now().toIso8601String(),
    };

    portfolioData['portfolio_id'] = effectivePortfolioId;

    await _client
        .from('portfolio')
        .delete()
        .eq('user_id', effectiveUserId)
        .eq('symbol', symbol)
        .or('portfolio_id.eq.$effectivePortfolioId,portfolio_id.is.null');
    await _client.from('portfolio').insert(portfolioData);

    final transactionData = {
      'user_id': effectiveUserId,
      'symbol': symbol,
      'type': 'buy',
      'transaction_type': 'buy',
      'quantity': quantity,
      'price': price,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
      'portfolio_id': effectivePortfolioId,
      'commission': komisyon,
    };

    await _client.from('transactions').insert(transactionData);
  }

  /// Hisse satışı - kısmi veya tam. Transaction kaydı oluşturur (ortalama maliyet üzerinden kar bilgisiyle), portföyü günceller.
  /// commissionRate: binde 1 = 0.001. Komisyon satış gelirinden düşülür.
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

    final effectiveUserId = portfolioId != null
        ? (await _portfoySahipUserId(portfolioId) ?? userId)
        : userId;

    var query = _client
        .from('portfolio')
        .select()
        .eq('user_id', effectiveUserId)
        .eq('symbol', symbol);

    if (portfolioId != null) {
      query = query.eq('portfolio_id', portfolioId);
    } else {
      query = query.filter('portfolio_id', 'is', null);
    }

    dynamic mevcut = await query.maybeSingle();
    bool usePortfolioIdFilter = portfolioId != null;

    if (mevcut == null && portfolioId != null) {
      try {
        mevcut = await _client
            .from('portfolio')
            .select()
            .eq('user_id', effectiveUserId)
            .eq('symbol', symbol)
            .filter('portfolio_id', 'is', null)
            .maybeSingle();
        if (mevcut != null) usePortfolioIdFilter = false;
      } catch (_) {}
    }

    if (mevcut == null) return;

    final ortalamaMaliyet = (mevcut['average_cost'] as num).toDouble();
    final brutGelir = quantity * price;
    final komisyon = brutGelir * commissionRate;
    final netGelir = brutGelir - komisyon;
    final maliyetDeger = quantity * ortalamaMaliyet;
    // Satış karı (TL): net gelir - maliyet (komisyon düşüldükten sonra)
    final satisKari = netGelir - maliyetDeger;
    // Hisse başı kar %: efektif satış fiyatı (komisyon sonrası) - ortalama maliyet
    final efektifSatisFiyati = price * (1 - commissionRate);
    final satisKarYuzde = ortalamaMaliyet != 0
        ? ((efektifSatisFiyati - ortalamaMaliyet) / ortalamaMaliyet) * 100
        : null;

    final transactionData = {
      'user_id': effectiveUserId,
      'symbol': symbol,
      'type': 'sell',
      'transaction_type': 'sell',
      'quantity': quantity,
      'price': price,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
      'commission': komisyon,
    };
    if (portfolioId != null) transactionData['portfolio_id'] = portfolioId;
    transactionData['satis_kari'] = satisKari;
    if (satisKarYuzde != null) transactionData['satis_kar_yuzde'] = satisKarYuzde;

    await _client.from('transactions').insert(transactionData);

    final toplamAdet = (mevcut['total_quantity'] as num).toDouble();
    final kalanAdet = toplamAdet - quantity;

    if (kalanAdet <= 0) {
      var deleteQuery = _client
          .from('portfolio')
          .delete()
          .eq('user_id', effectiveUserId)
          .eq('symbol', symbol);
      if (usePortfolioIdFilter && portfolioId != null) {
        deleteQuery = deleteQuery.eq('portfolio_id', portfolioId);
      } else {
        deleteQuery = deleteQuery.filter('portfolio_id', 'is', null);
      }
      await deleteQuery;
    } else {
      final ortMaliyet = (mevcut['average_cost'] as num).toDouble();
      var updateQuery = _client
          .from('portfolio')
          .update({
            'total_quantity': kalanAdet,
            'average_cost': ortMaliyet,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', effectiveUserId)
          .eq('symbol', symbol);
      if (usePortfolioIdFilter && portfolioId != null) {
        updateQuery = updateQuery.eq('portfolio_id', portfolioId);
      } else {
        updateQuery = updateQuery.filter('portfolio_id', 'is', null);
      }
      await updateQuery;
    }
  }

  /// Bölünme işlemi ekler
  static Future<void> bolunmeEkle({
    required String symbol,
    required String name,
    required double eklenenAdet,
    required double maliyet,
    DateTime? islemTarihi,
    String? portfolioId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    // portfolioId null ise portfolio_id sütununa hiç dokunma (eski şema / sütun yoksa uyumluluk)
    var query = _client
        .from('portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol);

    if (portfolioId != null) {
      query = query.eq('portfolio_id', portfolioId);
    } else {
      query = query.filter('portfolio_id', 'is', null);
    }

    dynamic mevcut;
    try {
      mevcut = await query.maybeSingle();
    } catch (e) {
      if (e.toString().contains('portfolio_id') && e.toString().contains('exist')) {
        mevcut = await _client
            .from('portfolio')
            .select()
            .eq('user_id', userId)
            .eq('symbol', symbol)
            .maybeSingle();
      } else {
        rethrow;
      }
    }

    if (mevcut == null) {
      final portfolioData = {
        'user_id': userId,
        'symbol': symbol,
        'name': name,
        'total_quantity': eklenenAdet,
        'average_cost': maliyet,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (portfolioId != null) {
        portfolioData['portfolio_id'] = portfolioId;
      }
      await _client.from('portfolio').insert(portfolioData);
    } else {
      final eskiAdet = (mevcut['total_quantity'] as num?)?.toDouble() ?? 0;
      final eskiOrt = (mevcut['average_cost'] as num?)?.toDouble() ?? 0;
      final eskiDeger = eskiAdet * eskiOrt;
      final yeniDeger = eklenenAdet * maliyet;
      final yeniToplamAdet = eskiAdet + eklenenAdet;
      final yeniOrtMaliyet = yeniToplamAdet > 0
          ? (eskiDeger + yeniDeger) / yeniToplamAdet
          : maliyet;

      var updateQuery = _client
          .from('portfolio')
          .update({
            'total_quantity': yeniToplamAdet,
            'average_cost': yeniOrtMaliyet,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('symbol', symbol);

      if (portfolioId != null) {
        await updateQuery.eq('portfolio_id', portfolioId);
      } else {
        try {
          await updateQuery.filter('portfolio_id', 'is', null);
        } catch (e) {
          if (e.toString().contains('portfolio_id') && e.toString().contains('exist')) {
            await _client
                .from('portfolio')
                .update({
                  'total_quantity': yeniToplamAdet,
                  'average_cost': yeniOrtMaliyet,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', userId)
                .eq('symbol', symbol);
          } else {
            rethrow;
          }
        }
      }
    }

    final transactionData = {
      'user_id': userId,
      'symbol': symbol,
      'type': 'buy',
      'transaction_type': 'split',
      'quantity': eklenenAdet,
      'price': maliyet,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
    };

    if (portfolioId != null) {
      transactionData['portfolio_id'] = portfolioId;
    }

    await _client.from('transactions').insert(transactionData);
  }

  /// Temettü işlemi ekler
  static Future<void> temettuEkle({
    required String symbol,
    required String name,
    required double temettuTutari,
    DateTime? islemTarihi,
    String? portfolioId,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    var query = _client
        .from('portfolio')
        .select()
        .eq('user_id', userId)
        .eq('symbol', symbol);

    if (portfolioId != null) {
      query = query.eq('portfolio_id', portfolioId);
    } else {
      query = query.filter('portfolio_id', 'is', null);
    }

    dynamic mevcut;
    try {
      mevcut = await query.maybeSingle();
    } catch (e) {
      if (e.toString().contains('portfolio_id') && e.toString().contains('exist')) {
        mevcut = await _client
            .from('portfolio')
            .select()
            .eq('user_id', userId)
            .eq('symbol', symbol)
            .maybeSingle();
      } else {
        rethrow;
      }
    }

    if (mevcut != null) {
      final eskiAdet = (mevcut['total_quantity'] as num?)?.toDouble() ?? 0;
      final eskiOrt = (mevcut['average_cost'] as num?)?.toDouble() ?? 0;
      final eskiToplamMaliyet = eskiAdet * eskiOrt;
      final yeniToplamMaliyet = eskiToplamMaliyet - temettuTutari;
      final yeniOrtMaliyet = eskiAdet > 0 ? yeniToplamMaliyet / eskiAdet : eskiOrt;

      var updateQuery = _client
          .from('portfolio')
          .update({
            'average_cost': yeniOrtMaliyet.clamp(0.0, double.infinity),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('symbol', symbol);

      if (portfolioId != null) {
        await updateQuery.eq('portfolio_id', portfolioId);
      } else {
        try {
          await updateQuery.filter('portfolio_id', 'is', null);
        } catch (e) {
          if (e.toString().contains('portfolio_id') && e.toString().contains('exist')) {
            await _client
                .from('portfolio')
                .update({
                  'average_cost': yeniOrtMaliyet.clamp(0.0, double.infinity),
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', userId)
                .eq('symbol', symbol);
          } else {
            rethrow;
          }
        }
      }
    }

    final transactionData = {
      'user_id': userId,
      'symbol': symbol,
      'type': 'sell',
      'transaction_type': 'dividend',
      'quantity': null,
      'price': temettuTutari,
      'created_at': (islemTarihi ?? DateTime.now()).toIso8601String(),
    };

    if (portfolioId != null) {
      transactionData['portfolio_id'] = portfolioId;
    }

    await _client.from('transactions').insert(transactionData);
  }

  // ========== İŞLEMLER ==========

  /// Kullanıcının tüm işlemlerini (transactions) yükler (filtreli veya tümü).
  /// [assetType]: "Tümü" görünümünde sadece bu tür portföylerin işlemleri
  static Future<List<TransactionRow>> islemleriYukle({
    String? portfolioId,
    DateTime? startDate,
    DateTime? endDate,
    String assetType = 'stock',
  }) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      // Paylaşılan portföy ID'leri
      List<String> sharedPortfolioIds = [];
      try {
        final sharesResponse = await _client
            .from('portfolio_shares')
            .select('portfolio_id')
            .eq('shared_with_user_id', userId);
        for (final s in sharesResponse as List) {
          sharedPortfolioIds.add(s['portfolio_id'] as String);
        }
      } catch (_) {}

      final allTransactions = <TransactionRow>[];

      // Kendi işlemleri
      var ownQuery = _client
          .from('transactions')
          .select()
          .eq('user_id', userId);
      if (portfolioId != null) {
        ownQuery = ownQuery.eq('portfolio_id', portfolioId);
      }
      if (startDate != null) {
        ownQuery = ownQuery.gte('created_at', startDate.toUtc().toIso8601String());
      }
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        ownQuery = ownQuery.lte('created_at', endOfDay.toUtc().toIso8601String());
      }
      final ownResponse = await ownQuery.order('created_at', ascending: false);
      for (final e in ownResponse as List) {
        allTransactions.add(TransactionRow.fromJson(e as Map<String, dynamic>));
      }

      // Paylaşılan portföylerin işlemleri (sadece Tümü veya o portföy seçiliyse)
      final includeShared = portfolioId == null || sharedPortfolioIds.contains(portfolioId);
      if (includeShared && sharedPortfolioIds.isNotEmpty) {
        var sharedQuery = _client
            .from('transactions')
            .select()
            .inFilter('portfolio_id', sharedPortfolioIds);
        if (portfolioId != null) {
          sharedQuery = sharedQuery.eq('portfolio_id', portfolioId);
        }
        if (startDate != null) {
          sharedQuery = sharedQuery.gte('created_at', startDate.toUtc().toIso8601String());
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          sharedQuery = sharedQuery.lte('created_at', endOfDay.toUtc().toIso8601String());
        }
        final sharedResponse = await sharedQuery.order('created_at', ascending: false);
        for (final e in sharedResponse as List) {
          allTransactions.add(TransactionRow.fromJson(e as Map<String, dynamic>));
        }
      }

      // "Tümü" görünümünde asset type'a göre filtrele
      List<TransactionRow> filtered = allTransactions;
      if (portfolioId == null) {
        final portfoyler = await portfoyleriYukle(assetType: assetType);
        final validIds = portfoyler.map((p) => p.id).toSet();
        filtered = allTransactions
            .where((t) => t.portfolioId == null || validIds.contains(t.portfolioId))
            .toList();
      }

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    } catch (e) {
      return [];
    }
  }

  /// Belirli bir hisse için işlemleri yükler
  static Future<List<TransactionRow>> hisseIslemleriYukle(String symbol) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .eq('symbol', symbol)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => TransactionRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ========== NOTLAR ==========

  /// Notu olan hisse sembollerini döndürür (kullanıcıya özel)
  static Future<Set<String>> notuOlanSemboller() async {
    final userId = _userId;
    if (userId == null) return {};

    try {
      final response = await _client
          .from('stock_notes')
          .select('symbol')
          .eq('user_id', userId);
      return (response as List)
          .map((e) => (e as Map<String, dynamic>)['symbol'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      return {};
    }
  }

  /// Hisse için notları yükler
  static Future<List<StockNote>> notlariYukle(String symbol) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('stock_notes')
          .select()
          .eq('user_id', userId)
          .eq('symbol', symbol)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => StockNote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Yeni not ekler
  static Future<StockNote> notEkle(String symbol, String note) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final response = await _client.from('stock_notes').insert({
      'user_id': userId,
      'symbol': symbol,
      'note': note,
    }).select().single();

    return StockNote.fromJson(response);
  }

  /// Not siler
  static Future<void> notSil(String noteId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    await _client
        .from('stock_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId);
  }

  // ========== ALARMLAR ==========

  /// Hisse için alarmları yükler
  static Future<List<StockAlarm>> alarmlariYukle(String symbol) async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('stock_alarms')
          .select()
          .eq('user_id', userId)
          .eq('symbol', symbol)
          .order('created_at', ascending: false);

      return (response as List)
          .map((e) => StockAlarm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Tüm aktif alarmları yükler (alarm kontrolü için)
  static Future<List<StockAlarm>> aktifAlarmlariYukle() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('stock_alarms')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('is_triggered', false);

      return (response as List)
          .map((e) => StockAlarm.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Yeni alarm ekler veya günceller
  static Future<StockAlarm> alarmEkle({
    required String symbol,
    required String alarmType, // 'target' veya 'stop'
    required double targetPrice,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    final data = {
      'user_id': userId,
      'symbol': symbol,
      'alarm_type': alarmType,
      'target_price': targetPrice,
      'is_active': true,
      'is_triggered': false,
    };

    // Upsert: aynı symbol ve alarm_type için mevcut alarm varsa güncelle
    final response = await _client
        .from('stock_alarms')
        .upsert(data, onConflict: 'user_id,symbol,alarm_type')
        .select()
        .single();

    return StockAlarm.fromJson(response);
  }

  /// Alarm siler veya pasif yapar
  static Future<void> alarmSil(String alarmId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    await _client
        .from('stock_alarms')
        .delete()
        .eq('id', alarmId)
        .eq('user_id', userId);
  }

  /// Alarmı pasif yapar
  static Future<void> alarmPasifYap(String alarmId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    await _client
        .from('stock_alarms')
        .update({'is_active': false})
        .eq('id', alarmId)
        .eq('user_id', userId);
  }

  /// Alarmı tekrar aktif yapar
  static Future<void> alarmAktifYap(String alarmId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Kullanıcı girişi gerekli.');

    await _client
        .from('stock_alarms')
        .update({'is_active': true})
        .eq('id', alarmId)
        .eq('user_id', userId);
  }

  /// Alarmı tetiklenmiş olarak işaretle
  static Future<void> alarmTetikle(String alarmId) async {
    final userId = _userId;
    if (userId == null) return;

    await _client
        .from('stock_alarms')
        .update({
          'is_triggered': true,
          'triggered_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alarmId)
        .eq('user_id', userId);
  }
}

// ========== MODELLER ==========

class Portfolio {
  final String id;
  final String userId;
  final String name;
  final DateTime createdAt;
  /// Portföy için varsayılan komisyon oranı (örn. 0.001 = binde 1)
  final double? commissionRate;
  /// Başkası tarafından paylaşılmış portföy mü (alıcı tarafındayım)
  final bool isSharedWithMe;
  /// Sahibi olarak başkalarıyla paylaştığım portföy mü
  final bool hasShares;
  /// Paylaşım yetkisi: artık sadece readonly (isSharedWithMe için)
  final String? sharePermission;
  /// Sahibin e-posta ipucu: ilk 3 harf*** (sadece isSharedWithMe true ise)
  final String? ownerEmailHint;

  Portfolio({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.commissionRate,
    this.isSharedWithMe = false,
    this.hasShares = false,
    this.sharePermission,
    this.ownerEmailHint,
  });

  /// Paylaşılmış portföy (sahip veya alıcı olarak)
  bool get isShared => isSharedWithMe || hasShares;

  factory Portfolio.fromJson(Map<String, dynamic> json) {
    return Portfolio(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      commissionRate: json['commission_rate'] != null ? (json['commission_rate'] as num).toDouble() : null,
      isSharedWithMe: json['is_shared_with_me'] == true,
      hasShares: json['has_shares'] == true,
      sharePermission: json['share_permission'] as String?,
      ownerEmailHint: json['owner_email_hint'] as String?,
    );
  }
}

class PortfolioRow {
  final String symbol;
  final String name;
  final double totalQuantity;
  final double averageCost;
  final String? portfolioId;

  PortfolioRow({
    required this.symbol,
    required this.name,
    required this.totalQuantity,
    required this.averageCost,
    this.portfolioId,
  });

  double get toplamDeger => totalQuantity * averageCost;

  factory PortfolioRow.fromJson(Map<String, dynamic> json) {
    return PortfolioRow(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      totalQuantity: (json['total_quantity'] as num).toDouble(),
      averageCost: (json['average_cost'] as num).toDouble(),
      portfolioId: json['portfolio_id'] as String?,
    );
  }
}

class TransactionRow {
  final String id;
  final String symbol;
  final String type; // 'buy' veya 'sell' (eski uyumluluk için)
  final String transactionType; // 'buy', 'sell', 'split', 'dividend'
  final double? quantity; // Temettü için null olabilir
  final double price;
  final DateTime createdAt;
  final String? portfolioId;
  /// İşlem komisyonu (TL)
  final double? commission;
  /// Satış işleminde ortalama maliyet üzerinden kar/zarar (TL)
  final double? satisKari;
  /// Satış işleminde hisse başı kar/zarar yüzdesi
  final double? satisKarYuzde;

  TransactionRow({
    required this.id,
    required this.symbol,
    required this.type,
    required this.transactionType,
    this.quantity,
    required this.price,
    required this.createdAt,
    this.portfolioId,
    this.commission,
    this.satisKari,
    this.satisKarYuzde,
  });

  double get toplamTutar {
    if (transactionType == 'dividend') {
      return price; // Temettü için price tutarı kadar gelir
    }
    return (quantity ?? 0) * price;
  }

  factory TransactionRow.fromJson(Map<String, dynamic> json) {
    return TransactionRow(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      type: json['type'] as String? ?? json['transaction_type'] as String? ?? 'buy',
      transactionType: json['transaction_type'] as String? ?? json['type'] as String? ?? 'buy',
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      price: (json['price'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      portfolioId: json['portfolio_id'] as String?,
      commission: json['commission'] != null ? (json['commission'] as num).toDouble() : null,
      satisKari: json['satis_kari'] != null ? (json['satis_kari'] as num).toDouble() : null,
      satisKarYuzde: json['satis_kar_yuzde'] != null ? (json['satis_kar_yuzde'] as num).toDouble() : null,
    );
  }
}
