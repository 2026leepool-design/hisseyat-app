import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Added
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'hisse_detay_page.dart';
import 'portfolio_share_info_screen.dart';
import 'stock_logo.dart';
import 'logo_service.dart';
import 'supabase_portfolio_service.dart';
import 'stock_notes_alarms.dart';
import 'yahoo_finance_service.dart';
import 'alarm_service.dart';
import 'widgets/app_logo.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _adetController = TextEditingController();
  final _fiyatController = TextEditingController();
  List<PortfolioRow> _liste = [];
  bool _yukleniyor = true;
  DateTime _seciliTarih = DateTime.now();

  HisseBilgisi? _arananHisse;
  bool _araniyor = false;
  String? _aramaHataMesaji;
  int _aramaKey = 0;

  // Döviz kuru desteği
  String _seciliDoviz = 'TL';
  double _usdKuru = 1.0;
  double _eurKuru = 1.0;

  /// Portföy listesinde kar/zarar % göstermek için sembol -> güncel bilgi
  Map<String, HisseBilgisi> _portfoyGuncelFiyatlar = {};

  /// Sıralama: adet, fiyat, deger, az
  String _siralama = 'az';

  // Portföy yönetimi
  List<Portfolio> _portfoyler = [];
  String? _seciliPortfoyId; // null = "All" (tüm portföyler)
  final Set<String> _acikHisseKartlari = {}; // Açık olan hisse kartları (işlem listesi için)

  /// Pull-to-refresh sırasında çekme miktarı (opacity için)
  final ValueNotifier<double> _pullExtent = ValueNotifier(0);

  /// Fiyatlar maskeli mi (**** ile gizleme)
  bool _fiyatlarMaskeli = false;

  /// Notu olan hisse sembolleri (not ikonu bordo göstermek için)
  Set<String> _notuOlanSemboller = {};

  /// Komisyon oranı (binde). Binde 1 = 0.001
  final _komisyonBindeController = TextEditingController(text: '1');
  bool _komisyonVarsayilanOlsun = false;

  /// Portföy seçim paneli açık mı (Tüm Portföyler altında inline)
  bool _portfoySecimAcik = false;
  
  Timer? _timer; // Added

  @override
  void initState() {
    super.initState();
    _portfoyleriYukle();
    _portfoyYukle();
    _dovizKurlariniYukle();
    // Uygulama açıldığında alarm kontrolü yap
    AlarmService.kontrolEtVeBildir();
    
    // 3 saniyede bir fiyatları güncelle
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_yukleniyor && _liste.isNotEmpty) {
        _portfoyGuncelFiyatlarYukle();
      }
    });
  }

  Future<void> _portfoyleriYukle() async {
    try {
      final portfoyler = await SupabasePortfolioService.portfoyleriYukle();
      if (mounted) {
        setState(() => _portfoyler = portfoyler);
      }
    } catch (_) {}
  }

  Future<void> _portfoyGuncelFiyatlarYukle() async {
    if (_liste.isEmpty) return;
    try {
      final futures = _liste.map((e) => YahooFinanceService.hisseAra(e.symbol));
      final sonuclar = await Future.wait(futures);
      if (!mounted) return;
      final map = <String, HisseBilgisi>{};
      for (var i = 0; i < _liste.length && i < sonuclar.length; i++) {
        map[_liste[i].symbol] = sonuclar[i];
      }
      setState(() => _portfoyGuncelFiyatlar = map);
    } catch (_) {
      // Hata olsa bile eski verileri koruyabiliriz veya boşaltabiliriz
      // setState(() => _portfoyGuncelFiyatlar = {});
    }
  }

  Future<void> _dovizKurlariniYukle() async {
    try {
      final kurlar = await Future.wait([
        YahooFinanceService.dovizKuruAl('USDTRY=X'),
        YahooFinanceService.dovizKuruAl('EURTRY=X'),
      ]);
      if (mounted) {
        setState(() {
          _usdKuru = kurlar[0];
          _eurKuru = kurlar[1];
        });
      }
    } catch (_) {
      // Kur yüklenemezse varsayılan değerler kullanılır (1.0)
    }
  }

  double _dovizCevir(double tlDegeri) {
    switch (_seciliDoviz) {
      case 'USD':
        return tlDegeri / _usdKuru;
      case 'EUR':
        return tlDegeri / _eurKuru;
      default:
        return tlDegeri;
    }
  }

  String _dovizSembolu() {
    switch (_seciliDoviz) {
      case 'USD':
        return 'USD';
      case 'EUR':
        return 'EUR';
      default:
        return '₺';
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Added
    _pullExtent.dispose();
    _adetController.dispose();
    _fiyatController.dispose();
    _komisyonBindeController.dispose();
    super.dispose();
  }

  Future<void> _portfoyYukle() async {
    setState(() => _yukleniyor = true);
    try {
      final liste = await SupabasePortfolioService.portfoyYukle(
        portfolioId: _seciliPortfoyId,
      );
      final notuOlan = await SupabasePortfolioService.notuOlanSemboller();
      if (mounted) {
        setState(() {
          _liste = liste;
          _notuOlanSemboller = notuOlan;
          _yukleniyor = false;
        });
      }
      _portfoyGuncelFiyatlarYukle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _liste = [];
          _yukleniyor = false;
        });
      }
    }
  }

  /// Toplam portföy değeri: güncel fiyat varsa (adet × güncel fiyat), yoksa maliyet (toplamDeger)
  double get _toplamParam =>
      _liste.fold(0, (sum, item) {
        final guncel = _portfoyGuncelFiyatlar[item.symbol];
        return sum + (guncel != null ? item.totalQuantity * guncel.fiyat : item.toplamDeger);
      });

  /// Toplam maliyet (alım tutarları toplamı)
  double get _toplamMaliyet =>
      _liste.fold(0, (sum, item) => sum + item.toplamDeger);

  /// Portföy yüzdesel kar/zarar (null = hesaplanamadı)
  double? get _portfoyKarZararYuzde {
    final maliyet = _toplamMaliyet;
    if (maliyet <= 0 || !_toplamParam.isFinite) return null;
    return ((_toplamParam - maliyet) / maliyet) * 100;
  }

  /// Portföy kar/zarar tutarı (güncel değer - maliyet)
  double? get _portfoyKarZararTutar {
    final maliyet = _toplamMaliyet;
    if (!_toplamParam.isFinite) return null;
    return _toplamParam - maliyet;
  }

  /// Seçili portföy düzenlenebilir mi (sadece kendi portföylerim düzenlenebilir)
  bool get _seciliPortfoyDuzenlenebilir {
    if (_seciliPortfoyId == null) return true;
    final p = _portfoyler.where((x) => x.id == _seciliPortfoyId).firstOrNull;
    if (p == null) return true;
    if (p.isSharedWithMe) return false; // Paylaşılan portföyler her zaman readonly
    return true;
  }

  /// Bu satır için alım/satım (kaydırma) izni. "Tüm portföyler"de her satır kendi portföyüne göre değerlendirilir.
  bool _rowAlimSatimIzinli(PortfolioRow item) {
    if (!_seciliPortfoyDuzenlenebilir) return false;
    if (_seciliPortfoyId != null) return true;
    final pid = item.portfolioId;
    if (pid == null) return true;
    final p = _portfoyler.where((x) => x.id == pid).firstOrNull;
    if (p == null) return true;
    return !p.isSharedWithMe;
  }

  /// Seçili portföye göre liste başlığı (paylaşılan portföyde kullanıcı adı dahil)
  String get _portfoyBaslik {
    if (_seciliPortfoyId == null) return 'Portföylerim';
    try {
      final p = _portfoyler.firstWhere((p) => p.id == _seciliPortfoyId);
      if (p.isSharedWithMe && (p.ownerEmailHint ?? '').isNotEmpty) {
        return '${p.name} (@${p.ownerEmailHint})';
      }
      return p.name;
    } catch (_) {
      return 'Portföy';
    }
  }

  Widget _buildSharedIconForSelected() {
    if (_seciliPortfoyId == null) return const SizedBox.shrink();
    try {
      final p = _portfoyler.firstWhere((p) => p.id == _seciliPortfoyId);
      if (p.isShared) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(Icons.people_outline, size: 20, color: AppTheme.navyBlue),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }

  List<PortfolioRow> get _siraliListe {
    final list = List<PortfolioRow>.from(_liste);
    double portfoyDegeri(PortfolioRow item) {
      final guncel = _portfoyGuncelFiyatlar[item.symbol];
      return guncel != null ? item.totalQuantity * guncel.fiyat : item.toplamDeger;
    }
    double? karZararYuzde(PortfolioRow item) {
      final guncel = portfoyDegeri(item);
      final maliyet = item.toplamDeger;
      if (maliyet <= 0) return null;
      return ((guncel - maliyet) / maliyet) * 100;
    }
    double karZarar(PortfolioRow item) =>
        portfoyDegeri(item) - item.toplamDeger;

    switch (_siralama) {
      case 'adet':
        list.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
        break;
      case 'fiyat':
        list.sort((a, b) => b.averageCost.compareTo(a.averageCost));
        break;
      case 'deger':
        list.sort((a, b) => portfoyDegeri(b).compareTo(portfoyDegeri(a)));
        break;
      case 'kar_zarar':
        list.sort((a, b) => karZarar(b).compareTo(karZarar(a)));
        break;
      case 'kar_zarar_yuzde': {
        list.sort((a, b) {
          final pa = karZararYuzde(a) ?? double.negativeInfinity;
          final pb = karZararYuzde(b) ?? double.negativeInfinity;
          return pb.compareTo(pa);
        });
        break;
      }
      case 'az':
      default:
        list.sort((a, b) => a.symbol.compareTo(b.symbol));
        break;
    }
    return list;
  }

  Future<Iterable<HisseAramaSonucu>> _aramaYap(String metin) async {
    if (metin.trim().length < 2) return [];
    if (!mounted) return [];
    try {
      return await YahooFinanceService.hisseAraListele(metin);
    } catch (_) {
      // Hata durumunda boş liste döndür
      return [];
    }
  }

  Future<void> _hisseSec(HisseAramaSonucu sonuc) async {
    // Overlay'in tamamen kapanmasını bekle (assertion hatası önlemi)
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    
    // Focus'u kaldır ve overlay'in kapanmasını bekle
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    setState(() {
      _araniyor = true;
      _aramaHataMesaji = null;
      _arananHisse = null;
    });

    try {
      final bilgi = await YahooFinanceService.hisseAra(sonuc.sembol);
      if (!mounted) return;
      setState(() {
        _arananHisse = bilgi;
        _fiyatController.text = bilgi.fiyat.toStringAsFixed(2);
        _araniyor = false;
      });
    } on YahooFinanceHata catch (e) {
      if (!mounted) return;
      setState(() {
        _araniyor = false;
        _aramaHataMesaji = e.mesaj;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _araniyor = false;
        _aramaHataMesaji =
            'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
      });
    }
  }

  void _fiyatArtir(TextEditingController ctrl) {
    final str = ctrl.text.trim().replaceAll(',', '.');
    final fiyat = double.tryParse(str) ?? 0;
    final yeni = ((fiyat * 100).round() + 1) / 100;
    ctrl.text = yeni.toStringAsFixed(2);
  }

  void _fiyatAzalt(TextEditingController ctrl) {
    final str = ctrl.text.trim().replaceAll(',', '.');
    final fiyat = double.tryParse(str) ?? 0;
    if (fiyat <= 0.01) return;
    final yeni = ((fiyat * 100).round() - 1) / 100;
    ctrl.text = yeni.toStringAsFixed(2);
  }

  double _guncelFiyatAl() {
    final str = _fiyatController.text.trim().replaceAll(',', '.');
    return double.tryParse(str) ?? 0;
  }

  void _aramaIptal() {
    setState(() {
      _arananHisse = null;
      _aramaHataMesaji = null;
      _aramaKey++;
      _adetController.clear();
      _fiyatController.clear();
    });
  }

  /// Portföy listesinde sağa süpürünce "Alış" ile açılır: bu hisse için alım ekranını açar.
  Future<void> _alisDiyaloguAc(PortfolioRow item) async {
    setState(() {
      _araniyor = true;
      _aramaHataMesaji = null;
      _arananHisse = null;
    });
    try {
      final bilgi = await YahooFinanceService.hisseAra(item.symbol);
      if (!mounted) return;
      setState(() {
        _arananHisse = bilgi;
        _fiyatController.text = bilgi.fiyat.toStringAsFixed(2);
        _adetController.clear();
        _araniyor = false;
      });
    } on YahooFinanceHata catch (e) {
      if (!mounted) return;
      setState(() {
        _araniyor = false;
        _aramaHataMesaji = e.mesaj;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _araniyor = false;
        _aramaHataMesaji = 'Bağlantı hatası. İnternet bağlantınızı kontrol edin.';
      });
    }
  }

  Future<void> _portfoyeEkle() async {
    final hisse = _arananHisse;
    if (hisse == null) {
      _hataGoster('Listeden bir hisse seçin.');
      return;
    }

    final adetStr = _adetController.text.trim();
    if (adetStr.isEmpty) {
      _hataGoster('Kaç adet aldığınızı girin.');
      return;
    }

    final adet = int.tryParse(adetStr);
    if (adet == null || adet < 1) {
      _hataGoster('Geçerli bir adet girin (1 veya daha fazla).');
      return;
    }

    final fiyat = _guncelFiyatAl();
    if (fiyat <= 0) {
      _hataGoster('Geçerli bir fiyat girin.');
      return;
    }

    // "Tümü" seçiliyse hangi portföye ekleneceğini sor (veya tek portföy varsa direkt Ana Portföy)
    String? eklenecekPortfoyId = _seciliPortfoyId;
    if (eklenecekPortfoyId == null) {
      final duzenlenebilirPortfoyler = _portfoyler.where((p) => !p.isSharedWithMe).toList();
      if (duzenlenebilirPortfoyler.isEmpty) {
        _hataGoster('Düzenlenebilir portföy bulunamadı. Önce yeni bir portföy oluşturun.');
        return;
      }
      final anaPortfoy = duzenlenebilirPortfoyler.where((p) => p.name == 'Ana Portföy').isEmpty
          ? duzenlenebilirPortfoyler.first
          : duzenlenebilirPortfoyler.firstWhere((p) => p.name == 'Ana Portföy');
      
      if (duzenlenebilirPortfoyler.length == 1) {
        eklenecekPortfoyId = anaPortfoy.id;
      } else {
        String? dialogSecilenId = anaPortfoy.id;
        eklenecekPortfoyId = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Hangi portföye eklenecek?'),
            content: DropdownButtonFormField<String>(
              initialValue: dialogSecilenId,
              decoration: const InputDecoration(
                labelText: 'Portföy',
                border: OutlineInputBorder(),
              ),
              items: duzenlenebilirPortfoyler.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (value) {
                if (value != null) {
                  dialogSecilenId = value;
                  setDialogState(() {});
                }
              },
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, dialogSecilenId),
                child: const Text('Ekle'),
              ),
            ],
          ),
        ),
      );
        if (eklenecekPortfoyId == null) return;
      }
    }

    final binde = double.tryParse(_komisyonBindeController.text.trim().replaceAll(',', '.')) ?? 1.0;
    final komisyonOrani = (binde / 1000).clamp(0.0, 1.0);

    try {
      await SupabasePortfolioService.alimEkle(
        symbol: hisse.sembol,
        name: hisse.tamAd,
        quantity: adet,
        price: fiyat,
        islemTarihi: _seciliTarih,
        portfolioId: eklenecekPortfoyId,
        commissionRate: komisyonOrani,
      );
      if (_komisyonVarsayilanOlsun) {
        await SupabasePortfolioService.portfoyKomisyonOranGuncelle(eklenecekPortfoyId, komisyonOrani);
        await _portfoyleriYukle();
      }
      setState(() {
        _arananHisse = null;
        _adetController.clear();
        _fiyatController.clear();
        _seciliTarih = DateTime.now();
        _komisyonVarsayilanOlsun = false;
        _aramaKey++;
      });
      await _portfoyYukle();
      if (mounted) _basariGoster('Hisse portföye eklendi.');
    } catch (e) {
      _hataGoster('Kayıt hatası: ${e.toString().split('\n').first}');
    }
  }

  Future<DateTime?> _tarihSec(BuildContext ctx, DateTime baslangic) async {
    if (!mounted) return null;
    
    try {
      final secilen = await showDatePicker(
        context: ctx,
        initialDate: baslangic,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        locale: const Locale('tr', 'TR'),
        helpText: 'İşlem Tarihi',
        cancelText: 'İptal',
        confirmText: 'Seç',
      );
      if (secilen == null || !mounted) return null;

      // Sadece tarih seçimi, saat bilgisi günün başına ayarlanıyor
      return DateTime(
        secilen.year,
        secilen.month,
        secilen.day,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> _satisDiyaloguAc(PortfolioRow item) async {
    final adetCtrl = TextEditingController(
      text: item.totalQuantity.toInt().toString(),
    );
    final fiyatCtrl = TextEditingController();
    final portfoy = item.portfolioId != null
        ? _portfoyler.where((p) => p.id == item.portfolioId).firstOrNull
        : null;
    final portfoyKomisyon = portfoy?.commissionRate ?? 0.001;
    final komisyonCtrl = TextEditingController(
      text: (portfoyKomisyon * 1000).toStringAsFixed(
        (portfoyKomisyon * 1000).truncateToDouble() == portfoyKomisyon * 1000 ? 0 : 2,
      ),
    );
    DateTime seciliTarih = DateTime.now();
    double? guncelFiyat;

    try {
      final bilgi = await YahooFinanceService.hisseAra(item.symbol);
      guncelFiyat = bilgi.fiyat;
      fiyatCtrl.text = bilgi.fiyat.toStringAsFixed(2);
    } catch (_) {
      fiyatCtrl.text = item.averageCost.toStringAsFixed(2);
    }

    if (!mounted) {
      adetCtrl.dispose();
      fiyatCtrl.dispose();
      komisyonCtrl.dispose();
      return false;
    }
    
    // Dialog sonucunu ve değerleri tutmak için değişkenler
    int? secilenAdet;
    double? secilenFiyat;
    DateTime? secilenTarih;
    double? secilenKomisyonBinde;
    bool secilenKomisyonVarsayilan = false;
    bool satisKomisyonVarsayilan = false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final adet = int.tryParse(adetCtrl.text.trim()) ?? 0;
            final fiyat = double.tryParse(
                    fiyatCtrl.text.trim().replaceAll(',', '.')) ??
                0;
            final toplamGelir = adet * fiyat;
            final maxAdet = item.totalQuantity.toInt();

            return AlertDialog(
              title: Text('Satış — ${LogoService.symbolForDisplay(item.symbol)}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eldeki: ${item.totalQuantity.toStringAsFixed(0)} adet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: adetCtrl,
                      decoration: InputDecoration(
                        labelText: 'Satılacak adet (max $maxAdet)',
                        border: const OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fiyatCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Satış fiyatı (TL)',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.filled(
                              onPressed: () {
                                _fiyatArtir(fiyatCtrl);
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.arrow_drop_up),
                            ),
                            IconButton.filled(
                              onPressed: () {
                                _fiyatAzalt(fiyatCtrl);
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.arrow_drop_down),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (guncelFiyat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Güncel fiyat: ${guncelFiyat.toStringAsFixed(2)} TL',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        if (!mounted) return;
                        final mevcutTarih = secilenTarih ?? seciliTarih;
                        final tarih = await _tarihSec(dialogContext, mevcutTarih);
                        if (tarih != null && mounted) {
                          secilenTarih = tarih;
                          setDialogState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İşlem Tarihi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd.MM.yyyy')
                                        .format(secilenTarih ?? seciliTarih),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today,
                                color: Colors.grey[600], size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: komisyonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Komisyon oranı (binde)',
                        hintText: 'Binde 1 = 0.001',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                      ],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: satisKomisyonVarsayilan,
                      onChanged: (v) {
                        satisKomisyonVarsayilan = v ?? false;
                        setDialogState(() {});
                      },
                      title: const Text('Bu portföy için varsayılan olarak kullan', style: TextStyle(fontSize: 14)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text('Toplam gelir:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${toplamGelir.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () {
                    final a = int.tryParse(adetCtrl.text.trim()) ?? 0;
                    final f = double.tryParse(
                            fiyatCtrl.text.trim().replaceAll(',', '.')) ??
                        0;
                    if (a < 1) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text('En az 1 adet girin'),
                            behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    if (a > maxAdet) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Eldeki adetten fazla satamazsınız (max $maxAdet)'),
                            behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    if (f <= 0) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                            content: Text('Geçerli bir fiyat girin'),
                            behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    // Değerleri kaydet
                    secilenAdet = a;
                    secilenFiyat = f;
                    secilenTarih = secilenTarih ?? seciliTarih;
                    secilenKomisyonBinde = double.tryParse(komisyonCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;
                    secilenKomisyonVarsayilan = satisKomisyonVarsayilan;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Satışı Onayla'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted || secilenAdet == null || secilenFiyat == null || secilenTarih == null) {
      Future.microtask(() {
        adetCtrl.dispose();
        fiyatCtrl.dispose();
        komisyonCtrl.dispose();
      });
      return false;
    }

    Future.microtask(() {
      adetCtrl.dispose();
      fiyatCtrl.dispose();
      komisyonCtrl.dispose();
    });

    final komisyonOrani = ((secilenKomisyonBinde ?? 1.0) / 1000).clamp(0.0, 1.0);
    try {
      await SupabasePortfolioService.satimEkle(
        symbol: item.symbol,
        name: item.name,
        quantity: secilenAdet!.toDouble(),
        price: secilenFiyat!,
        islemTarihi: secilenTarih!,
        portfolioId: item.portfolioId,
        commissionRate: komisyonOrani,
      );
      if (secilenKomisyonVarsayilan && item.portfolioId != null) {
        await SupabasePortfolioService.portfoyKomisyonOranGuncelle(item.portfolioId!, komisyonOrani);
        await _portfoyleriYukle();
      }
      if (mounted) {
        final mesaj = 'Satış kaydedildi. Toplam gelir: ${(secilenAdet! * secilenFiyat!).toStringAsFixed(2)} TL';
        // Slidable kapanırken setState _dependents hatası verir. Önce Slidable'ın tamamen kapanması için bekleyip sonra güncelle.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _basariGoster(mesaj);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _portfoyYukle();
          });
        });
      }
      return false;
    } catch (e) {
      _hataGoster('Satış hatası: ${e.toString().split('\n').first}');
      return false;
    }
  }

  Future<void> _hisseTasimaDiyaloguAc(PortfolioRow item) async {
    if (_seciliPortfoyId == null) return;
    final kaynakId = item.portfolioId ?? _seciliPortfoyId;
    if (kaynakId == null) return;

    final hedefCuzdanlar =
        _portfoyler.where((p) => p.id != kaynakId).toList();
    if (hedefCuzdanlar.isEmpty) {
      _hataGoster('Taşınabilecek başka portföy yok. Önce yeni portföy oluşturun.');
      return;
    }

    String? secilenId = hedefCuzdanlar.first.id;
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Taşı — ${LogoService.symbolForDisplay(item.symbol)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.totalQuantity.toStringAsFixed(0)} adet hisseyi hangi portföye taşımak istiyorsunuz?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: secilenId,
                decoration: const InputDecoration(
                  labelText: 'Hedef portföy',
                  border: OutlineInputBorder(),
                ),
                items: hedefCuzdanlar
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    secilenId = v;
                    setDialogState(() {});
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, secilenId),
              child: const Text('Taşı'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await SupabasePortfolioService.hisseTasima(
          symbol: item.symbol,
          name: item.name,
          fromPortfolioId: kaynakId,
          toPortfolioId: result,
        );
        if (mounted) {
          _basariGoster('Hisse taşındı.');
          _portfoyYukle();
        }
      } catch (e) {
        if (mounted) _hataGoster(e.toString().split('\n').first);
      }
    }
  }

  void _hataGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _basariGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mesaj),
        backgroundColor: AppTheme.emeraldGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _portfoyUzunBasMenuAc() {
    if (_seciliPortfoyId == null) return;
    final secili = _portfoyler.where((p) => p.id == _seciliPortfoyId).firstOrNull;
    if (secili == null) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(secili.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.darkSlate)),
              const SizedBox(height: 16),
              if (!secili.isSharedWithMe && secili.name != 'Ana Portföy') ...[
                ListTile(
                  leading: const Icon(Icons.share, color: AppTheme.navyBlue),
                  title: Text(secili.hasShares ? 'Portföyü Paylaş (mevcut paylaşımlar)' : 'Portföyü Paylaş'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortfolioShareInfoScreen(portfolio: secili),
                      ),
                    ).then((_) => _portfoyleriYukle());
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (secili.isSharedWithMe) ...[
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppTheme.navyBlue),
                  title: const Text('Paylaşım Bilgileri'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PortfolioShareInfoScreen(portfolio: secili),
                      ),
                    ).then((_) => _portfoyleriYukle());
                  },
                ),
                const SizedBox(height: 16),
              ],
              if (!secili.isSharedWithMe && secili.name != 'Ana Portföy')
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.softRed),
                  title: const Text('Portföyü Sil'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _cuzdanSilDiyaloguAc();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cuzdanSilDiyaloguAc() async {
    if (_seciliPortfoyId == null) return;
    final secili = _portfoyler.where((p) => p.id == _seciliPortfoyId).firstOrNull;
    if (secili == null || secili.name == 'Ana Portföy' || secili.isSharedWithMe) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Portföyü Sil'),
        content: const Text(
          'Bu portföy silinecek ve içindeki tüm hisseler Ana Portföy\'e taşınacak. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.softRed),
            child: const Text('Sil ve Taşı'),
          ),
        ],
      ),
    );
    if (onay == true && _seciliPortfoyId != null && mounted) {
      try {
        await SupabasePortfolioService.cuzdanTasimaVeSil(_seciliPortfoyId!);
        setState(() => _seciliPortfoyId = null);
        await _portfoyleriYukle();
        await _portfoyYukle();
        if (mounted) _basariGoster('Portföy silindi, hisseler Ana Portföy\'e taşındı.');
      } catch (e) {
        if (mounted) _hataGoster(e.toString().split('\n').first);
      }
    }
  }

  Widget _buildCuzdanSecimItem(
    BuildContext ctx, {
    required IconData icon,
    required Widget label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final textColor = Theme.of(ctx).colorScheme.onSurface;
    return Material(
      color: selected ? AppTheme.navyBlue.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.navyBlue, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: DefaultTextStyle(
                  style: GoogleFonts.inter(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                  child: label,
                ),
              ),
              if (trailing != null) ...[trailing, const SizedBox(width: 8)],
              if (selected) Icon(Icons.check_rounded, color: AppTheme.navyBlue, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _yeniPortfoyDiyalogu() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _YeniPortfoyDiyalogContent(),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await SupabasePortfolioService.portfoyOlustur(result);
        await _portfoyleriYukle();
        if (mounted) _basariGoster('Portföy oluşturuldu');
      } catch (e) {
        _hataGoster('Portföy oluşturulamadı: ${e.toString().split('\n').first}');
      }
    }
  }


  String _formatTutar(double v) =>
      NumberFormat('#,##0.##', 'tr_TR').format(v);

  Future<void> _pullToRefresh() async {
    await _dovizKurlariniYukle();
    try {
      final liste = await SupabasePortfolioService.portfoyYukle(
        portfolioId: _seciliPortfoyId,
      );
      if (mounted) setState(() => _liste = liste);
      await _portfoyGuncelFiyatlarYukle();
    } catch (_) {}
    if (mounted) await _portfoyleriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
          : ValueListenableBuilder<double>(
              valueListenable: _pullExtent,
              builder: (context, extent, _) {
                final opacity = extent > 0 ? (1 - (extent / 100).clamp(0.0, 0.5)) : 1.0;
                final offset = extent > 0 ? (extent * 0.6) : 0.0;
                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: _pullToRefresh,
                        builder: (
                          context,
                          refreshState,
                          pulledExtent,
                          refreshTriggerPullDistance,
                          refreshIndicatorExtent,
                        ) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_pullExtent.value != pulledExtent) {
                              _pullExtent.value = pulledExtent;
                            }
                          });
                          return SizedBox(
                            height: refreshIndicatorExtent,
                            child: Center(
                              child: refreshState == RefreshIndicatorMode.refresh
                                  ? const _FinansOkuAnimasyonu()
                                  : Icon(
                                      Icons.trending_up_rounded,
                                      size: 32,
                                      color: AppTheme.navyBlue.withValues(
                                        alpha: (pulledExtent / refreshTriggerPullDistance).clamp(0.3, 1.0),
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      SliverAppBar(
                  expandedHeight: 100,
                  pinned: true,
                  centerTitle: true,
                  leadingWidth: 72,
                  backgroundColor: AppTheme.navyBlue,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Center(
                      child: AppLogo(size: 60, forDarkBackground: true),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(bottom: 14),
                    title: const SizedBox.shrink(),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.navyBlue, AppTheme.darkSlate],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                  iconTheme: const IconThemeData(color: Colors.white, size: 22),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('d MMM, EEEE', 'tr_TR').format(DateTime.now()),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'USD ${NumberFormat('#,##0.##', 'tr_TR').format(_usdKuru)} ₺  EUR ${NumberFormat('#,##0.##', 'tr_TR').format(_eurKuru)} ₺',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: AppTheme.bankCardDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Güncel Yaklaşık Değer',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: _fiyatlarMaskeli ? 'Fiyatları göster' : 'Fiyatları gizle',
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _fiyatlarMaskeli = !_fiyatlarMaskeli);
                                          },
                                          child: Icon(
                                            _fiyatlarMaskeli ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                            color: Colors.white.withValues(alpha: 0.9),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _fiyatlarMaskeli
                                          ? '****'
                                          : (_toplamParam.isFinite
                                              ? _formatTutar(_dovizCevir(_toplamParam))
                                              : '0.00'),
                                      style: GoogleFonts.inter(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _ModernDovizSecici(
                                    seciliDoviz: _seciliDoviz,
                                    onChanged: (v) {
                                      if (v != null) setState(() => _seciliDoviz = v);
                                    },
                                  ),
                                ],
                              ),
                              if (_portfoyKarZararYuzde != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fiyatlarMaskeli ? '****%' : '${_portfoyKarZararYuzde! >= 0 ? '+' : ''}${_portfoyKarZararYuzde!.toStringAsFixed(2)}%',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: _portfoyKarZararYuzde! >= 0
                                            ? AppTheme.emeraldGreen
                                            : AppTheme.softRed,
                                      ),
                                    ),
                                    if (_portfoyKarZararTutar != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _fiyatlarMaskeli ? '(**** ${_dovizSembolu()})' : '(${_portfoyKarZararTutar! >= 0 ? '+' : ''}${_formatTutar(_dovizCevir(_portfoyKarZararTutar!))} ${_dovizSembolu()})',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: _portfoyKarZararTutar! >= 0
                                              ? AppTheme.emeraldGreen
                                              : AppTheme.softRed,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Tüm Portföyler - hisse arama üstünde
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => setState(() => _portfoySecimAcik = !_portfoySecimAcik),
                              onLongPress: _seciliPortfoyId != null ? _portfoyUzunBasMenuAc : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_rounded, color: AppTheme.navyBlue, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _seciliPortfoyId == null ? 'Tüm Portföyler' : _portfoyBaslik,
                                              style: AppTheme.h2(context),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          _buildSharedIconForSelected(),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      _portfoySecimAcik ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      color: AppTheme.navyBlue,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_portfoySecimAcik) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppTheme.softShadow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCuzdanSecimItem(
                                  context,
                                  icon: Icons.list_rounded,
                                  label: const Text('Tümü'),
                                  selected: _seciliPortfoyId == null,
                                  onTap: () {
                                    setState(() {
                                      _seciliPortfoyId = null;
                                      _komisyonBindeController.text = '1';
                                      _portfoySecimAcik = false;
                                    });
                                    _portfoyYukle();
                                  },
                                ),
                                ..._portfoyler.expand((p) => [
                                  const SizedBox(height: 8),
                                  _buildCuzdanSecimItem(
                                    context,
                                    icon: Icons.account_balance_wallet_outlined,
                                    label: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            p.isSharedWithMe && (p.ownerEmailHint ?? '').isNotEmpty
                                                ? '${p.name} (@${p.ownerEmailHint})'
                                                : p.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (p.isShared) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                                        ],
                                      ],
                                    ),
                                    selected: _seciliPortfoyId == p.id,
                                    // Trailing removed since icon is now next to name
                                    onTap: () {
                                      final binde = (p.commissionRate ?? 0.001) * 1000;
                                      setState(() {
                                        _seciliPortfoyId = p.id;
                                        _komisyonBindeController.text = binde.toStringAsFixed(binde.truncateToDouble() == binde ? 0 : 2);
                                        _portfoySecimAcik = false;
                                      });
                                      _portfoyYukle();
                                    },
                                  ),
                                ]),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      setState(() => _portfoySecimAcik = false);
                                      _yeniPortfoyDiyalogu();
                                    },
                                    icon: const Icon(Icons.add_rounded, size: 20),
                                    label: const Text('Yeni Portföy'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.navyBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 20),
                        if (_seciliPortfoyDuzenlenebilir) ...[
                          Autocomplete<HisseAramaSonucu>(
                            key: ValueKey(_aramaKey),
                            optionsBuilder: (editingValue) {
                              final metin = editingValue.text.trim();
                              if (metin.length < 2) return Future.value([]);
                              if (!mounted) return Future.value([]);
                              return _aramaYap(metin).then((sonuc) {
                                if (!mounted) return <HisseAramaSonucu>[];
                                return sonuc;
                              }).catchError((_) {
                                return <HisseAramaSonucu>[];
                              });
                            },
                            displayStringForOption: (o) =>
                                '${LogoService.symbolForDisplay(o.sembol)} - ${o.goruntulenecekAd}',
                            fieldViewBuilder: (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  TextInputFormatter.withFunction((old, replace) => TextEditingValue(
                                    text: replace.text.toUpperCase(),
                                    selection: replace.selection,
                                  )),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Hisse ara',
                                  hintText: 'THYAO, GARAN...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: textEditingController,
                                    builder: (context, value, _) {
                                      if (value.text.isEmpty) return const SizedBox.shrink();
                                      return IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => textEditingController.clear(),
                                        tooltip: 'Temizle',
                                      );
                                    },
                                  ),
                                ),
                                onSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 240),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final opt = options.elementAt(index);
                                        return InkWell(
                                          onTap: () {
                                            // Overlay kapanmadan önce callback'i çağır
                                            if (mounted) {
                                              onSelected(opt);
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            child: Row(
                                              children: [
                                                StockLogo(symbol: opt.sembol, size: 36),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        LogoService.symbolForDisplay(opt.sembol),
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        opt.goruntulenecekAd,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey[600],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            onSelected: _hisseSec,
                          ),
                          if (_araniyor)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(),
                            ),
                          if (_aramaHataMesaji != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _aramaHataMesaji!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        if (_arananHisse != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: AppTheme.cardDecoration(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    StockLogo(symbol: _arananHisse!.sembol, size: 48),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            LogoService.symbolForDisplay(_arananHisse!.sembol),
                                            style: AppTheme.symbol(context),
                                          ),
                                          Text(
                                            _arananHisse!.tamAd,
                                            style: AppTheme.bodySmall(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                          TextField(
                            controller: _fiyatController,
                            decoration: InputDecoration(
                              labelText: 'Fiyat (${AppTheme.currencyDisplay(_arananHisse!.paraBirimi)})',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              hintText: '0.00',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _fiyatArtir(_fiyatController),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.keyboard_arrow_up_rounded,
                                            color: AppTheme.emeraldGreen,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _fiyatAzalt(_fiyatController),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            color: AppTheme.softRed,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _adetController,
                            decoration: InputDecoration(
                              labelText: 'Alım Adeti',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              hintText: 'Adet',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final tarih = await _tarihSec(context, _seciliTarih);
                              if (tarih != null && mounted) {
                                setState(() => _seciliTarih = tarih);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'İşlem Tarihi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('dd.MM.yyyy')
                                            .format(_seciliTarih),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.calendar_today,
                                      color: Colors.grey[600]),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _komisyonBindeController,
                            decoration: InputDecoration(
                              labelText: 'Komisyon oranı (binde)',
                              hintText: 'Binde 1 = 0.001',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Varsayılan',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Checkbox(
                                    value: _komisyonVarsayilanOlsun,
                                    onChanged: (v) => setState(() => _komisyonVarsayilanOlsun = v ?? false),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filled(
                                onPressed: _seciliPortfoyDuzenlenebilir ? _portfoyeEkle : null,
                                icon: const Icon(Icons.add_chart),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.navyBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(14),
                                  minimumSize: const Size(52, 52),
                                ),
                                tooltip: 'Portföye Ekle',
                              ),
                              const SizedBox(width: 16),
                              IconButton.filled(
                                onPressed: _aramaIptal,
                                icon: const Icon(Icons.close, size: 24),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppTheme.softRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(14),
                                  minimumSize: const Size(52, 52),
                                ),
                                tooltip: 'İptal',
                              ),
                            ],
                          ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_liste.length} hisse', style: AppTheme.bodySmall(context)),
                            if (_liste.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: DropdownButton<String>(
                                  value: _siralama,
                                  underline: const SizedBox(),
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade700, size: 20),
                                  isDense: true,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                  items: const [
                                    DropdownMenuItem(value: 'az', child: Text('A-Z')),
                                    DropdownMenuItem(value: 'adet', child: Text('Adet')),
                                    DropdownMenuItem(value: 'fiyat', child: Text('Fiyat')),
                                    DropdownMenuItem(value: 'deger', child: Text('Değer')),
                                    DropdownMenuItem(value: 'kar_zarar', child: Text('Kar/Zarar')),
                                    DropdownMenuItem(value: 'kar_zarar_yuzde', child: Text('%Kar/Zarar')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _siralama = v);
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_liste.isNotEmpty)
                          ..._siraliListe.asMap().entries.map(
                                (entry) {
                                  final item = entry.value;
                                  final guncelBilgi = _portfoyGuncelFiyatlar[item.symbol];
                                  final guncelDeger = guncelBilgi != null ? item.totalQuantity * guncelBilgi.fiyat : null;
                                  final maliyet = item.toplamDeger;
                                  final karZararYuzde = (guncelDeger != null && maliyet > 0)
                                      ? ((guncelDeger - maliyet) / maliyet) * 100
                                      : null;
                                  final karZararTutar = guncelDeger != null ? guncelDeger - maliyet : null;
                                  final karda = karZararYuzde != null && karZararYuzde >= 0;
                                  final hedefCuzdanlar = _portfoyler
                                      .where((p) => p.id != _seciliPortfoyId)
                                      .toList();
                                  final tasimaGoster = _seciliPortfoyDuzenlenebilir &&
                                      _seciliPortfoyId != null &&
                                      (item.portfolioId == _seciliPortfoyId) &&
                                      hedefCuzdanlar.isNotEmpty;
                                  final aksiyonlarVar = _rowAlimSatimIzinli(item);
                                  final portfoyKayit = item.portfolioId != null
                                      ? _portfoyler.where((p) => p.id == item.portfolioId).firstOrNull
                                      : null;
                                  final portfoyAdi = portfoyKayit?.name;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: aksiyonlarVar
                                        ? Slidable(
                                            key: Key('${item.symbol}-${entry.key}'),
                                            startActionPane: ActionPane(
                                              motion: const StretchMotion(),
                                              extentRatio: 0.25,
                                              children: [
                                                SlidableAction(
                                                  onPressed: (ctx) {
                                                    Slidable.of(ctx)?.close();
                                                    _alisDiyaloguAc(item);
                                                  },
                                                  backgroundColor: AppTheme.emeraldGreen,
                                                  foregroundColor: Colors.white,
                                                  icon: Icons.add_chart,
                                                  label: 'Alış',
                                                ),
                                              ],
                                            ),
                                            endActionPane: ActionPane(
                                              motion: const StretchMotion(),
                                              extentRatio: tasimaGoster ? 0.5 : 0.25,
                                              children: [
                                          if (tasimaGoster)
                                            SlidableAction(
                                              onPressed: (_) =>
                                                  _hisseTasimaDiyaloguAc(item),
                                              backgroundColor: AppTheme.navyBlue,
                                              foregroundColor: Colors.white,
                                              icon: Icons.drive_file_move_rounded,
                                              label: 'Taşı',
                                            ),
                                          SlidableAction(
                                            onPressed: (ctx) {
                                              Slidable.of(ctx)?.close();
                                              _satisDiyaloguAc(item);
                                            },
                                            backgroundColor: AppTheme.softRed,
                                            foregroundColor: Colors.white,
                                            icon: Icons.sell,
                                            label: 'Satış',
                                          ),
                                        ],
                                      ),
                                            child: _HisseKarti(
                                        item: item,
                                        guncelDeger: guncelDeger,
                                        karZararYuzde: karZararYuzde,
                                        karZararTutar: karZararTutar,
                                        karda: karda,
                                        hasNote: _notuOlanSemboller.contains(item.symbol),
                                        portfoyAdi: portfoyAdi,
                                        isSharedWithMe: portfoyKayit?.isSharedWithMe ?? false,
                                        hasOutgoingShares: portfoyKayit != null &&
                                            portfoyKayit.hasShares &&
                                            !portfoyKayit.isSharedWithMe,
                                        ownerEmailHint: portfoyKayit?.ownerEmailHint,
                                        degisimYuzde: guncelBilgi?.degisimYuzde, // Added
                                        formatTutar: (v) => _fiyatlarMaskeli ? '****' : _formatTutar(v),
                                        dovizCevir: _dovizCevir,
                                        dovizSembolu: _dovizSembolu,
                                        acik: false,
                                        onToggle: () {},
                                        onDetay: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => HisseDetayPage(
                                                item: item,
                                                seciliDoviz: _seciliDoviz,
                                                usdKuru: _usdKuru,
                                                eurKuru: _eurKuru,
                                                readOnly: !_rowAlimSatimIzinli(item),
                                                portfoyAdi: portfoyAdi,
                                                isMasked: _fiyatlarMaskeli,
                                              ),
                                            ),
                                          ).then((_) => _portfoyYukle());
                                        },
                                        onSatis: () => _satisDiyaloguAc(item),
                                      ),
                                    )
                                        : _HisseKarti(
                                            item: item,
                                            guncelDeger: guncelDeger,
                                            karZararYuzde: karZararYuzde,
                                            karZararTutar: karZararTutar,
                                            karda: karda,
                                            hasNote: _notuOlanSemboller.contains(item.symbol),
                                            portfoyAdi: portfoyAdi,
                                            isSharedWithMe: portfoyKayit?.isSharedWithMe ?? false,
                                            hasOutgoingShares: portfoyKayit != null &&
                                                portfoyKayit.hasShares &&
                                                !portfoyKayit.isSharedWithMe,
                                            ownerEmailHint: portfoyKayit?.ownerEmailHint,
                                            degisimYuzde: guncelBilgi?.degisimYuzde, // Added
                                            formatTutar: (v) => _fiyatlarMaskeli ? '****' : _formatTutar(v),
                                            dovizCevir: _dovizCevir,
                                            dovizSembolu: _dovizSembolu,
                                            acik: false,
                                            onToggle: () {},
                                            onDetay: () {
                                              final portfoyAdi = item.portfolioId != null
                                                  ? _portfoyler.where((p) => p.id == item.portfolioId).firstOrNull?.name
                                                  : null;
                                              Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => HisseDetayPage(
                                                item: item,
                                                seciliDoviz: _seciliDoviz,
                                                usdKuru: _usdKuru,
                                                eurKuru: _eurKuru,
                                                readOnly: !_rowAlimSatimIzinli(item),
                                                portfoyAdi: portfoyAdi,
                                                isMasked: _fiyatlarMaskeli,
                                              ),
                                            ),
                                              ).then((_) => _portfoyYukle());
                                            },
                                            onSatis: () {},
                                          ),
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        );
        },
      ),
    );
  }
}

