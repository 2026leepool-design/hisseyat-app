import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'crypto_detail_screen.dart';
import 'crypto_theme.dart';
import 'widgets/crypto_glass_app_bar.dart';
import 'models/crypto_coin.dart';
import 'services/crypto_service.dart';
import 'supabase_crypto_service.dart';
import 'widgets/crypto_logo.dart';

/// Kripto portföy sayfası – hisse portföyünün crypto karşılığı
class CryptoPortfolioPage extends StatefulWidget {
  const CryptoPortfolioPage({super.key});

  @override
  State<CryptoPortfolioPage> createState() => _CryptoPortfolioPageState();
}

class _CryptoPortfolioPageState extends State<CryptoPortfolioPage> {
  List<CryptoPortfolioRow> _liste = [];
  List<CryptoPortfolio> _portfoyler = [];
  String? _seciliPortfoyId;
  bool _yukleniyor = true;
  Map<String, CryptoCoin?> _guncelFiyatlar = {};
  Timer? _timer;
  final _adetController = TextEditingController();
  final _fiyatController = TextEditingController();
  CryptoCoin? _seciliCrypto;

  bool get _seciliPortfoyDuzenlenebilir {
    if (_seciliPortfoyId == null) return true;
    final p = _portfoyler.where((x) => x.id == _seciliPortfoyId).firstOrNull;
    if (p == null) return true;
    return !p.isShared; // CryptoPortfolio has isShared
  }

