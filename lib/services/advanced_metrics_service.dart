import 'collect_api_service.dart';
import 'fmp_api_service.dart';
import 'advanced_metrics_model.dart';

class AdvancedMetricsService {
  static Future<AdvancedMetrics> fetchAdvancedMetrics(String symbol) async {
    try {
      final fmp = await _safeFmp(symbol);
      if (fmp != null && fmp.hasCriticalData) {
        // FMP başarılıysa ama bazı alanlar eksikse Collect ile tamamla
        final collect = await _safeCollect(symbol);
        return fmp.mergeMissing(collect);
      }

      // FMP null veya kritik alan eksikse fallback
      final collectFallback = await _safeCollect(symbol);
      if (collectFallback != null) {
        return (fmp ?? const AdvancedMetrics.empty()).mergeMissing(collectFallback);
      }
      return fmp ?? const AdvancedMetrics.empty();
    } catch (_) {
      final collectFallback = await _safeCollect(symbol);
      return collectFallback ?? const AdvancedMetrics.empty();
    }
  }

  static Future<AdvancedMetrics?> _safeFmp(String symbol) async {
    try {
      return await FmpApiService.fetchAdvancedMetrics(symbol);
    } catch (_) {
      return null;
    }
  }

  static Future<AdvancedMetrics?> _safeCollect(String symbol) async {
    try {
      return await CollectApiService.fetchAdvancedMetrics(symbol);
    } catch (_) {
      return null;
    }
  }
}