class _FinansOkuAnimasyonu extends StatefulWidget {
  const _FinansOkuAnimasyonu();

  @override
  State<_FinansOkuAnimasyonu> createState() => _FinansOkuAnimasyonuState();
}

class _FinansOkuAnimasyonuState extends State<_FinansOkuAnimasyonu>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: child,
        );
      },
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.emeraldGreen, AppTheme.softRed],
        ).createShader(bounds),
        blendMode: BlendMode.srcIn,
        child: Icon(Icons.trending_up_rounded, size: 36, color: Colors.white),
      ),
    );
  }
}

class _YeniPortfoyDiyalogContent extends StatefulWidget {
  @override
  State<_YeniPortfoyDiyalogContent> createState() => _YeniPortfoyDiyalogContentState();
}

class _YeniPortfoyDiyalogContentState extends State<_YeniPortfoyDiyalogContent> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Portföy'),
      content: TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Portföy Adı',
          hintText: 'Örn: Ana Portföy, Yatırım 1',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () {
            final ad = _nameCtrl.text.trim();
            if (ad.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Portföy adı gerekli'), behavior: SnackBarBehavior.floating),
              );
              return;
            }
            Navigator.pop(context, ad);
          },
          child: const Text('Oluştur'),
        ),
      ],
    );
  }
}

