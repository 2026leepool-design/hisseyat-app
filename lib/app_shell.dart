import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ana_sayfa_page.dart';
import 'gecmis_islemler_page.dart';
import 'hisse_page.dart';
import 'performans_page.dart';
import 'time_tunnel_screen.dart';
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
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

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

  Widget _tabIcerik(int index) {
    Widget sayfa;
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
    return Navigator(
      key: _navigatorKeys[index],
      initialRoute: '/',
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => sayfa),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = _navigatorKeys[_seciliIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }

        if (_seciliIndex != 0) {
          setState(() => _seciliIndex = 0);
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
      body: IndexedStack(
        index: _seciliIndex,
        children: [
          _tabIcerik(0),
          _tabIcerik(1),
          _tabIcerik(2),
          _tabIcerik(3),
          _tabIcerik(4),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: _currentRoute,
        onTap: (index) {
          if (index == _seciliIndex) {
            _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
          } else {
            // Geçmiş İşlemler (landscape) ekranından çıkarken portrait'e dön
            if (_seciliIndex == 1) {
              SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
            }
            // Geçmiş İşlemler (landscape) ekranına girerken landscape'e geç
            if (index == 1) {
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
    );
  }
}
