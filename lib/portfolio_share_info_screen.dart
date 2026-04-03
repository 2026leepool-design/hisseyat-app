import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'supabase_portfolio_service.dart';

/// Paylaşım bilgileri ekranı - sahip: paylaşımları yönet, alıcı: erişimimi kaldır
class PortfolioShareInfoScreen extends StatefulWidget {
  const PortfolioShareInfoScreen({
    super.key,
    required this.portfolio,
  });

  final Portfolio portfolio;

  @override
  State<PortfolioShareInfoScreen> createState() => _PortfolioShareInfoScreenState();
}

class _PortfolioShareInfoScreenState extends State<PortfolioShareInfoScreen> {
  List<Map<String, dynamic>> _paylasimlar = [];
  Map<String, String> _emailMap = {};
  bool _yukleniyor = true;
  final _emailController = TextEditingController();
  List<Map<String, dynamic>> _aramaSonuclari = [];
  bool _araniyor = false;
  String? _seciliUserId;
  String? _seciliEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _ara() async {
    final q = _emailController.text.trim();
    if (q.isEmpty) {
      setState(() => _aramaSonuclari = []);
      return;
    }
    setState(() => _araniyor = true);
    try {
      final sonuc = await SupabasePortfolioService.kullaniciEmailIleAra(q);
      if (mounted) {
        setState(() {
          _aramaSonuclari = sonuc;
          _araniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  Future<void> _paylas() async {
    if (_seciliUserId == null || _seciliEmail == null) return;
    try {
      await SupabasePortfolioService.portfoyPaylas(
        portfolioId: widget.portfolio.id,
        sharedWithUserId: _seciliUserId!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Portföy $_seciliEmail ile paylaşıldı (sadece görüntüleme)'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _seciliUserId = null;
          _seciliEmail = null;
          _emailController.clear();
          _aramaSonuclari = [];
        });
        _yukle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.softRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _yukle() async {
    if (widget.portfolio.isSharedWithMe) {
      setState(() => _yukleniyor = false);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final list = await SupabasePortfolioService.portfoyPaylasimlariniGetir(widget.portfolio.id);
      final emails = <String, String>{};
      for (final p in list) {
        final uid = p['shared_with_user_id'] as String;
        try {
          final prof = await Supabase.instance.client.from('profiles').select('email').eq('id', uid).maybeSingle();
          if (prof != null && prof['email'] != null) {
            emails[uid] = prof['email'] as String;
          } else {
            emails[uid] = 'Bilinmeyen';
          }
        } catch (_) {
          emails[uid] = uid.substring(0, 8);
        }
      }
      if (mounted) {
        setState(() {
          _paylasimlar = list;
          _emailMap = emails;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _paylasimiKaldir(String sharedWithUserId) async {
    final email = _emailMap[sharedWithUserId] ?? sharedWithUserId;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Paylaşımı Kaldır'),
        content: Text('$email kullanıcısının erişimi kaldırılacak. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.softRed),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await SupabasePortfolioService.portfoyPaylasimiKaldir(
        portfolioId: widget.portfolio.id,
        sharedWithUserId: sharedWithUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paylaşım kaldırıldı'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _yukle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.softRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _erisimimiKaldir() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Erişimi Kaldır'),
        content: const Text('Bu portföye olan erişiminiz kaldırılacak. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.softRed),
            child: const Text('Erişimimi Kaldır'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await SupabasePortfolioService.paylasimErisimimiKaldir(widget.portfolio.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erişiminiz kaldırıldı'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.softRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = !widget.portfolio.isSharedWithMe;
    return Scaffold(
      appBar: AppBar(
        title: Text(isOwner ? 'Portföyü Paylaş — ${widget.portfolio.name}' : 'Paylaşım Bilgileri — ${widget.portfolio.name}'),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: AppTheme.navyBlue))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: widget.portfolio.isSharedWithMe
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.share, color: AppTheme.navyBlue, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Paylaşılan portföy', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                          Text(
                                            'Sadece görüntüleme yetkisi',
                                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _erisimimiKaldir,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Erişimimi Kaldır'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.softRed,
                            side: const BorderSide(color: AppTheme.softRed),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_paylasimlar.isNotEmpty) ...[
                            Text('Mevcut paylaşımlar', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            ..._paylasimlar.map((p) {
                              final uid = p['shared_with_user_id'] as String;
                              final email = _emailMap[uid] ?? uid.substring(0, 8);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const Icon(Icons.person, color: AppTheme.navyBlue),
                                  title: Text(email),
                                  subtitle: const Text('Sadece görüntüleme'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.softRed),
                                    onPressed: () => _paylasimiKaldir(uid),
                                    tooltip: 'Paylaşımı kaldır',
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 24),
                            Text('Yeni paylaşım ekle', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          ] else ...[
                            Text(
                              'Bu portföy henüz kimseyle paylaşılmamış',
                              style: GoogleFonts.inter(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'E-posta ile ara (ornek@email.com)',
                              border: const OutlineInputBorder(),
                              filled: true,
                              suffixIcon: IconButton(
                                icon: _araniyor
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.search),
                                onPressed: _araniyor ? null : _ara,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _ara(),
                          ),
                          if (_aramaSonuclari.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Sonuçlar:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            ..._aramaSonuclari.map((u) {
                              final uid = u['user_id'] as String;
                              final email = u['email'] as String;
                              final secili = _seciliUserId == uid;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.person, color: secili ? AppTheme.navyBlue : Colors.grey, size: 20),
                                  title: Text(email, style: const TextStyle(fontSize: 14)),
                                  selected: secili,
                                  onTap: () => setState(() {
                                    _seciliUserId = uid;
                                    _seciliEmail = email;
                                  }),
                                ),
                              );
                            }),
                          ],
                          if (_seciliUserId != null) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _paylas,
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text('Paylaş'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.navyBlue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
    );
  }
}