class _ModernDovizSecici extends StatelessWidget {
  final String seciliDoviz;
  final ValueChanged<String?> onChanged;

  const _ModernDovizSecici({
    required this.seciliDoviz,
    required this.onChanged,
  });

  String _sembol(String k) {
    switch (k) {
      case 'TL': return '₺';
      case 'USD': return 'USD';
      case 'EUR': return 'EUR';
      default: return k;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(value: 'TL', child: Text('₺ TL', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
        PopupMenuItem(value: 'USD', child: Text('\$ USD', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
        PopupMenuItem(value: 'EUR', child: Text('€ EUR', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _sembol(seciliDoviz),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
        ],
      ),
    );
  }
}

/// Not varken ikon + zemin (kartta kolay seçilir)
const _notIconBrightLight = Color(0xFF1D4ED8);
const _notIconBrightDark = Color(0xFF93C5FD);
const _notIconBgLight = Color(0xFFDBEAFE);
const _notIconBgDark = Color(0xFF1E3A5F);

class _HisseKarti extends StatefulWidget {
  final PortfolioRow item;
  /// Güncel piyasa değeri (adet × güncel fiyat). Yoksa kart maliyet (toplamDeger) gösterir.
  final double? guncelDeger;
  final double? karZararYuzde;
  final double? karZararTutar;
  final bool karda;
  final bool hasNote;
  final String? portfoyAdi;
  /// Başkasının bana paylaştığı portföy
  final bool isSharedWithMe;
  /// Sahibi olduğum ve başkalarıyla paylaştığım portföy
  final bool hasOutgoingShares;
  final String? ownerEmailHint;
  final double? degisimYuzde; // Added
  final String Function(double) formatTutar;
  final double Function(double) dovizCevir;
  final String Function() dovizSembolu;
  final bool acik;
  final VoidCallback onToggle;
  final VoidCallback onDetay;
  final VoidCallback onSatis;

  const _HisseKarti({
    required this.item,
    this.guncelDeger,
    required this.karZararYuzde,
    this.karZararTutar,
    required this.karda,
    this.hasNote = false,
    this.portfoyAdi,
    this.isSharedWithMe = false,
    this.hasOutgoingShares = false,
    this.ownerEmailHint,
    this.degisimYuzde, // Added
    required this.formatTutar,
    required this.dovizCevir,
    required this.dovizSembolu,
    required this.acik,
    required this.onToggle,
    required this.onDetay,
    required this.onSatis,
  });

  @override
  State<_HisseKarti> createState() => _HisseKartiState();
}

class _HisseKartiState extends State<_HisseKarti> {
  List<StockNote>? _notlar;
  bool _notlarYukleniyor = false;
  bool _notlarAcik = false;

  @override
  void initState() {
    super.initState();
    if (_notlarAcik) _notlariYukle();
  }

  @override
  void didUpdateWidget(_HisseKarti oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget güncellendiğinde yeniden yükleme yapmaya gerek yok
  }

  Future<void> _notlariYukle() async {
    if (_notlar != null) return;
    setState(() => _notlarYukleniyor = true);
    try {
      final notlar = await SupabasePortfolioService.notlariYukle(widget.item.symbol);
      if (mounted) {
        setState(() {
          _notlar = notlar;
          _notlarYukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _notlar = [];
          _notlarYukleniyor = false;
        });
      }
    }
  }

  Future<void> _notEkle() async {
    final noteCtrl = TextEditingController();
    String? notMetni;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Not Ekle — ${LogoService.symbolForDisplay(widget.item.symbol)}'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(
            labelText: 'Not',
            hintText: 'Hisse ile ilgili notunuzu yazın...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
            },
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Not boş olamaz'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              notMetni = noteCtrl.text.trim();
              Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    // Route kapanırken TextField hâlâ controller'a bağlı olabiliyor; hemen dispose _dependents assert'ine yol açar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      noteCtrl.dispose();
    });

    final metin = notMetni?.trim();
    final symbol = widget.item.symbol;
    if (result != true || metin == null || metin.isEmpty) return;

    try {
      await SupabasePortfolioService.notEkle(symbol, metin);
      // UI güncellemesini sonraki frame'e ertele (_dependents.isEmpty hatasını önle)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _notlar = null;
          _notlarAcik = true;
        });
        _notlariYukle().then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Not eklendi'),
                backgroundColor: AppTheme.emeraldGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }).catchError((_) {});
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not eklenemedi: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.softRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
        border: widget.karZararYuzde != null
            ? Border.all(
                color: AppTheme.chipBgGreen(widget.karda),
                width: 1,
              )
            : null,
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onDetay,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    StockLogo(symbol: widget.item.symbol, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.portfoyAdi != null && widget.portfoyAdi!.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.portfoyAdi!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ) ??
                                        TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                if (widget.isSharedWithMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.people_outline, size: 12, color: Colors.grey[600]),
                                  if (widget.ownerEmailHint != null &&
                                      widget.ownerEmailHint!.isNotEmpty) ...[
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        '(@${widget.ownerEmailHint})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ) ??
                                            TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    ),
                                  ],
                                ],
                                if (widget.hasOutgoingShares) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.people_outline, size: 12, color: Colors.grey[600]),
                                  Icon(Icons.north_east, size: 11, color: Colors.grey[600]),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                          Row(
                            children: [
                              Text(
                                LogoService.symbolForDisplay(widget.item.symbol),
                                style: AppTheme.symbol(context).copyWith(fontSize: 14),
                              ),
                              if (widget.degisimYuzde != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.degisimYuzde! >= 0 ? '+' : ''}${widget.degisimYuzde!.toStringAsFixed(2)}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: widget.degisimYuzde! >= 0 ? AppTheme.emeraldGreen : AppTheme.softRed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.item.name,
                            style: AppTheme.bodySmall(context).copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${widget.formatTutar(widget.item.totalQuantity).contains('****') ? '****' : widget.item.totalQuantity.toStringAsFixed(0)} adet × ${widget.formatTutar(widget.dovizCevir(widget.item.averageCost))} ${widget.dovizSembolu()}',
                              style: AppTheme.bodySmall(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${widget.formatTutar(widget.dovizCevir(widget.guncelDeger ?? widget.item.toplamDeger))} ${widget.dovizSembolu()}',
                                    style: AppTheme.price(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              Builder(
                                builder: (context) {
                                  final notVar =
                                      _notlar != null ? _notlar!.isNotEmpty : widget.hasNote;
                                  final isDark = Theme.of(context).brightness == Brightness.dark;
                                  return IconButton(
                                    icon: const Icon(Icons.edit_note_rounded, size: 22),
                                    onPressed: () {
                                      setState(() => _notlarAcik = !_notlarAcik);
                                      if (_notlarAcik && _notlar == null) _notlariYukle();
                                    },
                                    color: notVar
                                        ? (isDark ? _notIconBrightDark : _notIconBrightLight)
                                        : (_notlarAcik ? AppTheme.navyBlue : Colors.grey.shade600),
                                    style: IconButton.styleFrom(
                                      padding: const EdgeInsets.all(6),
                                      minimumSize: const Size(36, 36),
                                      shape: const CircleBorder(),
                                      backgroundColor: notVar
                                          ? (isDark ? _notIconBgDark : _notIconBgLight)
                                          : null,
                                    ),
                                    tooltip: 'Notlar',
                                  );
                                },
                              ),
                            ],
                          ),
                          if (widget.karZararYuzde != null) ...[
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.karZararYuzde != null
                                        ? (widget.formatTutar(widget.karZararYuzde!).contains('****')
                                            ? '****%'
                                            : '${widget.karZararYuzde! >= 0 ? '+' : ''}${widget.karZararYuzde!.toStringAsFixed(1)}%')
                                        : '—',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.chipGreen(widget.karda),
                                    ),
                                  ),
                                  if (widget.karZararTutar != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.karZararTutar! >= 0 ? '+' : ''}${widget.formatTutar(widget.dovizCevir(widget.karZararTutar!))} ${widget.dovizSembolu()}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppTheme.chipGreen(widget.karda),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_notlarAcik) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.surfaceDark.withValues(alpha: 0.6)
                    : Colors.grey.shade50,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notlar',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkSlate,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    color: AppTheme.navyBlue,
                    onPressed: _notEkle,
                    tooltip: 'Not Ekle',
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _notlarYukleniyor
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _notlar == null
                      ? const SizedBox.shrink()
                      : _notlar!.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Henüz not yok',
                                style: AppTheme.bodySmall(context),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _notlar!.length,
                              itemBuilder: (context, index) {
                                final not = _notlar![index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              not.note,
                                              style: AppTheme.bodySmall(context),
                                              maxLines: null,
                                              overflow: TextOverflow.visible,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('dd.MM.yyyy HH:mm').format(not.createdAt),
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        color: AppTheme.softRed,
                                        onPressed: () async {
                                          try {
                                            await SupabasePortfolioService.notSil(not.id);
                                            if (mounted) {
                                              setState(() {
                                                _notlar = null; // Zorla yeniden yükleme için null yap
                                              });
                                              await _notlariYukle();
                                            }
                                          } catch (_) {}
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ],
      ),
    );
  }
}

