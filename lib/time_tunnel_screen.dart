import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'logo_service.dart';
import 'services/time_tunnel_service.dart';
import 'stock_logo.dart';
import 'supabase_portfolio_service.dart';

/// Zaman Tüneli — Geçmiş bir tarihteki portföy durumunu gösterir
class TimeTunnelScreen extends StatefulWidget {
  const TimeTunnelScreen({super.key});

  @override
  State<TimeTunnelScreen> createState() => _TimeTunnelScreenState();
}

class _TimeTunnelScreenState extends State<TimeTunnelScreen> {
  DateTime _seciliTarih = DateTime.now().subtract(const Duration(days: 365));
  TimeTunnelSonuc? _sonuc;
  bool _yukleniyor = false;
  String? _hata;
  List<Portfolio> _portfoyler = [];
  String? _seciliPortfoyId;

  @override
  void initState() {
    super.initState();
    _portfoyleriYukle();
    // Artık ilk hesaplamayı _portfoyleriYukle içinde, portföy seçilince yapıyoruz
  }

  Future<void> _portfoyleriYukle() async {
    try {
      final list = await SupabasePortfolioService.portfoyleriYukle();
      if (mounted) {
        setState(() {
          _portfoyler = list;
          // Eğer seçili portföy yoksa veya listede değilse (ve liste boş değilse) ilkini seç
          if (_seciliPortfoyId == null || !list.any((p) => p.id == _seciliPortfoyId)) {
            if (list.isNotEmpty) {
              _seciliPortfoyId = list.first.id;
              _hesapla(); // İlk portföy seçilince tekrar hesapla
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _hesapla() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final sonuc = await TimeTunnelService.hesapla(_seciliTarih, portfolioId: _seciliPortfoyId);
      if (mounted) {
        setState(() {
          _sonuc = sonuc;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = e.toString().split('\n').first;
          _yukleniyor = false;
        });
      }
    }
  }

  Future<void> _tarihSec() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _seciliTarih,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Tarih Seç',
    );
    if (picked != null && mounted) {
      setState(() => _seciliTarih = picked);
      _hesapla();
    }
  }

  void _hizliTarihSec(int gunOnce) {
    setState(() => _seciliTarih = DateTime.now().subtract(Duration(days: gunOnce)));
    _hesapla();
  }

  String _formatTutar(double v) => NumberFormat('#,##0.##', 'tr_TR').format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      appBar: AppBar(
        title: Text(
          'Zaman Tüneli',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTarihSecici(),
            const SizedBox(height: 24),
            if (_yukleniyor)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: AppTheme.cardDecoration(context),
                child: const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.navyBlue),
                      SizedBox(height: 16),
                      Text('Hesaplanıyor...'),
                    ],
                  ),
                ),
              )
            else if (_hata != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration(context),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.softRed, size: 32),
                    const SizedBox(width: 16),
                    Expanded(child: Text(_hata!, style: AppTheme.body(context))),
                  ],
                ),
              )
            else if (_sonuc != null) ...[
              _buildOzetKarti(),
              const SizedBox(height: 24),
              if (_sonuc!.pozisyonlar.isNotEmpty) ...[
                Text('Hisse Pozisyonları', style: AppTheme.h2(context)),
                const SizedBox(height: 12),
                _buildPozisyonListesi(),
              ] else
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: AppTheme.cardDecoration(context),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Bu tarihte portföyde hisse bulunmuyor',
                          style: AppTheme.body(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTarihSecici() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtrele',
                style: AppTheme.h2(context),
              ),
              if (_sonuc != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'BIST100: ${_formatTutar(_sonuc!.bist100)}',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'USD: ${_formatTutar(_sonuc!.usdKuru)} ₺  |  EUR: ${_formatTutar(_sonuc!.eurKuru)} ₺',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _seciliPortfoyId,
            decoration: InputDecoration(
              labelText: 'Portföy',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _portfoyler.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                      if (p.isShared) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                        if (p.isSharedWithMe && p.ownerEmailHint != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(@${p.ownerEmailHint})',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ],
                  ),
                )).toList(),
            onChanged: (v) {
              setState(() => _seciliPortfoyId = v);
              _hesapla();
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TarihChip(
                label: 'Geçen Hafta',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 7))),
                onTap: () => _hizliTarihSec(7),
              ),
              _TarihChip(
                label: '1 Ay Öncesi',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 30))),
                onTap: () => _hizliTarihSec(30),
              ),
              _TarihChip(
                label: '3 Ay Öncesi',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 90))),
                onTap: () => _hizliTarihSec(90),
              ),
              _TarihChip(
                label: '6 Ay Öncesi',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 180))),
                onTap: () => _hizliTarihSec(180),
              ),
              _TarihChip(
                label: '1 Yıl Öncesi',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 365))),
                onTap: () => _hizliTarihSec(365),
              ),
              _TarihChip(
                label: '2 Yıl Öncesi',
                secili: _tarihKarsilastir(_seciliTarih, DateTime.now().subtract(const Duration(days: 730))),
                onTap: () => _hizliTarihSec(730),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _tarihSec,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: AppTheme.navyBlue, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d MMMM yyyy', 'tr_TR').format(_seciliTarih),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkSlate,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _tarihKarsilastir(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildOzetKarti() {
    final s = _sonuc!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.bankCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Toplam Portföy Değeri',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatTutar(s.toplamTry)} ₺',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (s.usdKuru > 0)
            Text(
              '\$ ${_formatTutar(s.toplamUsd)}  ·  € ${_formatTutar(s.toplamEur)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          else
            Text(
              'Kur verisi yok',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPozisyonListesi() {
    final pozisyonlar = _sonuc!.pozisyonlar;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pozisyonlar.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = pozisyonlar[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(context),
          child: Row(
            children: [
              StockLogo(symbol: p.symbol, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LogoService.symbolForDisplay(p.symbol),
                      style: AppTheme.symbol(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.adet.toStringAsFixed(0)} adet',
                      style: AppTheme.bodySmall(context),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.tarihselFiyat != null
                        ? '${_formatTutar(p.tarihselFiyat!)} ₺'
                        : 'Veri yok',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.tarihselFiyat != null ? AppTheme.darkSlate : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.tarihselDeger != null
                        ? '${_formatTutar(p.tarihselDeger!)} ₺'
                        : '—',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkSlate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TarihChip extends StatelessWidget {
  final String label;
  final bool secili;
  final VoidCallback onTap;

  const _TarihChip({
    required this.label,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secili ? AppTheme.navyBlue : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: secili ? Colors.white : AppTheme.darkSlate,
            ),
          ),
        ),
      ),
    );
  }
}
