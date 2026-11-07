enum SaleEchoVerdict { distinct, hardEcho, possibleRepeat }

class SaleEchoResult {
  const SaleEchoResult(this.verdict, this.reason);
  final SaleEchoVerdict verdict;
  final String reason;
}

class SaleEchoCandidate {
  const SaleEchoCandidate({
    required this.id,
    required this.amount,
    required this.direction,
    required this.appKey,
    required this.appFamily,
    required this.at,
    this.reference,
    this.sourceFingerprint,
    this.text = '',
  });

  final String id;
  final double amount;
  final String direction;
  final String appKey;
  final String appFamily;
  final DateTime at;
  final String? reference;
  final String? sourceFingerprint;
  final String text;
}

class SalePaymentEchoPolicy {
  SalePaymentEchoPolicy._();

  static const Duration immediateReplayWindow = Duration(seconds: 10);
  static const Duration identicalTextWindow = Duration(seconds: 90);
  static const Duration crossChannelWindow = Duration(minutes: 12);

  static SaleEchoResult classify(
    SaleEchoCandidate current,
    Iterable<SaleEchoCandidate> recent,
  ) {
    String? weakReason;

    for (final previous in recent) {
      if (previous.id == current.id) {
        return const SaleEchoResult(SaleEchoVerdict.hardEcho, 'same_event');
      }

      if (current.reference != null && previous.reference != null) {
        if (current.reference == previous.reference) {
          return const SaleEchoResult(
            SaleEchoVerdict.hardEcho,
            'same_reference',
          );
        }
        continue;
      }

      if (current.sourceFingerprint != null &&
          current.sourceFingerprint == previous.sourceFingerprint) {
        return const SaleEchoResult(
          SaleEchoVerdict.hardEcho,
          'same_native_post',
        );
      }

      if ((current.amount - previous.amount).abs() >= 0.01 ||
          current.direction == 'unknown' ||
          current.direction != previous.direction) {
        continue;
      }

      final age = current.at.difference(previous.at).abs();
      final sameApp = current.appKey == previous.appKey;
      if (sameApp) {
        if (current.text.isEmpty || current.text != previous.text) continue;
        final bothHaveNativeIdentity =
            current.sourceFingerprint != null &&
            previous.sourceFingerprint != null;
        if (bothHaveNativeIdentity) continue;
        if (age <= immediateReplayWindow) {
          return const SaleEchoResult(
            SaleEchoVerdict.hardEcho,
            'immediate_replay',
          );
        }
        if (age <= identicalTextWindow) {
          weakReason ??= 'identical_text_same_app';
        }
        continue;
      }

      final crossChannel =
          (current.appFamily == 'bankRelay' &&
              (previous.appFamily == 'uplike' ||
                  previous.appFamily == 'bankRelay')) ||
          (previous.appFamily == 'bankRelay' &&
              (current.appFamily == 'uplike' ||
                  current.appFamily == 'bankRelay'));
      if (crossChannel && age <= crossChannelWindow) {
        weakReason ??= 'same_amount_other_channel';
      }
    }

    return weakReason == null
        ? const SaleEchoResult(SaleEchoVerdict.distinct, 'no_match')
        : SaleEchoResult(SaleEchoVerdict.possibleRepeat, weakReason);
  }

  static bool billAlreadyCovered({
    required double remainingDue,
    required Iterable<double> pendingAmounts,
    required double amount,
  }) {
    var pending = 0.0;
    for (final value in pendingAmounts) {
      if (value.isFinite && value > 0) pending += value;
    }
    return remainingDue - pending < amount - 0.5;
  }
}
