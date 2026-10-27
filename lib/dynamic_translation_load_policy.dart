/// Bounds dynamic translation work to protect entry-level Android devices.
///
/// UI labels covered by the local translation dictionaries do not use this
/// queue. These limits only apply to unmatched, dynamic display strings.
class DynamicTranslationLoadPolicy {
  DynamicTranslationLoadPolicy._();

  /// Keep low-RAM devices from accumulating hundreds of translation futures
  /// while a large dashboard is being built.
  static const int maxPendingLowEnd = 40;
  static const int maxPendingStandard = 240;

  static int maxPending({required bool lowEndDevice}) =>
      lowEndDevice ? maxPendingLowEnd : maxPendingStandard;

  static bool shouldAccept({
    required int pendingUniqueRequests,
    required bool lowEndDevice,
  }) {
    if (pendingUniqueRequests < 0) return false;
    return pendingUniqueRequests < maxPending(lowEndDevice: lowEndDevice);
  }
}
