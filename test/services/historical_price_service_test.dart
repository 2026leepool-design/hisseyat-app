import 'package:flutter_test/flutter_test.dart';
import 'package:ilk_deneme/services/historical_price_service.dart';

void main() {
  group('HistoricalPriceService - yahooSymbol', () {
    test('Turkish stocks should get .IS suffix', () {
      expect(HistoricalPriceService.yahooSymbol('THYAO'), 'THYAO.IS');
      expect(HistoricalPriceService.yahooSymbol('eregl'), 'EREGL.IS');
    });

    test('Stocks already having .IS suffix should remain unchanged', () {
      expect(HistoricalPriceService.yahooSymbol('THYAO.IS'), 'THYAO.IS');
      expect(HistoricalPriceService.yahooSymbol('SISE.IS'), 'SISE.IS');
    });

    test('FX symbols (containing =X) should remain unchanged', () {
      expect(HistoricalPriceService.yahooSymbol('USDTRY=X'), 'USDTRY=X');
      expect(HistoricalPriceService.yahooSymbol('EURTRY=X'), 'EURTRY=X');
    });

    test('Symbols with other extensions should remain unchanged', () {
      expect(HistoricalPriceService.yahooSymbol('AAPL.US'), 'AAPL.US');
      expect(HistoricalPriceService.yahooSymbol('TSLA.O'), 'TSLA.O');
    });

    test('Should handle whitespace and case sensitivity', () {
      expect(HistoricalPriceService.yahooSymbol('  thyao  '), 'THYAO.IS');
      expect(HistoricalPriceService.yahooSymbol('usdtry=x'), 'USDTRY=X');
    });
  });
}