  bool _isRowDuzenlenebilir(CryptoPortfolioRow r) {
    final pid = r.portfolioId;
    if (pid == null) return _seciliPortfoyDuzenlenebilir;
    final p = _portfoyler.where((x) => x.id == pid).firstOrNull;
    if (p == null) return true;
    return !p.isShared;
  }

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _liste.isNotEmpty) _guncelFiyatlariYukle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adetController.dispose();
    _fiyatController.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final portfoyler = await SupabaseCryptoService.portfoyleriYukle();
      final liste = await SupabaseCryptoService.portfoyYukle(
        portfolioId: _seciliPortfoyId,
      );
      if (mounted) {
        setState(() {
          _portfoyler = portfoyler;
          _liste = liste;
          _yukleniyor = false;
        });
        _guncelFiyatlariYukle();
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _guncelFiyatlariYukle() async {
    if (_liste.isEmpty) return;
    final market = await CryptoService.getCryptoMarket();
    if (!mounted) return;
    final map = <String, CryptoCoin?>{};
    for (final c in market) {
      map[c.symbol] = c;
      map[c.displaySymbol] = c;
    }
    setState(() => _guncelFiyatlar = map);
  }

  double _toplamDeger() => _liste.fold(0, (sum, r) {
        final coin = _guncelFiyatlar[r.symbol];
        final fiyat = coin?.price ?? r.averageCost;
        return sum + r.totalQuantity * fiyat;
      });

  double _toplamMaliyet() => _liste.fold(0, (sum, r) => sum + r.toplamDeger);

  String _displaySymbol(String sym) =>
      sym.toUpperCase().endsWith('USDT') ? sym.substring(0, sym.length - 4) : sym;

  Future<void> _portfoyDegistir(CryptoPortfolioRow r) async {
    final kaynakId = r.portfolioId ?? _seciliPortfoyId ?? await SupabaseCryptoService.anaPortfoyId();
    if (kaynakId == null) return;
    final hedefler = _portfoyler.where((p) => p.id != kaynakId).toList();
    if (hedefler.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taşınabilecek başka portföy yok.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    String? secilenId = hedefler.first.id;
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Portföy değiştir — ${_displaySymbol(r.symbol)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hedef portföyü seçin', style: GoogleFonts.inter(color: CryptoTheme.textSecondaryFor(context))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: secilenId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: CryptoTheme.cardColor(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: CryptoTheme.cardColor(context),
                items: hedefler.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, secilenId),
              style: FilledButton.styleFrom(
                backgroundColor: CryptoTheme.cryptoAmber,
                foregroundColor: CryptoTheme.onPrimary,
              ),
              child: const Text('Taşı'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    try {
      await SupabaseCryptoService.varlikPortfoyDegistir(
        symbol: r.symbol,
        name: r.name,
        fromPortfolioId: kaynakId,
        toPortfolioId: result,
        quantity: r.totalQuantity,
        averageCost: r.averageCost,
      );
      if (mounted) {
        _yukle();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_displaySymbol(r.symbol)} taşındı.'), backgroundColor: CryptoTheme.successGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _satisYap(CryptoPortfolioRow r) async {
    final coin = _guncelFiyatlar[r.symbol];
    final guncelFiyat = coin?.price ?? r.averageCost;
    final adetController = TextEditingController(text: r.totalQuantity.toStringAsFixed(2));
    final fiyatController = TextEditingController(text: guncelFiyat.toStringAsFixed(2));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Satış — ${_displaySymbol(r.symbol)}', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mevcut: ${r.totalQuantity.toStringAsFixed(2)} adet', style: GoogleFonts.inter(color: CryptoTheme.textSecondaryFor(context))),
              const SizedBox(height: 12),
              TextField(
                controller: adetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Satılacak adet',
                  hintText: 'Max ${r.totalQuantity.toStringAsFixed(2)}',
                  filled: true,
                  fillColor: CryptoTheme.cardColor(context),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fiyatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Satış fiyatı (\$)',
                  filled: true,
                  fillColor: CryptoTheme.cardColor(context),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: CryptoTheme.cryptoAmber,
                foregroundColor: CryptoTheme.onPrimary,
              ),
            child: const Text('Sat'),
          ),
        ],
      ),
    );

    final adetStr = adetController.text.trim().replaceAll(',', '.');
    final fiyatStr = fiyatController.text.trim().replaceAll(',', '.');
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        adetController.dispose();
        fiyatController.dispose();
      });
    } else {
      adetController.dispose();
      fiyatController.dispose();
    }
    if (confirmed != true || !mounted) return;

    final adet = double.tryParse(adetStr);
    if (adet == null || adet <= 0 || adet > r.totalQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli adet girin (0 < adet ≤ mevcut).'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final fiyat = double.tryParse(fiyatStr) ?? guncelFiyat;
    final portfoyId = r.portfolioId ?? _seciliPortfoyId ?? await SupabaseCryptoService.anaPortfoyId();
    if (portfoyId == null) return;
    try {
      await SupabaseCryptoService.satimEkle(
        symbol: r.symbol,
        name: r.name,
        quantity: adet,
        price: fiyat,
        portfolioId: portfoyId,
      );
      if (mounted) {
        _yukle();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_displaySymbol(r.symbol)} satışı kaydedildi.'), backgroundColor: CryptoTheme.successGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _portfoyeEkle() async {
    final coin = _seciliCrypto;
    if (coin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir kripto seçin.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final adet = int.tryParse(_adetController.text.trim());
    if (adet == null || adet < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli adet girin.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final fiyat = double.tryParse(_fiyatController.text.trim().replaceAll(',', '.')) ?? coin.price;
    
    String? portfoyId = _seciliPortfoyId;
    if (portfoyId == null) {
      final duzenlenebilirPortfoyler = _portfoyler.where((p) => !p.isShared).toList();
      if (duzenlenebilirPortfoyler.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Düzenlenebilir portföy bulunamadı.'), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      final anaPortfoy = duzenlenebilirPortfoyler.where((p) => p.name == 'Ana Kripto Portföy').isEmpty
          ? duzenlenebilirPortfoyler.first
          : duzenlenebilirPortfoyler.firstWhere((p) => p.name == 'Ana Kripto Portföy');
      
      if (duzenlenebilirPortfoyler.length == 1) {
        portfoyId = anaPortfoy.id;
      } else {
        String? dialogSecilenId = anaPortfoy.id;
        portfoyId = await showDialog<String>(
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
        if (portfoyId == null) return;
      }
    }

    try {
      await SupabaseCryptoService.alimEkle(
        symbol: coin.symbol,
        name: coin.displaySymbol,
        quantity: adet,
        price: fiyat,
        portfolioId: portfoyId,
      );
      if (mounted) {
        setState(() {
          _seciliCrypto = null;
          _adetController.clear();
          _fiyatController.clear();
        });
        _yukle();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${coin.displaySymbol} eklendi.'), backgroundColor: CryptoTheme.successGreen, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _yeniPortfoyDialog(BuildContext context) async {
    final nameController = TextEditingController(text: 'Yeni Kripto Portföy');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Kripto Portföy'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Portföy adı'),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: CryptoTheme.cryptoAmber,
                foregroundColor: CryptoTheme.onPrimary,
              ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => nameController.dispose());
    } else {
      nameController.dispose();
    }
    if (name == null || name.isEmpty) return;
    try {
      await SupabaseCryptoService.portfoyOlustur(name);
      if (!mounted) return;
      await _yukle();
      try {
        final created = _portfoyler.firstWhere((p) => p.name == name);
        setState(() => _seciliPortfoyId = created.id);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name oluşturuldu.'), backgroundColor: CryptoTheme.successGreen, behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString().split('\n').first}'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CryptoTheme.backgroundGrey(context),
      appBar: const CryptoGlassAppBar(title: 'Kripto Portföy'),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: CryptoTheme.cryptoAmber))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: CryptoTheme.cryptoAmber,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_portfoyler.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _seciliPortfoyId,
                                    decoration: InputDecoration(
                                      labelText: 'Portföy',
                                      filled: true,
                                      fillColor: CryptoTheme.cardColor(context),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('Tümü')),
                                      ..._portfoyler.map((p) => DropdownMenuItem(
                                            value: p.id,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                                                if (p.isShared) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                                                ],
                                              ],
                                            ),
                                          )),
                                    ],
                                    onChanged: (v) {
                                      setState(() => _seciliPortfoyId = v);
                                      _yukle();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: () => _yeniPortfoyDialog(context),
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Yeni portföy',
                                  style: IconButton.styleFrom(
                                    backgroundColor: CryptoTheme.cryptoAmber,
                                    foregroundColor: CryptoTheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: CryptoTheme.cardColorElevated(context),
                              borderRadius: BorderRadius.circular(CryptoTheme.radius),
                            ),
                            child: Column(
                              children: [
                                Text('Toplam Değer', style: GoogleFonts.inter(fontSize: 12, color: CryptoTheme.textSecondaryFor(context))),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${NumberFormat('#,##0.##', 'tr_TR').format(_toplamDeger())}',
                                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: CryptoTheme.priceAccent),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_seciliPortfoyDuzenlenebilir) ...[
                            Autocomplete<CryptoCoin>(
                              optionsBuilder: (e) => CryptoService.cryptoAra(e.text),
                              displayStringForOption: (c) => '${c.displaySymbol} — \$${NumberFormat('#,##0.##').format(c.price)}',
                              fieldViewBuilder: (_, controller, focusNode, onSubmitted) => TextField(
                                controller: controller,
                                focusNode: focusNode,
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [
                                  TextInputFormatter.withFunction((old, replace) => TextEditingValue(
                                    text: replace.text.toUpperCase(),
                                    selection: replace.selection,
                                  )),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Kripto varlık ara',
                                  hintText: 'BTC, ETH, SOL...',
                                  prefixIcon: Icon(Icons.search, color: CryptoTheme.cryptoAmber),
                                  filled: true,
                                  fillColor: CryptoTheme.cardColor(context),
                                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: controller,
                                    builder: (context, value, _) {
                                      if (value.text.isEmpty) return const SizedBox.shrink();
                                      return IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () => controller.clear(),
                                        tooltip: 'Temizle',
                                      );
                                    },
                                  ),
                                ),
                              ),
                              optionsViewBuilder: (_, onSelected, options) => Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 8,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder: (_, i) {
                                        final c = options.elementAt(i);
                                        return ListTile(
                                          title: Text(c.displaySymbol),
                                          subtitle: Text('\$${NumberFormat('#,##0.##').format(c.price)}'),
                                          onTap: () {
                                            onSelected(c);
                                            setState(() {
                                              _seciliCrypto = c;
                                              _fiyatController.text = c.price.toStringAsFixed(2);
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              onSelected: (c) {
                                setState(() {
                                  _seciliCrypto = c;
                                  _fiyatController.text = c.price.toStringAsFixed(2);
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _adetController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: 'Adet', filled: true, fillColor: CryptoTheme.cardColor(context)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _fiyatController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(labelText: 'Fiyat (\$)', filled: true, fillColor: CryptoTheme.cardColor(context)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _seciliPortfoyDuzenlenebilir ? _portfoyeEkle : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Portföye Ekle'),
                              style: FilledButton.styleFrom(
                                backgroundColor: CryptoTheme.cryptoAmber,
                                foregroundColor: CryptoTheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_liste.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 64, color: CryptoTheme.textSecondaryFor(context)),
                            const SizedBox(height: 16),
                            Text('Henüz kripto yok', style: GoogleFonts.inter(color: CryptoTheme.textSecondaryFor(context))),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final r = _liste[i];
                          final coin = _guncelFiyatlar[r.symbol];
                          final fiyat = coin?.price ?? r.averageCost;
                          final deger = r.totalQuantity * fiyat;
                          final kz = deger - r.toplamDeger;
                          final duzenlenebilir = _isRowDuzenlenebilir(r);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            child: Slidable(
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  if (duzenlenebilir) ...[
                                    SlidableAction(
                                      onPressed: (_) => _portfoyDegistir(r),
                                      backgroundColor: CryptoTheme.successGreen,
                                      foregroundColor: CryptoTheme.onPrimary,
                                      icon: Icons.drive_file_move_rounded,
                                    ),
                                    SlidableAction(
                                      onPressed: (_) => _satisYap(r),
                                      backgroundColor: CryptoTheme.accentCyan,
                                      foregroundColor: CryptoTheme.onPrimary,
                                      icon: Icons.sell_rounded,
                                      label: 'Satış',
                                    ),
                                  ],
                                  SlidableAction(
                                    onPressed: (_) => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CryptoDetailScreen(
                                          coin: coin ?? CryptoCoin(symbol: r.symbol, price: r.averageCost, changePercent: 0, volume: 0),
                                        ),
                                      ),
                                    ).then((_) => _yukle()),
                                    backgroundColor: CryptoTheme.cryptoAmber,
                                    foregroundColor: CryptoTheme.onPrimary,
                                    icon: Icons.visibility,
                                    label: 'Detay',
                                  ),
                                ],
                              ),
                              child: Material(
                                color: CryptoTheme.cardColor(context),
                                borderRadius: BorderRadius.circular(CryptoTheme.radius),
                                child: ListTile(
                                  leading: CryptoLogo(symbol: r.symbol, size: 44),
                                  title: Text(_displaySymbol(r.symbol), style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: CryptoTheme.textPrimaryFor(context))),
                                  subtitle: Text('${r.totalQuantity.toStringAsFixed(2)} adet', style: TextStyle(fontSize: 12, color: CryptoTheme.textSecondaryFor(context))),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('\$${NumberFormat('#,##0.##').format(deger)}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: CryptoTheme.priceAccent)),
                                      Text(
                                        '${kz >= 0 ? '+' : ''}${NumberFormat('#,##0.##').format(kz)}',
                                        style: GoogleFonts.inter(fontSize: 12, color: kz >= 0 ? CryptoTheme.positiveChange : CryptoTheme.negativeChange),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _liste.length,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
