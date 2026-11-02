// =============================================================================
// payment_direction_speech.dart
//
// Pure helpers for SPEAKING a payment without ever saying the wrong direction.
// No Flutter, no plugins: unit-testable with `dart test`.
//
// Rule for anything spoken aloud: if the app cannot tell whether money came in
// or went out, it must say so. It must never fall back to wording that means
// "received". Accounting keeps its own, stricter classifier; this file only
// affects speech.
// =============================================================================

/// Bank SMS often mention BOTH sides of one transfer, e.g.
/// "Rs 500 debited from A/c XX1234 ... credited to ramesh@upi".
/// The general classifier sees a credit cue and a debit cue and gives up.
/// For speech we can do better: the cue attached to the user's OWN account
/// wins ("debited from A/c ...", "credited to your A/c ...").
///
/// Returns `'credit'`, `'debit'`, or `null` when it is still ambiguous (both
/// own-account cues present, or neither).
String? ownAccountDirection(String text) {
  final t = text.toLowerCase();
  final ownDebit = RegExp(
    r'\b(?:debited|deducted|withdrawn)\b[^.]{0,50}?\bfrom\s+'
    r'(?:your\b|a\/c|acct|account)',
  ).hasMatch(t);
  final ownCredit = RegExp(
    r'\bcredited\b[^.]{0,30}?\b(?:to|in)\s+your\b',
  ).hasMatch(t);
  if (ownDebit && !ownCredit) return 'debit';
  if (ownCredit && !ownDebit) return 'credit';
  return null;
}

/// Direction-neutral alert used when credit vs debit is unknown. Deliberately
/// avoids every word that means "received", "came" or "got".
///
/// [languageKey] is `VoiceLanguage.name`: english, hindi, tamil, telugu,
/// kannada, marathi, gujarati, bengali, punjabi, malayalam. Unknown keys fall
/// back to English. [amountText] is the already formatted amount.
///
/// NOTE: have a native speaker of each language review these phrases before
/// release.
String neutralPaymentAlert(String languageKey, String amountText) {
  switch (languageKey) {
    case 'hindi':
      return '$amountText का भुगतान संदेश। जमा हुआ या कटा, ऐप में जांचें।';
    case 'tamil':
      return '$amountText பணப் பரிவர்த்தனை அறிவிப்பு. வரவா அல்லது பற்றா என்று சரிபார்க்கவும்.';
    case 'telugu':
      return '$amountText లావాదేవీ నోటిఫికేషన్. జమ అయిందో డెబిట్ అయిందో చెక్ చేయండి.';
    case 'kannada':
      return '$amountText ವಹಿವಾಟು ಸೂಚನೆ. ಜಮಾ ಆಗಿದೆಯೇ ಅಥವಾ ಡೆಬಿಟ್ ಆಗಿದೆಯೇ ಎಂದು ಪರಿಶೀಲಿಸಿ.';
    case 'marathi':
      return '$amountText व्यवहाराची सूचना. जमा झाले की वजा झाले ते तपासा.';
    case 'gujarati':
      return '$amountText વ્યવહારની સૂચના. જમા થયું કે કપાયું તે ચકાસો.';
    case 'bengali':
      return '$amountText লেনদেনের বিজ্ঞপ্তি। জমা হয়েছে নাকি কাটা হয়েছে যাচাই করুন।';
    case 'punjabi':
      return '$amountText ਲੈਣ-ਦੇਣ ਦੀ ਸੂਚਨਾ। ਜਮ੍ਹਾਂ ਹੋਈ ਜਾਂ ਕੱਟੀ ਗਈ, ਜਾਂਚ ਕਰੋ।';
    case 'malayalam':
      return '$amountText ഇടപാട് അറിയിപ്പ്. ക്രെഡിറ്റ് ആണോ ഡെബിറ്റ് ആണോ എന്ന് പരിശോധിക്കുക.';
    default:
      return 'Payment of $amountText detected. The app could not tell whether '
          'it was credited or debited. Please check.';
  }
}

/// A separate payment signal kept despite weak echo evidence; asks the
/// merchant to verify it and does not claim that money was received.
String anotherPaymentAlert(String languageKey, String amountText) {
  switch (languageKey) {
    case 'hindi':
      return 'एक और $amountText का भुगतान दिखा है। कृपया पुष्टि करें।';
    case 'tamil':
      return 'மேலும் ஒரு $amountText கட்டணம் கண்டறியப்பட்டது. தயவுசெய்து சரிபார்க்கவும்.';
    case 'telugu':
      return 'మరో $amountText చెల్లింపు గుర్తించబడింది. దయచేసి ధృవీకరించండి.';
    case 'kannada':
      return 'ಇನ್ನೊಂದು $amountText ಪಾವತಿ ಪತ್ತೆಯಾಗಿದೆ. ದಯವಿಟ್ಟು ಪರಿಶೀಲಿಸಿ.';
    case 'marathi':
      return 'आणखी एक $amountText भरणा आढळला. कृपया तपासा.';
    case 'gujarati':
      return 'વધુ એક $amountText ચુકવણી મળી આવી છે. કૃપા કરીને ચકાસો.';
    case 'bengali':
      return 'আরও একটি $amountText পেমেন্ট শনাক্ত হয়েছে। অনুগ্রহ করে যাচাই করুন।';
    case 'punjabi':
      return 'ਇੱਕ ਹੋਰ $amountText ਭੁਗਤਾਨ ਦਾ ਪਤਾ ਲੱਗਾ ਹੈ। ਕਿਰਪਾ ਕਰਕੇ ਜਾਂਚੋ।';
    case 'malayalam':
      return 'മറ്റൊരു $amountText പേയ്മെന്റ് കണ്ടെത്തി. ദയവായി പരിശോധിക്കുക.';
    default:
      return 'Another payment of $amountText detected. Please verify.';
  }
}
