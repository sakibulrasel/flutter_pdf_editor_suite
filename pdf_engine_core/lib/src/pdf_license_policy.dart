enum PdfLicenseState { licensed, unlicensed }

final class PdfLicensePolicy {
  const PdfLicensePolicy({
    required this.state,
    this.watermarkText = 'UNLICENSED',
  });

  const PdfLicensePolicy.licensed({
    this.watermarkText = 'UNLICENSED',
  }) : state = PdfLicenseState.licensed;

  const PdfLicensePolicy.unlicensed({
    this.watermarkText = 'UNLICENSED',
  }) : state = PdfLicenseState.unlicensed;

  final PdfLicenseState state;
  final String watermarkText;

  bool get showWatermark => state == PdfLicenseState.unlicensed;
  bool get isLicensed => state == PdfLicenseState.licensed;
}
