// =============================================================================
// payment_identity_matcher.dart
//
// ONE place that answers: "are these two payment signals the same transfer?"
//
// A single payment can reach the app as several signals: a payment-app
// notification, a bank SMS, a Truecaller mirror, an accessibility update, or a
// replay after a service restart. Before this file, the matching rules were
// hand-copied into three layers (detection, voice queue, cross-isolate guard)
// plus a Java gate, and the copies drifted apart. New layers must call this
// matcher instead of re-implementing the rules.
//
// Pure Dart on purpose (no Flutter, no plugins): it is fully unit-testable
// with `dart test` and carries no I/O. It only decides identity for ANNOUNCEMENT
// and ALERT suppression; it is never proof of settlement and must never update
// sales or invoices.
// =============================================================================

/// Normalised view of one payment signal. Build it with the adapters in the
/// layer that owns the raw event; do not add parsing here.
class SignalIdentity {
  const SignalIdentity({
    required this.id,
    required this.amount,
    required this.direction,
    required this.channel,
    required this.origin,
    required this.at,
    this.reference,
    this.payer,
    this.account,
    this.sourceIdentity,
    this.notificationStream,
    this.notificationAt,
    this.notificationPayer,
    this.text = '',
  });

  /// Unique id of this signal (not of the transfer).
  final String id;
  final double amount;

  /// `credit`, `debit` or `unknown`.
  final String direction;

  /// `<origin>|<app or package>`, e.g. `notification|phonepe`.
  final String channel;

  /// `sms`, `notification`, `notification+sms`, `accessibility`,
  /// `truecaller_notification`.
  final String origin;
  final DateTime at;

  /// Normalised UTR / reference, when the source exposes one.
  final String? reference;

  /// Normalised payer name; null when absent or generic ("customer", "bank").
  final String? payer;

  /// Last digits of the masked account, digits only.
  final String? account;

  /// Stable identity of the native Android notification post (hashed).
  final String? sourceIdentity;

  /// Stable notification slot identity, excluding post time and payload.
  final String? notificationStream;

  /// Source post time, distinct from [at] which is the processing time.
  final DateTime? notificationAt;

  /// Unicode-preserving payer identity for notification repost comparison.
  final String? notificationPayer;

  /// Whitespace-normalised, lower-cased text, used only for exact replays.
  final String text;
}

enum IdentityVerdict {
  /// Proven same transfer (same native post, same reference, exact replay).
  sameTransfer,

  /// Looks like an echo of the other signal; the caller must still check
  /// uniqueness and per-channel claims (see [PaymentIdentityMatcher.resolve]).
  candidateEcho,

  /// Different transfers, or not enough evidence to merge them.
  distinct,
}

class IdentityDecision {
  const IdentityDecision(this.verdict, this.reason);
  final IdentityVerdict verdict;

  /// Short machine-friendly reason, safe to log (no payment content).
  final String reason;
}

class EchoResolution {
  const EchoResolution._({
    required this.isEcho,
    required this.reason,
    this.matchedId,
    this.claimChannel,
    this.ambiguous = false,
    this.possibleMatch = false,
  });

  const EchoResolution.none({
    bool ambiguous = false,
    bool possibleMatch = false,
  }) : this._(
         isEcho: false,
         reason: ambiguous ? 'ambiguous_candidates_kept_separate' : 'no_match',
         ambiguous: ambiguous,
         possibleMatch: possibleMatch,
       );

  const EchoResolution.proof(String matchedId, String reason)
    : this._(isEcho: true, reason: reason, matchedId: matchedId);

  const EchoResolution.echo(
    String matchedId,
    String reason,
    String claimChannel,
  ) : this._(
        isEcho: true,
        reason: reason,
        matchedId: matchedId,
        claimChannel: claimChannel,
      );

  final bool isEcho;
  final String reason;
  final String? matchedId;

  /// When set, the caller must record that [matchedId] has now been paired
  /// with this channel, so one payment can absorb at most one echo per channel.
  final String? claimChannel;
  final bool ambiguous;
  final bool possibleMatch;

  /// Single structured log line. Contains ids and reasons only.
  String describe(String currentId) => isEcho
      ? 'merged $currentId into $matchedId reason=$reason'
      : 'kept $currentId separate reason=$reason';
}

class PaymentIdentityMatcher {
  PaymentIdentityMatcher._();

