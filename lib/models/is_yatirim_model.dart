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
