/// Single rule for whether a spoken bill line can start checked.
///
/// Both the assistant parser and VoiceNlpEngineV2 must use this so a
/// low-confidence or ambiguous "rice 60" line is never auto-confirmed
/// in one path and skipped in the other.
class VoiceItemConfirmation {
  static const double autoConfirmMinConfidence = 0.6;

  static bool shouldAutoConfirm({
    required double confidence,
    required bool catalogMatched,
    bool quantityPriceAmbiguous = false,
  }) {
    if (quantityPriceAmbiguous) return false;
    if (!confidence.isFinite || confidence < 0) return false;
    return confidence >= autoConfirmMinConfidence || catalogMatched;
  }
}