  /// Amount/direction alone is weak evidence, so a weak pair is only MUTED and
  /// flagged "possible repeat" (never merged). Bank SMS routinely arrives
  /// minutes after the payment-app notification, so 60s let the late SMS be
  /// announced as a second payment. Three minutes covers normal SMS delay while
  /// ambiguity (several candidates) still keeps real payments separate.
  static const Duration weakModalityWindow = Duration(minutes: 3);
  static const String weakModalityReason = 'weak_modality_pair';

  /// Same notification slot, amount and direction can be an update/repost even
  /// without payer/account/reference fields. Conflicts still block this match.
  static const Duration sameStreamRepostWindow = Duration(seconds: 60);
  static const Duration crossAppWindow = Duration(minutes: 10);

  /// Operators can queue bank SMS for an hour or more.
  static const Duration smsWindow = Duration(hours: 3);
  static const Duration truecallerWindow = Duration(seconds: 8);
  static const Duration defaultReplayWindow = Duration(seconds: 3);
  static const Duration notificationUpdateWindow = Duration(seconds: 30);

  static const Set<String> _trustedTruecallerCounterparts = {
    'googlepay',
    'phonepe',
    'paytm',
    'amazonpay',
    'bhim',
    'payzapp',
    'icici',
    'sbiyono',
    'axis',
    'hdfc',
    'banksms',
    'bankapp',
    'com.google.android.apps.nbu.paisa.user',
    'com.google.android.apps.nbu.paisa.merchant',
    'net.one97.paytm',
    'com.paytm.business',
    'com.phonepe.app',
    'com.phonepe.app.business',
    'com.phonepe.app.merchant',
    'com.phonepe.business',
    'in.org.npci.upiapp',
    'com.dreamplug.androidapp',
    'com.hdfcbank.payzapp',
    'com.icicibank.imobile',
    'com.sbi.imobile',
    'com.axis.mobile',
    'com.hdfcbank.smartbuy',
    'com.indusind.mobilebanking',
    'com.yes.mobile',
    'com.baroda.mpassbook',
    'com.canarabank.mobility',
    'com.kotak.mobile.banking',
  };

  static bool _isTruecaller(String origin) =>
      origin == 'truecaller_notification';

  /// A bank SMS reaches the app either through the SMS receiver ('sms') or as
  /// the Messages-app notification of that same SMS ('notification+sms').
  /// Both are the SMS side of a pair with a payment-app notification.
  static bool _isSmsSide(String origin) =>
      origin == 'sms' || origin == 'notification+sms';

  /// Only pair a bank SMS (or its Messages-app copy) with a payment-app
  /// notification on weak evidence.
  static bool isWeakModalityPair(String a, String b) =>
      (_isSmsSide(a) && b == 'notification') ||
      (a == 'notification' && _isSmsSide(b));

  /// Loose: any SMS involvement, used only to pick the long time window.
  static bool _involvesSms(String origin) => origin.contains('sms');

  static bool _trustedCounterpart(String channel) {
    final parts = channel.toLowerCase().split('|');
    if (parts.isEmpty) return false;
    final origin = parts.first;
    if (origin == 'sms' || origin == 'notification+sms') return true;
    return _trustedTruecallerCounterparts.contains(parts.last);
  }

  static bool _payersCompatible(String a, String b) =>
      a == b || a.contains(b) || b.contains(a);

