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
  });

  const EchoResolution.none({bool ambiguous = false})
      : this._(
          isEcho: false,
          reason: ambiguous ? 'ambiguous_candidates_kept_separate' : 'no_match',
          ambiguous: ambiguous,
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

  /// Single structured log line. Contains ids and reasons only.
  String describe(String currentId) => isEcho
      ? 'merged $currentId into $matchedId reason=$reason'
      : 'kept $currentId separate reason=$reason';
}

class PaymentIdentityMatcher {
  PaymentIdentityMatcher._();

  /// App notification + bank SMS of one transfer usually land within a minute
  /// but share no payer, account or UTR. Pair one-to-one only.
  static const Duration weakModalityWindow = Duration(seconds: 60);
  static const Duration crossAppWindow = Duration(minutes: 10);

  /// Operators can queue bank SMS for an hour or more.
  static const Duration smsWindow = Duration(hours: 3);
  static const Duration truecallerWindow = Duration(seconds: 8);
  static const Duration defaultReplayWindow = Duration(seconds: 3);

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

  static bool _isTruecaller(String origin) => origin == 'truecaller_notification';

  /// Only pair a plain bank SMS with a payment-app notification on weak evidence.
  static bool isWeakModalityPair(String a, String b) =>
      (a == 'sms' && b == 'notification') ||
      (a == 'notification' && b == 'sms');

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
  }) {
    if ((current.amount - previous.amount).abs() >= 0.01) {
      return const IdentityDecision(IdentityVerdict.distinct, 'amount_differs');
    }

    final directionCompatible = current.direction == previous.direction ||
        current.direction == 'unknown' ||
        previous.direction == 'unknown';
    final directionKnownEqual =
        current.direction == previous.direction && current.direction != 'unknown';
    final bothReferences = current.reference != null && previous.reference != null;

    // 1. Same Android notification post (text may have been updated).
    if (current.sourceIdentity != null &&
        current.sourceIdentity == previous.sourceIdentity) {
      if (bothReferences && current.reference != previous.reference) {
        return const IdentityDecision(
            IdentityVerdict.distinct, 'same_post_different_reference');
      }
      return directionCompatible
          ? const IdentityDecision(
              IdentityVerdict.sameTransfer, 'same_native_post')
          : const IdentityDecision(
              IdentityVerdict.distinct, 'same_post_direction_conflict');
    }

    // 2. References: two different ones are two payments; equal is one.
    //    A reference on only one side proves nothing either way.
    if (bothReferences) {
      if (current.reference != previous.reference) {
        return const IdentityDecision(
            IdentityVerdict.distinct, 'different_reference');
      }
      return directionCompatible
          ? const IdentityDecision(IdentityVerdict.sameTransfer, 'same_reference')
          : const IdentityDecision(
              IdentityVerdict.distinct, 'same_reference_direction_conflict');
    }

    // Everything below is fuzzy and needs a known, equal direction.
    if (!directionKnownEqual) {
      return const IdentityDecision(
          IdentityVerdict.distinct, 'direction_unknown_or_differs');
    }

    final age = current.at.difference(previous.at).abs();

    // 3. Same channel: only a native-post match or an exact immediate replay
    //    can prove a repeat. Distinct native posts are distinct payments.
    if (current.channel == previous.channel) {
      if (current.sourceIdentity != null || previous.sourceIdentity != null) {
        return const IdentityDecision(
            IdentityVerdict.distinct, 'distinct_native_posts');
      }
      if (age <= sameChannelReplayWindow &&
          current.text.isNotEmpty &&
          current.text == previous.text) {
        return const IdentityDecision(
            IdentityVerdict.sameTransfer, 'same_channel_exact_replay');
      }
      return const IdentityDecision(
          IdentityVerdict.distinct, 'same_channel_no_proof');
    }

    // 4. Cross-channel echo.
    final allowed = (_involvesSms(current.origin) || _involvesSms(previous.origin))
        ? smsWindow
        : crossAppWindow;
    if (age > allowed) {
      return const IdentityDecision(IdentityVerdict.distinct, 'outside_window');
    }

    final accountConflict = current.account != null &&
        previous.account != null &&
        current.account != previous.account;
    if (accountConflict) {
      return const IdentityDecision(IdentityVerdict.distinct, 'account_conflict');
    }
    final payerConflict = current.payer != null &&
        previous.payer != null &&
        !_payersCompatible(current.payer!, previous.payer!);
    if (payerConflict) {
      return const IdentityDecision(IdentityVerdict.distinct, 'payer_conflict');
    }

    if (current.account != null && current.account == previous.account) {
      return const IdentityDecision(IdentityVerdict.candidateEcho, 'same_account');
    }
    if (current.payer != null && previous.payer != null) {
      return const IdentityDecision(IdentityVerdict.candidateEcho, 'same_payer');
    }

    final truecallerMirror = age <= truecallerWindow &&
        _isTruecaller(current.origin) != _isTruecaller(previous.origin) &&
        _trustedCounterpart(
          _isTruecaller(current.origin) ? previous.channel : current.channel,
        );
    if (truecallerMirror) {
      return const IdentityDecision(
          IdentityVerdict.candidateEcho, 'truecaller_mirror');
    }

    if (age <= weakModalityWindow &&
         isWeakModalityPair(current.origin, previous.origin)) {
      return const IdentityDecision(
          IdentityVerdict.candidateEcho, 'weak_modality_pair');
    }

    return const IdentityDecision(
        IdentityVerdict.distinct, 'no_shared_evidence');
  }

  /// Compare [current] against recent signals and apply the safety rules that
  /// pairwise comparison cannot: one-to-one claims per channel, and "more than
  /// one plausible match means keep both" so a real second payment is never
  /// swallowed.
  ///
  /// [claims] maps a previous signal id to the channels it has already
  /// absorbed an echo from.
  static EchoResolution resolve(
    SignalIdentity current,
    Iterable<SignalIdentity> recent, {
    Map<String, Set<String>> claims = const {},
    Duration sameChannelReplayWindow = defaultReplayWindow,
  }) {
    SignalIdentity? candidate;
    String candidateReason = '';
    var ambiguous = false;

    for (final previous in recent) {
      final decision = compare(
        current,
        previous,
        sameChannelReplayWindow: sameChannelReplayWindow,
      );
      switch (decision.verdict) {
        case IdentityVerdict.sameTransfer:
          return EchoResolution.proof(previous.id, decision.reason);
        case IdentityVerdict.distinct:
          continue;
        case IdentityVerdict.candidateEcho:
          if (claims[previous.id]?.contains(current.channel) ?? false) continue;
          if (candidate != null && candidate.id != previous.id) {
            ambiguous = true;
          } else {
            candidate = previous;
            candidateReason = decision.reason;
          }
      }
      if (ambiguous) break;
    }

    if (candidate != null && !ambiguous) {
      return EchoResolution.echo(candidate.id, candidateReason, current.channel);
    }
    return EchoResolution.none(ambiguous: ambiguous);
  }
}
