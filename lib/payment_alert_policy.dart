/// Policy for whether a detected payment needs an audible OS notification.
///
/// When voice is enabled, TTS owns routine live payment announcements. The OS
/// notification stays silent so one detected payment does not produce speech
/// plus a second sound. Late events, disabled voice, and identity conflicts
/// remain independently audible.
///
/// A silent notification is upgraded if the associated TTS announcement
/// fails, times out, expires, or has no active speaker.
bool shouldUseAudiblePaymentAlert({
  required bool isLate,
  required bool voiceEnabled,
  required bool hasConflict,
}) {
  return isLate || !voiceEnabled || hasConflict;
}
