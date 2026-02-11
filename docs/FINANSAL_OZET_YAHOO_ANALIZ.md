# Finansal Özet Ekranı – Yahoo Finance Veri Analizi

Bu dokümanda, hisse kartındaki info butonuyla açılan **Finansal Özet** ekranı için Yahoo Finance’tan çekilebilecek veriler ile TradingView örnekleri karşılaştırılmaktadır.

---

## 1. Mevcut Durum (StockDetailScreen)

Şu an Finansal Özet ekranında gösterilen veriler:

| Bölüm | Metrik | Kaynak |
|-------|--------|--------|
| **Finansal Özet** | Önceki Kapanış, Hacim, Günlük Yüksek/Düşük, 52 Haftalık Aralık | StockChartMeta (v8/finance/chart) |
| **Temel İstatistikler** | Ortalama Hacim (30G), Piyasa Değeri, Temettü Verimi, F/K Oranı, Basit HBK, Net Kazanç, Gelir, Halka Açık Hisseler, Beta | HisseDetayliBilgi (quoteSummary: summaryDetail, defaultKeyStatistics, financialData) |

---

## 2. TradingView Örneklerinde Görünen Veriler

TradingView ekran görüntülerinden tespit edilen metrikler:

### 2.1 Önemli Gerçekler (Important Facts) / Temel İstatistikler
- Piyasa değeri (Market Cap)
- Temettü verimi (Dividend Yield)
- Fiyat/Kazanç Oranı (P/E)
- Basit HBK (EPS TTM)
- Kuruluş yılı (Founded)
- Çalışanlar (Employees)
- CEO
- Web sitesi
- Sahiplik (Closely held / Halka açık hisseler)

### 2.2 Değerleme / Sermaye Yapısı
- Piyasa Değeri
- Borç (Debt)
- Nakit ve benzerleri (Cash & Equivalents)
- Kuruluş değeri (Enterprise Value)
- F/K oranı, P/S oranı

### 2.3 Gelir Tablosu / Gelir – Kâr Dönüşümü
- Gelir (Revenue)
- Net gelir (Net Income)
- Net marj %
- COGS, Brüt Kar, Giderler

### 2.4 Finansal Sağlık
- Borç seviyesi
- Serbest nakit akışı (Free Cash Flow)
- Kısa/Uzun vadeli varlıklar ve yükümlülükler

### 2.5 Temettüler
- Temettü getirisi TTM
- Ödeme oranı (Payout ratio)
- Son ödeme, son hak ediş/ödeme tarihi
- Hisse başı temettü, temettü verimi geçmişi

### 2.6 Hakkında (Şirket Profili)
- Sektör, Sanayi
- CEO, Web sitesi, Genel merkez
- Kuruluş yılı, ISIN, FIGI
- Halka arz tarihi (IPO)
- Şirket açıklaması

### 2.7 Tahminler (Estimates)
- Gelir ve kazanç tahminleri (yıllık/çeyreklik)
- Kazanç sonraki (Next earnings date)

### 2.8 Gelir Dağılımı
- Kaynağa göre (ürün/bölüm)
- Ülke bazında

---

## 3. Yahoo Finance quoteSummary Modülleri ve Veriler

Yahoo Finance `quoteSummary` API’si modül bazlı veri sunar. Önemli modüller:

| Modül | Veriler |
|-------|---------|
| **summaryDetail** | previousClose, open, dayHigh, dayLow, volume, averageVolume, marketCap, fiftyTwoWeekHigh/Low, dividendRate, dividendYield, exDividendDate, payoutRatio, trailingPE, forwardPE, priceToSalesTrailing12Months, beta |
| **defaultKeyStatistics** | enterpriseValue, floatShares, sharesOutstanding, sharesShort, heldPercentInsiders, heldPercentInstitutions, shortRatio, beta, bookValue, priceToBook, trailingEps, forwardEps, pegRatio, earningsQuarterlyGrowth, netIncomeToCommon, enterpriseToRevenue, enterpriseToEbitda |
| **financialData** | totalCash, totalCashPerShare, ebitda, totalDebt, quickRatio, currentRatio, totalRevenue, debtToEquity, revenuePerShare, returnOnAssets, returnOnEquity, grossProfits, **freeCashflow**, operatingCashflow, earningsGrowth, revenueGrowth, grossMargins, ebitdaMargins, operatingMargins, **profitMargins** |
| **assetProfile** | sector, industry, fullTimeEmployees, longBusinessSummary, website, address1, city, state, country, companyOfficers (CEO vb.) |
| **quoteType** | firstTradeDateEpochUtc (IPO tarihi) |
| **calendarEvents** | exDividendDate, dividendDate, earnings (earningsDate, earningsAverage, revenueAverage) |
| **earnings** | earningsChart (quarterly actual/estimate), financialsChart (yearly/quarterly revenue, earnings) |
| **earningsTrend** | Gelir ve kazanç tahminleri (period bazlı) |
| **majorHoldersBreakdown** | insidersPercentHeld, institutionsPercentHeld (Sahiplik dağılımı) |
| **balanceSheetHistory** | totalAssets, totalLiabilities, totalStockholderEquity, totalCash, totalDebt (yıllık) |
| **balanceSheetHistoryQuarterly** | Aynı alanlar, çeyreklik |
| **incomeStatementHistory** | totalRevenue, costOfRevenue, grossProfit, operatingIncome, netIncome (yıllık) |
| **incomeStatementHistoryQuarterly** | Aynı alanlar, çeyreklik |
| **cashflowStatementHistory** | totalCashFromOperatingActivities, capitalExpenditures, dividendsPaid, totalCashFromFinancingActivities (yıllık) |
| **cashflowStatementHistoryQuarterly** | Aynı alanlar, çeyreklik |

**Not:** Yahoo dokümantasyonuna göre ABD dışı hisseler (ör. BIST) için `balanceSheetHistory`, `incomeStatementHistory`, `cashflowStatementHistory` ve çeyreklik versiyonları **yanlış veya eksik** olabilir. Bu nedenle BIST hisseleri için bu modülleri deneyip sonuçları kontrol etmek gerekir.

---

## 4. TradingView → Yahoo Finance Eşlemesi

### ✅ Yahoo Finance ile Çekilebilir

| TradingView Metriği | Yahoo Modül / Alan | Not |
|--------------------|--------------------|-----|
| Piyasa değeri | summaryDetail.marketCap | ✓ |
| Temettü verimi | summaryDetail.dividendYield | ✓ |
| F/K oranı | summaryDetail.trailingPE, forwardPE | ✓ |
| Basit HBK (EPS) | defaultKeyStatistics.trailingEps | ✓ |
| Kuruluş yılı | assetProfile | Genellikle longBusinessSummary içinde metin olarak |
| Çalışanlar | assetProfile.fullTimeEmployees | ✓ |
| CEO | assetProfile.companyOfficers[0].name | ✓ |
| Web sitesi | assetProfile.website | ✓ |
| Genel merkez | assetProfile.city, state, country | ✓ |
| Halka açık hisseler | defaultKeyStatistics.sharesOutstanding, floatShares | ✓ |
| Sahiplik (insider/institution %) | majorHoldersBreakdown | ✓ |
| Borç | financialData.totalDebt | ✓ |
| Nakit ve benzerleri | financialData.totalCash | ✓ |
| Kuruluş değeri | defaultKeyStatistics.enterpriseValue | ✓ |
| Serbest nakit akışı | financialData.freeCashflow | ✓ |
| Net gelir | financialData (netIncomeToCommon) veya incomeStatementHistory | ✓ |
| Gelir | financialData.totalRevenue veya incomeStatementHistory | ✓ |
| Net marj % | financialData.profitMargins | ✓ (0–1 aralığı, *100 ile % yapılır) |
| Brüt marj | financialData.grossMargins | ✓ |
| ROA, ROE | financialData.returnOnAssets, returnOnEquity | ✓ |
| Borç/Özsermaye | financialData.debtToEquity | ✓ |
| P/S oranı | summaryDetail.priceToSalesTrailing12Months | ✓ |
| P/B oranı | defaultKeyStatistics.priceToBook | ✓ |
| Ödeme oranı | summaryDetail.payoutRatio | ✓ |
| Son temettü hak ediş | summaryDetail.exDividendDate, calendarEvents | ✓ |
| IPO tarihi | quoteType.firstTradeDateEpochUtc | ✓ |
| Sonraki kazanç tarihi | calendarEvents.earnings.earningsDate | ✓ |

### ⚠️ Sınırlı / Hesaplama Gerektiren

