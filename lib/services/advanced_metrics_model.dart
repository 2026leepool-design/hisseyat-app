class AdvancedMetrics {
  final double? fK;
  final double? pdDd;
  final double? roe;
  final double? temettuVerimi;
  final double? piyasaDegeri;
  final double? beta;

  const AdvancedMetrics({
    this.fK,
    this.pdDd,
    this.roe,
    this.temettuVerimi,
    this.piyasaDegeri,
    this.beta,
  });

  const AdvancedMetrics.empty()
      : fK = null,
        pdDd = null,
        roe = null,
        temettuVerimi = null,
        piyasaDegeri = null,
        beta = null;

  bool get hasCriticalData => fK != null;

  AdvancedMetrics mergeMissing(AdvancedMetrics? other) {
    if (other == null) return this;
    return AdvancedMetrics(
      fK: fK ?? other.fK,
      pdDd: pdDd ?? other.pdDd,
      roe: roe ?? other.roe,
      temettuVerimi: temettuVerimi ?? other.temettuVerimi,
      piyasaDegeri: piyasaDegeri ?? other.piyasaDegeri,
      beta: beta ?? other.beta,
    );
  }
}
