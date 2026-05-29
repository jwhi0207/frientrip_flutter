import 'package:flutter_test/flutter_test.dart';
import 'package:frientrip/utils/invite_code.dart';

const _validAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
final _validChars = _validAlphabet.split('').toSet();

void main() {
  group('generateInviteCode', () {
    test('has format XXXX-XXXX', () {
      for (int i = 0; i < 20; i++) {
        final code = generateInviteCode();
        expect(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(code), isTrue,
            reason: 'code "$code" does not match XXXX-XXXX pattern');
      }
    });

    test('only contains valid alphabet characters (no I, L, O, 0, 1)', () {
      final banned = {'I', 'L', 'O', '0', '1'};
      for (int i = 0; i < 50; i++) {
        final code = generateInviteCode().replaceAll('-', '');
        for (final ch in code.split('')) {
          expect(banned.contains(ch), isFalse,
              reason: 'banned character "$ch" found in code');
          expect(_validChars.contains(ch), isTrue,
              reason: 'unexpected character "$ch" found in code');
        }
      }
    });

    test('generates unique codes', () {
      final codes = List.generate(100, (_) => generateInviteCode()).toSet();
      expect(codes.length, greaterThan(90));
    });
  });

  group('normalizeInviteCode', () {
    test('lowercased 8-char input becomes XXXX-XXXX', () {
      expect(normalizeInviteCode('abcdefgh'), 'ABCD-EFGH');
    });

    test('already formatted XXXX-XXXX passes through', () {
      expect(normalizeInviteCode('ABCD-EFGH'), 'ABCD-EFGH');
    });

    test('strips the dash before re-inserting it', () {
      final result = normalizeInviteCode('ABCD-EFGH');
      expect(result.indexOf('-'), 4);
      expect(result.length, 9);
    });

    test('input with extra punctuation is stripped', () {
      expect(normalizeInviteCode('ABCD.EFGH'), 'ABCD-EFGH');
    });

    test('mixed case is uppercased', () {
      expect(normalizeInviteCode('aBcDeFgH'), 'ABCD-EFGH');
    });

    test('input shorter than 8 chars is returned uppercased without dash insertion', () {
      final result = normalizeInviteCode('abc');
      expect(result, 'ABC');
    });

    test('spaces in input are stripped', () {
      expect(normalizeInviteCode('ABCD EFGH'), 'ABCD-EFGH');
    });
  });
}
