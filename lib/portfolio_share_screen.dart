import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'supabase_portfolio_service.dart';

/// Portföy paylaşım ekranı - e-posta ile kullanıcı ara, paylaş (her zaman sadece görüntüleme)
class PortfolioShareScreen extends StatefulWidget {
  const PortfolioShareScreen({
    super.key,
    required this.portfolio,
  });

  final Portfolio portfolio;

  @override
  State<PortfolioShareScreen> createState() => _PortfolioShareScreenState();
}

class _PortfolioShareScreenState extends State<PortfolioShareScreen> {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Portföyü Paylaş — ${widget.portfolio.name}'),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'E-posta ile kullanıcı ara',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'ornek@email.com',
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
            const SizedBox(height: 16),
            if (_aramaSonuclari.isNotEmpty) ...[
              Text('Sonuçlar:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _aramaSonuclari.length,
                  itemBuilder: (ctx, i) {
                    final u = _aramaSonuclari[i];
                    final uid = u['user_id'] as String;
                    final email = u['email'] as String;
                    final secili = _seciliUserId == uid;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.person, color: secili ? AppTheme.navyBlue : Colors.grey),
                        title: Text(email),
                        selected: secili,
                        onTap: () {
                          setState(() {
                            _seciliUserId = uid;
                            _seciliEmail = email;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
            if (_seciliUserId != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _paylas,
                icon: const Icon(Icons.share),
                label: const Text('Paylaş'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.navyBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
