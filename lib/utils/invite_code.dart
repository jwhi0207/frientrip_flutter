import 'dart:math';

const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
final _random = Random.secure();

String generateInviteCode() {
  final code =
      List.generate(8, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
  return '${code.substring(0, 4)}-${code.substring(4, 8)}';
}

String normalizeInviteCode(String input) {
  final clean = input
      .toUpperCase()
      .split('')
      .where((c) => RegExp(r'[A-Z0-9]').hasMatch(c))
      .join();
  if (clean.length == 8) {
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}';
  }
  return input.toUpperCase();
}
