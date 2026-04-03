/// İş Yatırım şirket kartından çekilen finansal veriler
class IsYatirimModel {
  final double? sonFiyat;
  final double? gunlukDegisimYuzde;
  final double? fK;
  final double? pdDd;
  final double? piyasaDegeri;
  final double? netKar;
  final double? temettuVerimi;
  const IsYatirimModel({
    this.sonFiyat,
    this.gunlukDegisimYuzde,
    this.fK,
    this.pdDd,
    this.piyasaDegeri,
    this.netKar,
    this.temettuVerimi,
  });

  bool get hasData =>
      sonFiyat != null ||
      gunlukDegisimYuzde != null ||
      fK != null ||
      pdDd != null ||
      piyasaDegeri != null ||
      netKar != null ||
      temettuVerimi != null;
}

/// İş Yatırım şirket kartından çekilen şirket profili (künye + faaliyet alanı).
/// CompanyProfile: CEO, Kuruluş, Sektör, Web Sitesi, Halka Arz, Ödenmiş Sermaye, Fiili Dolaşım.
class IsYatirimCompanyProfile {
  final String? sirketUnvani;
  final String? kurulusTarihi;
  final String? genelMudur;
  final String? sektor;
  final String? webSitesi;
  final String? halkaArzTarihi;
  final String? odenmisSermaye;
  final String? fiiliDolasimOrani;
  final double? fiiliDolasimOraniYuzde;
  final String? sirketHakkinda;

  const IsYatirimCompanyProfile({
    this.sirketUnvani,
    this.kurulusTarihi,
    this.genelMudur,
    this.sektor,
    this.webSitesi,
    this.halkaArzTarihi,
    this.odenmisSermaye,
    this.fiiliDolasimOrani,
    this.fiiliDolasimOraniYuzde,
    this.sirketHakkinda,
  });

  bool get hasData =>
      sirketUnvani != null ||
      kurulusTarihi != null ||
      genelMudur != null ||
      sektor != null ||
      webSitesi != null ||
      halkaArzTarihi != null ||
      odenmisSermaye != null ||
      fiiliDolasimOrani != null ||
      fiiliDolasimOraniYuzde != null ||
      (sirketHakkinda != null && sirketHakkinda!.trim().isNotEmpty);
}