  /// Pairwise decision. Order matters: proof first, then evidence conflicts,
  /// then weak evidence. Amount alone is never identity, except for the one
  /// bounded cross-modality case documented on [weakModalityWindow].
  static IdentityDecision compare(
    SignalIdentity current,
    SignalIdentity previous, {
    Duration sameChannelReplayWindow = defaultReplayWindow,
    Duration weakWindow = weakModalityWindow,
  }) {
    if ((current.amount - previous.amount).abs() >= 0.01) {
      return const IdentityDecision(IdentityVerdict.distinct, 'amount_differs');
    }

    final directionCompatible =
        current.direction == previous.direction ||
        current.direction == 'unknown' ||
        previous.direction == 'unknown';
    final directionKnownEqual =
        current.direction == previous.direction &&
        current.direction != 'unknown';
    final bothReferences =
        current.reference != null && previous.reference != null;

    // 1. Same Android notification post (text may have been updated).
    if (current.sourceIdentity != null &&
        current.sourceIdentity == previous.sourceIdentity) {
      if (bothReferences && current.reference != previous.reference) {
        return const IdentityDecision(
          IdentityVerdict.distinct,
          'same_post_different_reference',
        );
      }
      return directionCompatible
          ? const IdentityDecision(
              IdentityVerdict.sameTransfer,
              'same_native_post',
            )
          : const IdentityDecision(
              IdentityVerdict.distinct,
              'same_post_direction_conflict',
            );
    }

    // 2. References: two different ones are two payments; equal is one.
    //    A reference on only one side proves nothing either way.
    if (bothReferences) {
      if (current.reference != previous.reference) {
        return const IdentityDecision(
          IdentityVerdict.distinct,
          'different_reference',
        );
      }
      return directionCompatible
          ? const IdentityDecision(
              IdentityVerdict.sameTransfer,
              'same_reference',
            )
          : const IdentityDecision(
              IdentityVerdict.distinct,
              'same_reference_direction_conflict',
            );
    }

    final notificationAt = current.notificationAt ?? current.at;
    final previousNotificationAt = previous.notificationAt ?? previous.at;
    final notificationAccountConflict =
        current.account != null &&
        previous.account != null &&
        current.account != previous.account;
    final currentNotificationPayer = current.notificationPayer ?? current.payer;
    final previousNotificationPayer =
        previous.notificationPayer ?? previous.payer;
    final notificationPayerConflict =
        currentNotificationPayer != null &&
        previousNotificationPayer != null &&
        currentNotificationPayer != previousNotificationPayer;
    final sameNotificationAccount =
        current.account != null &&
        previous.account != null &&
        current.account == previous.account;
    final sameNotificationPayer =
        currentNotificationPayer != null &&
        previousNotificationPayer != null &&
        _payersCompatible(currentNotificationPayer, previousNotificationPayer);
    // An in-place notification update usually ENRICHES the first post, e.g.
    // "Rs 500 received" -> "Rs 500 received from Ravi, UTR 123". Evidence that
    // exists on only one side is new information about the same notification
    // slot, not a second payment. Two different references never reach here as
    // an echo, and any payer/account conflict keeps the posts separate.
    final bothHaveReference =
        current.reference != null && previous.reference != null;
    final oneSidedEvidence =
        (current.reference == null) != (previous.reference == null) ||
        (currentNotificationPayer == null) !=
            (previousNotificationPayer == null) ||
        (current.account == null) != (previous.account == null);
    if (!bothHaveReference &&
        oneSidedEvidence &&
        current.notificationStream != null &&
        current.notificationStream == previous.notificationStream &&
        directionKnownEqual &&
        notificationAt.difference(previousNotificationAt).abs() <=
            notificationUpdateWindow &&
        !notificationAccountConflict &&
        !notificationPayerConflict) {
      return const IdentityDecision(
        IdentityVerdict.candidateEcho,
        'same_notification_enrichment',
      );
    }
    if (current.reference == null &&
        previous.reference == null &&
        current.notificationStream != null &&
        current.notificationStream == previous.notificationStream &&
        directionKnownEqual &&
        notificationAt.difference(previousNotificationAt).abs() <=
            sameStreamRepostWindow &&
        !notificationAccountConflict &&
        !notificationPayerConflict) {
      return IdentityDecision(
        IdentityVerdict.candidateEcho,
        sameNotificationAccount || sameNotificationPayer
            ? 'same_notification_update'
            : 'same_notification_stream_amount',
      );
    }

    // Everything below is fuzzy and needs a known, equal direction.
    if (!directionKnownEqual) {
      return const IdentityDecision(
        IdentityVerdict.distinct,
        'direction_unknown_or_differs',
      );
    }

    final age = current.at.difference(previous.at).abs();

    // 3. Same channel: only a native-post match or an exact immediate replay
    //    can prove a repeat. Distinct native posts are distinct payments.
    if (current.channel == previous.channel) {
      if (current.sourceIdentity != null || previous.sourceIdentity != null) {
        return const IdentityDecision(
          IdentityVerdict.distinct,
          'distinct_native_posts',
        );
      }
      if (age <= sameChannelReplayWindow &&
          current.text.isNotEmpty &&
          current.text == previous.text) {
        return const IdentityDecision(
          IdentityVerdict.candidateEcho,
          'same_channel_exact_replay',
        );
      }
      return const IdentityDecision(
        IdentityVerdict.distinct,
        'same_channel_no_proof',
      );
    }

    // 4. Cross-channel echo.
    final allowed =
        (_involvesSms(current.origin) || _involvesSms(previous.origin))
        ? smsWindow
        : crossAppWindow;
    if (age > allowed) {
      return const IdentityDecision(IdentityVerdict.distinct, 'outside_window');
    }

    final accountConflict =
        current.account != null &&
        previous.account != null &&
        current.account != previous.account;
    if (accountConflict) {
      return const IdentityDecision(
        IdentityVerdict.distinct,
        'account_conflict',
      );
    }
    // Truecaller may extract a bank label as the payer from Business Chat text.
    final ignorePayer =
        _isTruecaller(current.origin) || _isTruecaller(previous.origin);
    final payerConflict =
        !ignorePayer &&
        current.payer != null &&
        previous.payer != null &&
        !_payersCompatible(current.payer!, previous.payer!);
    if (payerConflict) {
      return const IdentityDecision(IdentityVerdict.distinct, 'payer_conflict');
    }

    // When a reference exists on only one signal, a shared masked account or
    // payer is not enough to prove that the two observations are the same
    // transfer. Keep them separate instead of letting fuzzy evidence override
    // the one-sided transaction identity. A reference-free weak modality pair
    // is still allowed inside the dedicated 60-second window below.
    final oneSidedReference =
        (current.reference == null) != (previous.reference == null);
    if (oneSidedReference &&
        ((current.account != null && current.account == previous.account) ||
            (!ignorePayer &&
                current.payer != null &&
                previous.payer != null))) {
      if (weakWindow > Duration.zero &&
          age <= weakWindow &&
          isWeakModalityPair(current.origin, previous.origin)) {
        return const IdentityDecision(
          IdentityVerdict.candidateEcho,
          'utr_enrichment',
        );
      }
      return const IdentityDecision(
        IdentityVerdict.distinct,
        'one_sided_reference_not_fuzzy_matched',
      );
    }

    if (current.account != null && current.account == previous.account) {
      return const IdentityDecision(
        IdentityVerdict.candidateEcho,
        'same_account',
      );
    }
    if (!ignorePayer && current.payer != null && previous.payer != null) {
      return const IdentityDecision(
        IdentityVerdict.candidateEcho,
        'same_payer',
      );
    }

    final truecallerMirror =
        age <= truecallerWindow &&
        _isTruecaller(current.origin) != _isTruecaller(previous.origin) &&
        _trustedCounterpart(
          _isTruecaller(current.origin) ? previous.channel : current.channel,
        );
    if (truecallerMirror) {
      return const IdentityDecision(
        IdentityVerdict.candidateEcho,
        'truecaller_mirror',
      );
    }

    if (weakWindow > Duration.zero &&
        age <= weakWindow &&
        isWeakModalityPair(current.origin, previous.origin)) {
      return const IdentityDecision(
        IdentityVerdict.candidateEcho,
        weakModalityReason,
      );
    }

    return const IdentityDecision(
      IdentityVerdict.distinct,
      'no_shared_evidence',
    );
  }

