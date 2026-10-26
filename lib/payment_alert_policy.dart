/// Policy for whether a detected payment needs an audible OS notification.
///
/// A verification-required incoming credit gets an audible notification even
/// when speech is enabled. Background TTS can fail silently on some Android
/// devices, so confirmation prompts must not rely on TTS as the only alert.
bool shouldUseAudiblePaymentAlert({
  required bool isLate,
  required bool voiceEnabled,
  required bool hasConflict,
  required bool needsVerification,
}) {
  return isLate || !voiceEnabled || hasConflict || needsVerification;
}
