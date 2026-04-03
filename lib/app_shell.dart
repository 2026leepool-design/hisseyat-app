import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'ana_sayfa_page.dart';
import 'crypto_gecmis_islemler_page.dart';
import 'crypto_performans_page.dart';
import 'crypto_portfolio_page.dart';
import 'crypto_time_tunnel_screen.dart';
import 'gecmis_islemler_page.dart';
import 'hisse_page.dart';
import 'performans_page.dart';
import 'services/app_mode_service.dart';
import 'time_tunnel_screen.dart';
import 'crypto_theme.dart';
import 'widgets/app_bottom_nav_bar.dart';

/// Ana kabuk – sabit alt navigasyon ile dikey sayfaları sarmalar.
/// Her sekme kendi Navigator'ına sahip; detay sayfalarına gidildiğinde alt bar görünür kalır.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _seciliIndex = 0;
  /// Hisse ve kripto modu için ayrı Navigator key'leri – mod değişince doğru sayfa açılsın diye
  final List<GlobalKey<NavigatorState>> _navigatorKeysHisse = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final List<GlobalKey<NavigatorState>> _navigatorKeysCrypto = List.generate(5, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    // AppShell açılışında portrait modunu garanti et
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    // Çıkışta portrait modunu koru
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String get _currentRoute {
    switch (_seciliIndex) {
      case 0:
        return 'AnaSayfa';
      case 1:
        return 'GecmisIslemlerPage';
      case 2:
        return 'TimeTunnelScreen';
      case 3:
        return 'PerformansPage';
      case 4:
        return 'Portfoyler';
      default:
        return 'MyHomePage';
    }
  }

  Widget _tabIcerik(int index, bool cryptoMode) {
    Widget sayfa;
    if (cryptoMode) {
      switch (index) {
        case 0:
          sayfa = const AnaSayfaPage();
          break;
        case 1:
          sayfa = const CryptoGecmisIslemlerPage();
          break;
        case 2:
          sayfa = const CryptoTimeTunnelScreen();
          break;
        case 3:
          sayfa = const CryptoPerformansPage();
          break;
        case 4:
          sayfa = const CryptoPortfolioPage();
          break;
        default:
          sayfa = const AnaSayfaPage();
      }
    } else {
      switch (index) {
        case 0:
          sayfa = const AnaSayfaPage();
          break;
        case 4:
          sayfa = const MyHomePage();
          break;
        case 1:
          sayfa = const GecmisIslemlerPage();
          break;
        case 2:
          sayfa = const TimeTunnelScreen();
          break;
        case 3:
          sayfa = const PerformansPage();
          break;
        default:
          sayfa = const MyHomePage();
      }
    }
    final navKey = cryptoMode ? _navigatorKeysCrypto[index] : _navigatorKeysHisse[index];
    return Navigator(
      key: navKey,
      initialRoute: '/',
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => sayfa),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppModeService.instance.cryptoMode,
      builder: (context, cryptoMode, _) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final cryptoMode = AppModeService.instance.cryptoMode.value;
        final navKeys = cryptoMode ? _navigatorKeysCrypto : _navigatorKeysHisse;
        final navigator = navKeys[_seciliIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (_seciliIndex != 0) {
          setState(() => _seciliIndex = 0);
          return;
        }

        final exitConfirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Uygulamadan Çık'),
            content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hayır'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.softRed,
                ),
                child: const Text('Evet'),
              ),
            ],
          ),
        );

        if (exitConfirm == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: cryptoMode ? CryptoTheme.backgroundGrey(context) : null,
        body: IndexedStack(
          index: _seciliIndex,
          children: [
            _tabIcerik(0, cryptoMode),
            _tabIcerik(1, cryptoMode),
            _tabIcerik(2, cryptoMode),
            _tabIcerik(3, cryptoMode),
            _tabIcerik(4, cryptoMode),
          ],
        ),
        bottomNavigationBar: AppBottomNavBar(
          currentRoute: _currentRoute,
          cryptoMode: cryptoMode,
        onTap: (index) {
          final navKeys = cryptoMode ? _navigatorKeysCrypto : _navigatorKeysHisse;
          if (index == _seciliIndex) {
            navKeys[index].currentState?.popUntil((r) => r.isFirst);
          } else {
            // Geçmiş İşlemler (landscape) ekranından çıkarken portrait'e dön
            if (_seciliIndex == 1) {
              SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
            }
            // Geçmiş İşlemler (landscape) ekranına girerken landscape'e geç (sadece hisse modunda)
            if (index == 1 && !cryptoMode) {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            }
            setState(() => _seciliIndex = index);
          }
        },
        ),
      ),
    ),
    );
  }
}