  /// Resolve proof-backed matches and unique cross-source matches with shared
  /// payer/account evidence. Weak or ambiguous candidates remain separate.
  ///
  /// [claims] maps a previous signal id to the channels it has already
  /// absorbed an echo from.
  static EchoResolution resolve(
    SignalIdentity current,
    Iterable<SignalIdentity> recent, {
    Map<String, Set<String>> claims = const {},
    Duration sameChannelReplayWindow = defaultReplayWindow,
    Duration weakWindow = weakModalityWindow,
  }) {
    var possibleMatch = false;
    var ambiguous = false;
    String? candidateId;
    String? candidateReason;

    for (final previous in recent) {
      final decision = compare(
        current,
        previous,
        sameChannelReplayWindow: sameChannelReplayWindow,
        weakWindow: weakWindow,
      );
      switch (decision.verdict) {
        case IdentityVerdict.sameTransfer:
          return EchoResolution.proof(previous.id, decision.reason);
        case IdentityVerdict.distinct:
          continue;
        case IdentityVerdict.candidateEcho:
          if (claims[previous.id]?.contains(current.channel) ?? false) continue;
          possibleMatch = true;
          if (candidateId != null && candidateId != previous.id) {
            ambiguous = true;
          } else {
            candidateId = previous.id;
            candidateReason = decision.reason;
          }
      }
    }

    const strongMatchReasons = {
      'same_account',
      'same_payer',
      'utr_enrichment',
      'same_notification_update',
      'same_notification_enrichment',
    };
    if (!ambiguous &&
        candidateId != null &&
        strongMatchReasons.contains(candidateReason)) {
      return EchoResolution.echo(
        candidateId,
        candidateReason!,
        current.channel,
      );
    }

    return EchoResolution.none(
      ambiguous: ambiguous,
      possibleMatch: possibleMatch,
    );
  }
}