| Metrik | Durum |
|--------|-------|
| Gelir dağılımı (ürün/ülke) | Yahoo’da segment/coğrafi dağılım yok. Başka kaynak gerekir. |
| Gelir/Kazanç tahminleri grafiği | earningsTrend ile yıllık/çeyreklik tahminler var, fakat grafik için kendi UI mantığınızı kurmanız gerekir. |
| COGS, Brüt Kar (gelir tablosu satırları) | incomeStatementHistory ile alınabilir; BIST için doğruluğu test edilmeli. |
| Kısa/Uzun vadeli varlık-yükümlülük | balanceSheetHistory ile; BIST için doğruluğu test edilmeli. |

### ❌ Yahoo Finance ile Sağlanamayan

| Metrik | Neden |
|--------|-------|
| ISIN, FIGI | quoteSummary’de yok; ayrı veri sağlayıcı gerekir. |
| Teknik analiz göstergesi (Al/Sat/Nötr) | Yahoo temel finansal veri sağlar; teknik göstergeler hesaplanmalı veya başka API kullanılmalı. |
| Gelir dağılımı (ürün/coğrafya) | Segment verisi yok. |

---

## 5. Kişiselleştirme İçin Önerilen Metrik Listesi

Finansal Özet ekranında kullanıcının seçebileceği metrikler:

### Varsayılan (Mevcut + Genişletilmiş)
1. Önceki kapanış  
2. Hacim  
3. Günlük yüksek/düşük  
4. 52 haftalık aralık  
5. Piyasa değeri  
6. Ortalama hacim (30 gün)  
7. F/K oranı (TTM)  
8. İleri F/K  
9. Basit HBK (EPS TTM)  
10. Temettü verimi  
11. Beta  

### Ek (Yahoo ile alınabilir)
12. Kuruluş değeri (Enterprise Value)  
13. Borç (Total Debt)  
14. Nakit ve benzerleri  
15. Serbest nakit akışı  
16. Net kazanç (MY)  
17. Gelir (FY)  
18. Net marj %  
19. Brüt marj  
20. ROA (Aktif kârlılığı)  
21. ROE (Özsermaye kârlılığı)  
22. Borç/Özsermaye  
23. P/S oranı  
24. P/B oranı  
25. Ödeme oranı  
26. Halka açık hisseler  
27. İçeridekiler % (Insider)  
28. Kurumlar % (Institution)  

### Şirket profili
29. Sektör  
30. Sanayi  
31. CEO  
32. Web sitesi  
33. Genel merkez  
34. Çalışan sayısı  
35. Kuruluş yılı  
36. IPO tarihi  
37. Şirket açıklaması (özet)  

### Tahminler / Takvim
38. Sonraki kazanç tarihi  
39. Son temettü hak ediş tarihi  

---

## 6. Uygulama Önerileri

1. **Ek modüller:**  
   `assetProfile`, `quoteType`, `calendarEvents`, `financialData` (zaten kısmen kullanılıyor), `majorHoldersBreakdown` eklenebilir.

2. **BIST kontrolü:**  
   `balanceSheetHistory`, `incomeStatementHistory`, `cashflowStatementHistory` BIST hisselerinde denenmeli; veri yoksa veya hatalıysa bu alanlar gizlenmeli.

3. **Kişiselleştirme mimarisi:**  
   Hisse kartı ÖZET için kullanılan `HisseKartiOzetService` benzeri bir servis (`FinansalOzetMetrikService`) oluşturulup SharedPreferences ile metrik tercihleri saklanabilir.

4. **Performans:**  
   Ek modüller tek `quoteSummary` çağrısına eklenebilir (örn. `modules=summaryDetail,defaultKeyStatistics,financialData,assetProfile,quoteType,calendarEvents,majorHoldersBreakdown`).

---

## 7. Özet Tablo

| Kategori | Yahoo ile | Sınırlı | Yahoo ile değil |
|----------|-----------|---------|-----------------|
| Piyasa / Fiyat | ✓ | | |
| Değerleme oranları | ✓ | | |
| Bilanço / Gelir tablosu | | BIST için test gerekir | |
| Şirket profili | ✓ | | |
| Sahiplik | ✓ | | |
| Temettü | ✓ | | |
| Tahminler | ✓ | | |
| Segment/coğrafya dağılımı | | | ✓ (Yahoo’da yok) |
| Teknik göstergeler | | Hesaplama ile | |
| ISIN / FIGI | | | ✓ (Yahoo’da yok) |
