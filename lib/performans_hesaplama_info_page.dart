import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

class PerformansHesaplamaInfoPage extends StatelessWidget {
  const PerformansHesaplamaInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey(context),
      appBar: AppBar(
        title: Text('Hesaplama Yöntemi', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              context,
              title: 'Temel Mantık (Cep Modeli)',
              lines: const [
                'Performans, iki tarih arasındaki nakit etkileri ve eldeki varlığın değer değişimi birlikte hesaplanarak bulunur.',
                'Başlangıçta portföyde olan hisselerin o günkü değeri, başlangıç maliyeti olarak kabul edilir.',
                'İşlem aralığında gerçekleşen her hareket (alım, satım, temettü, bölünme) cep bakiyesine artı/eksi etki eder.',
                'Bitiş tarihindeki elde kalan hisselerin değeri, son varlık olarak sonuca eklenir.',
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Adım Adım Hesap',
              lines: const [
                '1) Başlangıç tarihi portföy değeri cepten düşülür.',
                '2) Alım işlemleri (komisyon dahil) cepten düşülür.',
                '3) Satış işlemleri (komisyon düşülmüş net gelir) cebe eklenir.',
                '4) Temettü gelirleri cebe eklenir.',
                '5) Bölünme işlemleri ayrı bir hareket olarak gösterilir ve maliyet etkisi cepten düşülür.',
                '6) Bitiş tarihindeki portföy değeri cebe eklenir.',
                '7) Son cep bakiyesi, dönem performansını (kar/zarar) verir.',
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Hisse Bazlı Dökümde Ne Görülür?',
              lines: const [
                'İlk tarih adedi ve fiyatı',
                'İkinci tarih adedi ve fiyatı',
                'İşlem kırılımları (alım/satım/temettü/bölünme)',
                'Hisse bazlı net cep etkisi ve yüzdesi',
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              title: 'Notlar',
              lines: const [
                'Yüzde hesapları, hisse için başlangıç baz değeri varsa gösterilir.',
                'Başlangıçta ve bitişte elde olmayan fakat aralıkta işlem gören hisseler ayrı renkle listelenir.',
                'Tüm sonuçlar seçilen portföy ve tarih aralığına göre dinamik hesaplanır.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<String> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.h2(context)),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(line, style: AppTheme.body(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
