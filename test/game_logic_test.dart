import 'package:cowboy_duel/game/game_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveTurn ammo bookkeeping', () {
    test('reload adds one bullet', () {
      final r = resolveTurn(
          CowboyAction.reload, 0, CowboyAction.reload, 2);
      expect(r.ammo1After, 1);
      expect(r.ammo2After, 3);
    });

    test('reload is capped at kMaxAmmo', () {
      final r = resolveTurn(
          CowboyAction.reload, kMaxAmmo, CowboyAction.defend, 0);
      expect(r.ammo1After, kMaxAmmo);
    });

    test('valid shot spends one bullet', () {
      final r = resolveTurn(
          CowboyAction.shoot, 2, CowboyAction.defend, 0);
      expect(r.ammo1After, 1);
      expect(r.p1Fired, isTrue);
      expect(r.p1Misfire, isFalse);
    });

    test('shooting with empty chamber is a misfire and spends nothing', () {
      final r = resolveTurn(
          CowboyAction.shoot, 0, CowboyAction.reload, 0);
      expect(r.ammo1After, 0);
      expect(r.p1Fired, isFalse);
      expect(r.p1Misfire, isTrue);
    });
  });

  group('resolveTurn outcomes', () {
    test('shot lands on a reloading opponent', () {
      final r = resolveTurn(
          CowboyAction.shoot, 1, CowboyAction.reload, 0);
      expect(r.outcome, DuelOutcome.p1Hit);
    });

    test('defend blocks an incoming shot', () {
      final r = resolveTurn(
          CowboyAction.shoot, 1, CowboyAction.defend, 0);
      expect(r.outcome, DuelOutcome.ongoing);
    });

    test('both firing valid shots is a standoff', () {
      final r = resolveTurn(
          CowboyAction.shoot, 1, CowboyAction.shoot, 1);
      expect(r.outcome, DuelOutcome.standoff);
    });

    test('misfire does not count as a shot, opponent shot still lands', () {
      final r = resolveTurn(
          CowboyAction.shoot, 0, CowboyAction.shoot, 1);
      expect(r.outcome, DuelOutcome.p2Hit);
    });

    test('two reloads continue the duel', () {
      final r = resolveTurn(
          CowboyAction.reload, 0, CowboyAction.reload, 0);
      expect(r.outcome, DuelOutcome.ongoing);
    });

    test('p2 lands on a reloading p1', () {
      final r = resolveTurn(
          CowboyAction.reload, 0, CowboyAction.shoot, 1);
      expect(r.outcome, DuelOutcome.p2Hit);
    });
  });
}
