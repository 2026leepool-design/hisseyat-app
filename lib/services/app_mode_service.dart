import 'package:flutter/foundation.dart';

/// Uygulama modu: false = Hisse, true = Crypto.
/// Ana sayfada toggle ile değiştirilir; tüm uygulama bu moda göre yeniden yapılanır.
class AppModeService {
  AppModeService._();
  static final AppModeService instance = AppModeService._();

  /// true = Kripto modu (portföy, geçmiş, zaman tüneli, performans hepsi crypto)
  /// false = Hisse modu (varsayılan)
  final ValueNotifier<bool> cryptoMode = ValueNotifier<bool>(false);

  static bool get isCrypto => instance.cryptoMode.value;
  static bool get isHisse => !instance.cryptoMode.value;

  void setCryptoMode(bool value) {
    cryptoMode.value = value;
  }
}
