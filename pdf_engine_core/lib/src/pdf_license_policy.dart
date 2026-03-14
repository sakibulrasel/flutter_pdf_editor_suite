/// Licensing state used by viewer and exporter feature gates.
enum PdfLicenseState { licensed, unlicensed }

/// Simple license policy model for watermark and feature checks.
final class PdfLicensePolicy {
  /// Creates a license policy with the provided [state].
  const PdfLicensePolicy({
    required this.state,
    this.watermarkText = 'UNLICENSED',
  });

  /// Creates a licensed policy.
  const PdfLicensePolicy.licensed({
    this.watermarkText = 'UNLICENSED',
  }) : state = PdfLicenseState.licensed;

  /// Creates an unlicensed policy.
  const PdfLicensePolicy.unlicensed({
    this.watermarkText = 'UNLICENSED',
  }) : state = PdfLicenseState.unlicensed;

  /// Current license state.
  final PdfLicenseState state;

  /// Watermark text shown when the policy is unlicensed.
  final String watermarkText;

  /// Whether watermarking should be applied.
  bool get showWatermark => state == PdfLicenseState.unlicensed;

  /// Whether premium behavior should be enabled.
  bool get isLicensed => state == PdfLicenseState.licensed;
}
