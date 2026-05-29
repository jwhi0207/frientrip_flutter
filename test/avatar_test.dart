import 'package:flutter_test/flutter_test.dart';
import 'package:frientrip/utils/avatar.dart';

void main() {
  group('avatarUrl', () {
    test('contains the seed in the URL', () {
      expect(avatarUrl(5), contains('seed=5'));
    });

    test('uses the pixel-art style', () {
      expect(avatarUrl(1), contains('pixel-art'));
    });

    test('requests 128px size', () {
      expect(avatarUrl(1), contains('size=128'));
    });
  });

  group('avatarBackgroundColor', () {
    test('returns a valid color for index 0', () {
      expect(() => avatarBackgroundColor(0), returnsNormally);
    });

    test('returns first color for negative index', () {
      expect(avatarBackgroundColor(-1), avatarBackgroundColor(0));
    });

    test('returns first color for out-of-range index', () {
      expect(avatarBackgroundColor(9999), avatarBackgroundColor(0));
    });

    test('returns distinct colors for different valid indices', () {
      final first = avatarBackgroundColor(0);
      bool anyDiffers = false;
      for (int i = 1; i < avatarColors.length; i++) {
        if (avatarBackgroundColor(i) != first) {
          anyDiffers = true;
          break;
        }
      }
      expect(anyDiffers, isTrue, reason: 'all avatar colors are identical');
    });

    test('each valid index returns normally', () {
      for (int i = 0; i < avatarColors.length; i++) {
        expect(() => avatarBackgroundColor(i), returnsNormally);
      }
    });
  });

  group('avatarSeeds', () {
    test('contains 12 seeds', () {
      expect(avatarSeeds.length, 12);
    });

    test('seeds are 1 through 12', () {
      expect(avatarSeeds, List.generate(12, (i) => i + 1));
    });
  });
}
