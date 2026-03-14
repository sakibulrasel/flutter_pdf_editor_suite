/// One selectable value in a combo box or list box field.
final class PdfChoiceOption {
  /// Creates a choice option with a stored value and display label.
  const PdfChoiceOption({required this.value, required this.label});

  /// Raw value stored in the PDF field.
  final String value;

  /// User-facing label shown in selection UIs.
  final String label;
}
