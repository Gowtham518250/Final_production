import 'package:flutter_test/flutter_test.dart';
import 'package:retail_mind/indic_number_repair.dart';

NumberRepairResult te(String s) => IndicNumberRepair.repair(s, 'te-IN');

void main() {
  group('repairs what the recogniser misspells (from a real Telugu bill)', () {
    const heard =
        'ఇండు కిలో పంచేదారా ఆరవే రూపాయలు ఒక నూనే నూటే ఆవి మరియు ఒక చికన్ బిరియాని రేణు ఉందలు మరియు ఒక మటన్ బిరియాని ఆయ్దు ఉందలు';

    test('the whole sentence', () {
      final r = te(heard);
      expect(
        r.text,
        '2 కిలో పంచేదారా 60 రూపాయలు ఒక నూనే నూటే ఆవి మరియు ఒక చికన్ బిరియాని 200 మరియు ఒక మటన్ బిరియాని 500',
      );
    });

    test('chicken biryani is 200 and mutton biryani is 500 (not both 500)', () {
      final r = te(heard);
      expect(r.text.contains('చికన్ బిరియాని 200'), true);
      expect(r.text.contains('మటన్ బిరియాని 500'), true);
    });

    test('every repair is reported so the shopkeeper can verify it', () {
      final r = te(heard);
      expect(r.repairs.length, 4);
      expect(r.repairs.map((e) => e.value).join(','), '2,60,200,500');
    });

    test('words it could not understand are left alone, never guessed', () {
      final r = te(heard);
      expect(r.text.contains('నూటే ఆవి'), true);
    });
  });

  group('canonical speech', () {
    test('plain numbers are untouched', () {
      final r = te('రెండు కిలో బియ్యం యాభై రూపాయలు');
      expect(r.text, 'రెండు కిలో బియ్యం యాభై రూపాయలు');
      expect(r.repairs.length, 0);
    });

    test('a correct scale phrase becomes digits with no warning', () {
      final r = te('ఐదు వందలు');
      expect(r.text, '500');
      expect(r.repairs.length, 0);
    });

    test('hundreds plus a remainder', () {
      expect(te('రెండు వందలు యాభై').text, '250');
      expect(te('నూట యాభై').text, '150');
    });

    test('thousands', () {
      expect(te('రెండు వేలు').text, '2000');
    });
  });

  group('safety: everyday words are never turned into prices', () {
    const everyday = [
      'బియ్యం', 'నూనె', 'పాలు', 'ఉప్పు', 'పప్పు', 'చక్కెర', 'ఉల్లిపాయ',
      'టమాటా', 'పెరుగు', 'వెన్న', 'కారం', 'చికెన్', 'మటన్', 'బిర్యానీ',
      'చేప', 'గుడ్డు', 'టీ', 'కాఫీ', 'సబ్బు', 'నీళ్లు',
      // words containing nasal clusters (ండ, ంద, ంబ) that must not collapse
      // onto రెండు / వందలు
      'పండు', 'అరటిపండు', 'మామిడిపండు', 'కందిపప్పు', 'బంగాళాదుంప',
      'చందనం', 'కొబ్బరి', 'దోసె', 'ఇడ్లీ', 'మిరపకాయ', 'వెల్లుల్లి',
      'అల్లం', 'బెల్లం', 'శనగలు', 'పెసలు', 'మినుములు', 'నెయ్యి',
      'గోధుమ', 'మైదా', 'రవ్వ', 'కూల్‌డ్రింక్', 'బిస్కెట్', 'బ్రెడ్',
    ];
    for (final word in everyday) {
      test('"$word" next to a price word or unit stays a word', () {
        expect(te('$word రూపాయలు').text, '$word రూపాయలు');
        expect(te('$word కిలో').text, '$word కిలో');
      });
    }

    test('a lone scale-sounding word with no number before it is not converted', () {
      expect(te('నాకు ఉందలు రూపాయలు').text, 'నాకు ఉందలు రూపాయలు');
    });

    test('a number-sounding word with no price, unit or scale next to it stays', () {
      expect(te('ఇండు ఆవి').text, 'ఇండు ఆవి');
    });
  });

  group('other languages and edge cases', () {
    test('a language without a lexicon is returned unchanged', () {
      final r = IndicNumberRepair.repair('दो किलो चावल', 'hi-IN');
      expect(r.text, 'दो किलो चावल');
      expect(r.repairs.length, 0);
    });

    test('empty input', () {
      expect(te('').text, '');
      expect(te('   ').repairs.length, 0);
    });

    test('language code forms te, te-IN, te_IN all work', () {
      for (final code in ['te', 'te-IN', 'te_IN', 'TE-in']) {
        expect(IndicNumberRepair.repair('ఇండు కిలో', code).text, '2 కిలో');
      }
    });
  });
}
