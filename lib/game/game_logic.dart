/// Core, UI-independent game rules for Cowboy Duel.
///
/// The game from the original blog post boils down to three actions:
///   - 장전 (reload): load one bullet. Required before you can shoot.
///   - 방어 (defend): block an incoming shot this turn.
///   - 빵야 (shoot): fire a bullet (only works if you have ammo).
///
/// Both players choose simultaneously every turn. A clean hit ends the duel.
/// If BOTH fire a valid shot in the same turn it's a stand-off, resolved by
/// who yells "카우보이!" first (handled in the UI as a reaction race).
library;

/// The three things a cowboy can do on a turn.
enum CowboyAction { reload, defend, shoot }

extension CowboyActionLabel on CowboyAction {
  String get ko {
    switch (this) {
      case CowboyAction.reload:
        return '장전';
      case CowboyAction.defend:
        return '방어';
      case CowboyAction.shoot:
        return '빵야';
    }
  }

  String get emoji {
    switch (this) {
      case CowboyAction.reload:
        return '🔄';
      case CowboyAction.defend:
        return '🛡️';
      case CowboyAction.shoot:
        return '💥';
    }
  }
}

/// What happened after both players revealed their actions.
enum DuelOutcome {
  /// Nobody got hit — play another turn.
  ongoing,

  /// Player 1 landed a clean hit on player 2.
  p1Hit,

  /// Player 2 landed a clean hit on player 1.
  p2Hit,

  /// Both fired valid shots at the same time → "카우보이!" reaction race.
  standoff,
}

/// Maximum bullets a cowboy can stockpile.
const int kMaxAmmo = 6;

/// Immutable result of resolving one simultaneous turn.
class TurnResult {
  final int ammo1After;
  final int ammo2After;

  /// True if the player fired a *valid* shot (had ammo).
  final bool p1Fired;
  final bool p2Fired;

  /// True if the player pulled the trigger with an empty chamber.
  final bool p1Misfire;
  final bool p2Misfire;

  final DuelOutcome outcome;

  const TurnResult({
    required this.ammo1After,
    required this.ammo2After,
    required this.p1Fired,
    required this.p2Fired,
    required this.p1Misfire,
    required this.p2Misfire,
    required this.outcome,
  });
}

/// Pure resolution of one turn given both choices and current ammo.
///
/// Rules:
///  * reload  → +1 ammo (capped at [kMaxAmmo]).
///  * shoot   → only fires if ammo > 0, then -1 ammo. Otherwise it's a misfire
///              (no effect, no ammo spent) and leaves you defenceless.
///  * defend  → blocks the opponent's shot this turn.
///  * A valid shot hits unless the target defended or also fired a valid shot.
///  * Both firing valid shots → [DuelOutcome.standoff] (decided by reaction).
TurnResult resolveTurn(
  CowboyAction a1,
  int ammo1,
  CowboyAction a2,
  int ammo2,
) {
  final p1Fired = a1 == CowboyAction.shoot && ammo1 > 0;
  final p2Fired = a2 == CowboyAction.shoot && ammo2 > 0;
  final p1Misfire = a1 == CowboyAction.shoot && ammo1 == 0;
  final p2Misfire = a2 == CowboyAction.shoot && ammo2 == 0;

  int ammo1After = ammo1;
  int ammo2After = ammo2;
  if (a1 == CowboyAction.reload) {
    ammo1After = (ammo1 + 1).clamp(0, kMaxAmmo);
  } else if (p1Fired) {
    ammo1After = ammo1 - 1;
  }
  if (a2 == CowboyAction.reload) {
    ammo2After = (ammo2 + 1).clamp(0, kMaxAmmo);
  } else if (p2Fired) {
    ammo2After = ammo2 - 1;
  }

  final p1Defended = a1 == CowboyAction.defend;
  final p2Defended = a2 == CowboyAction.defend;

  DuelOutcome outcome;
  if (p1Fired && p2Fired) {
    outcome = DuelOutcome.standoff;
  } else if (p1Fired && !p2Defended) {
    outcome = DuelOutcome.p1Hit;
  } else if (p2Fired && !p1Defended) {
    outcome = DuelOutcome.p2Hit;
  } else {
    outcome = DuelOutcome.ongoing;
  }

  return TurnResult(
    ammo1After: ammo1After,
    ammo2After: ammo2After,
    p1Fired: p1Fired,
    p2Fired: p2Fired,
    p1Misfire: p1Misfire,
    p2Misfire: p2Misfire,
    outcome: outcome,
  );
}
