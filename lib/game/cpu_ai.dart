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
  // Weight map for the three actions; highest roll wins.
  double reload, defend, shoot;

  if (cpuAmmo == 0) {
    // Can't shoot. Reload, but guard against a player who can fire.
    if (playerAmmo > 0) {
      defend = 0.55;
      reload = 0.45;
      shoot = 0.0;
    } else {
      reload = 0.85;
      defend = 0.15;
      shoot = 0.0;
    }
  } else if (playerAmmo == 0) {
    // Player can't fire this turn → a shot is low risk.
    shoot = 0.65;
    reload = 0.20;
    defend = 0.15;
  } else {
    // Both armed: the tense case. Mix it up.
    shoot = 0.40;
    defend = 0.35;
    reload = 0.25;
  }

  // Difficulty tilts the armed-vs-armed case toward smarter play.
  if (difficulty == Difficulty.hard && cpuAmmo > 0 && playerAmmo > 0) {
    shoot += 0.10;
    reload -= 0.10;
  } else if (difficulty == Difficulty.easy) {
    // Easy CPU sometimes wastes a turn.
    reload += 0.10;
    shoot -= 0.10;
  }

  final total = reload + defend + shoot;
  var roll = rng.nextDouble() * total;
  if (roll < reload) return CowboyAction.reload;
  roll -= reload;
  if (roll < defend) return CowboyAction.defend;
  return CowboyAction.shoot;
}
