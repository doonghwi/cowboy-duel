import 'dart:math';

import 'game_logic.dart';

/// Difficulty affects how aggressively the CPU plays and how fast it reacts
/// in a "카우보이!" stand-off.
enum Difficulty { easy, normal, hard }

extension DifficultyLabel on Difficulty {
  String get ko {
    switch (this) {
      case Difficulty.easy:
        return '쉬움';
      case Difficulty.normal:
        return '보통';
      case Difficulty.hard:
        return '어려움';
    }
  }

  /// CPU reaction time (ms) for the stand-off race. Lower = harder to beat.
  int get reactionMs {
    switch (this) {
      case Difficulty.easy:
        return 720;
      case Difficulty.normal:
        return 480;
      case Difficulty.hard:
        return 300;
    }
  }
}

/// Picks the CPU's action for a turn using a light heuristic. The CPU is aware
/// of the player's ammo (so it stays a fair challenge) but still plays with
/// randomness so it never feels scripted.
CowboyAction chooseCpuAction({
  required int cpuAmmo,
  required int playerAmmo,
  required Difficulty difficulty,
  required Random rng,
}) {
  // Strictly-correct case: if neither side has ammo, nobody can shoot this
  // turn, so the only useful move is to reload. Every difficulty plays it.
  if (cpuAmmo == 0 && playerAmmo == 0) {
    return CowboyAction.reload;
  }

  double reload = 0, defend = 0, shoot = 0;
  if (cpuAmmo == 0) {
    // Empty against an armed player: survive, but still need to arm up.
    switch (difficulty) {
      case Difficulty.easy:
        reload = 0.55;
        defend = 0.45;
        break;
      case Difficulty.normal:
        reload = 0.40;
        defend = 0.60;
        break;
      case Difficulty.hard:
        reload = 0.30;
        defend = 0.70;
        break;
    }
  } else if (playerAmmo == 0) {
    // Player can't fire this turn → a shot punishes their reload.
    switch (difficulty) {
      case Difficulty.easy:
        shoot = 0.45;
        reload = 0.35;
        defend = 0.20;
        break;
      case Difficulty.normal:
        shoot = 0.60;
        reload = 0.25;
        defend = 0.15;
        break;
      case Difficulty.hard:
        shoot = 0.72;
        reload = 0.18;
        defend = 0.10;
        break;
    }
  } else {
    // Both armed: the tense mind-game. Mix shoot/defend, rarely reload.
    switch (difficulty) {
      case Difficulty.easy:
        shoot = 0.34;
        defend = 0.33;
        reload = 0.33;
        break;
      case Difficulty.normal:
        shoot = 0.42;
        defend = 0.42;
        reload = 0.16;
        break;
      case Difficulty.hard:
        shoot = 0.47;
        defend = 0.45;
        reload = 0.08;
        break;
    }
  }

  final total = reload + defend + shoot;
  var roll = rng.nextDouble() * total;
  if (roll < reload) return CowboyAction.reload;
  roll -= reload;
  if (roll < defend) return CowboyAction.defend;
  return CowboyAction.shoot;
}
