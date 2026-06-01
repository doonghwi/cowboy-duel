import 'dart:math';

import 'package:firebase_database/firebase_database.dart';

import '../game/game_logic.dart';

/// Slot a player occupies in a room. Host is player 1, guest is player 2.
enum Slot { host, guest }

extension SlotKey on Slot {
  String get key => this == Slot.host ? 'host' : 'guest';
  Slot get other => this == Slot.host ? Slot.guest : Slot.host;
}

enum OnlinePhase { waitingForOpponent, choosing, submitted, standoff, over }

/// A fully-derived, render-ready view of a room from one player's perspective.
/// Computed by deterministically replaying the move history so both clients
/// always agree without writing redundant state.
class RoomView {
  final bool opponentJoined;
  final OnlinePhase phase;
  final int turn;
  final int myAmmo;
  final int oppAmmo;
  final CowboyAction? myLastAction;
  final CowboyAction? oppLastAction;
  final bool iSubmitted;
  final bool iTappedStandoff;
  final bool? iWon; // non-null only when phase == over
  final String banner;

  const RoomView({
    required this.opponentJoined,
    required this.phase,
    required this.turn,
    required this.myAmmo,
    required this.oppAmmo,
    required this.myLastAction,
    required this.oppLastAction,
    required this.iSubmitted,
    required this.iTappedStandoff,
    required this.iWon,
    required this.banner,
  });
}

class OnlineService {
  OnlineService() : clientId = _genClientId();

  final String clientId;
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String _genClientId() {
    final r = Random();
    return List.generate(10, (_) => _idChars[r.nextInt(_idChars.length)]).join();
  }

  static String generateRoomCode() {
    final r = Random();
    return List.generate(4, (_) => _codeChars[r.nextInt(_codeChars.length)]).join();
  }

  DatabaseReference room(String code) => _root.child('rooms/$code');

  /// Create a fresh room and occupy the host slot.
  Future<void> createRoom(String code) async {
    await room(code).set({
      'host': clientId,
      'guest': null,
      'turns': null,
      'rematch': null,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Returns true if the room exists and a guest slot was successfully claimed.
  Future<bool> joinRoom(String code) async {
    final snap = await room(code).get();
    if (!snap.exists) return false;
    final result = await room(code).child('guest').runTransaction((current) {
      if (current == null) return Transaction.success(clientId);
      // Allow re-entry if we already hold the slot.
      if (current == clientId) return Transaction.success(current);
      return Transaction.abort();
    });
    return result.committed;
  }

  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  Future<void> submitMove(String code, int turn, Slot slot, CowboyAction a) {
    return room(code).child('turns/$turn/${slot.key}').set(a.index);
  }

  Future<void> tapStandoff(String code, int turn, Slot slot) {
    return room(code).child('turns/$turn/st_${slot.key}').set(ServerValue.timestamp);
  }

  Future<void> requestRematch(String code, Slot slot) {
    return room(code).child('rematch/${slot.key}').set(true);
  }

  /// Host resets the board for a rematch once both players opted in.
  Future<void> resetForRematch(String code) {
    return room(code).update({'turns': null, 'rematch': null});
  }

  Future<void> leave(String code, Slot slot) async {
    // Drop our slot; if the room empties it will be cleaned up lazily.
    await room(code).child(slot.key).remove();
  }

  // ---- Pure replay -------------------------------------------------------

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  /// Replays the move log to produce a consistent view for [mySlot].
  static RoomView computeView(Map data, Slot mySlot) {
    final host = data['host'];
    final guest = data['guest'];
    final opponentJoined = mySlot == Slot.host ? guest != null : host != null;
    final turns = (data['turns'] as Map?) ?? const {};

    int ammoHost = 0, ammoGuest = 0;
    CowboyAction? lastHost, lastGuest;

    int t = 0;
    while (true) {
      final turn = turns['$t'] as Map?;
      final hRaw = turn == null ? null : _asInt(turn['host']);
      final gRaw = turn == null ? null : _asInt(turn['guest']);

      if (hRaw == null || gRaw == null) {
        // Pending turn: waiting for one or both moves.
        final mineKey = mySlot.key;
        final iSubmitted = turn != null && turn[mineKey] != null;
        return _view(
          opponentJoined: opponentJoined,
          phase: iSubmitted
              ? OnlinePhase.waitingForOpponent
              : OnlinePhase.choosing,
          turn: t,
          mySlot: mySlot,
          ammoHost: ammoHost,
          ammoGuest: ammoGuest,
          lastHost: lastHost,
          lastGuest: lastGuest,
          iSubmitted: iSubmitted,
          iTapped: false,
          iWon: null,
          banner: iSubmitted ? '상대를 기다리는 중...' : '장전 · 방어 · 빵야!',
        );
      }

      final aHost = CowboyAction.values[hRaw];
      final aGuest = CowboyAction.values[gRaw];
      final r = resolveTurn(aHost, ammoHost, aGuest, ammoGuest);
      ammoHost = r.ammo1After;
      ammoGuest = r.ammo2After;
      lastHost = aHost;
      lastGuest = aGuest;

      if (r.outcome == DuelOutcome.p1Hit) {
        return _over(opponentJoined, mySlot, ammoHost, ammoGuest, lastHost,
            lastGuest, Slot.host, '명중!');
      }
      if (r.outcome == DuelOutcome.p2Hit) {
        return _over(opponentJoined, mySlot, ammoHost, ammoGuest, lastHost,
            lastGuest, Slot.guest, '명중!');
      }
      if (r.outcome == DuelOutcome.standoff) {
        final stHost = turn!['st_host'];
        final stGuest = turn['st_guest'];
        if (stHost != null && stGuest != null) {
          final winner =
              (_asInt(stHost) ?? 0) <= (_asInt(stGuest) ?? 0) ? Slot.host : Slot.guest;
          return _over(opponentJoined, mySlot, ammoHost, ammoGuest, lastHost,
              lastGuest, winner, '카우보이!');
        }
        final mineTapped = turn['st_${mySlot.key}'] != null;
        return _view(
          opponentJoined: opponentJoined,
          phase: OnlinePhase.standoff,
          turn: t,
          mySlot: mySlot,
          ammoHost: ammoHost,
          ammoGuest: ammoGuest,
          lastHost: lastHost,
          lastGuest: lastGuest,
          iSubmitted: true,
          iTapped: mineTapped,
          iWon: null,
          banner: '동시에 빵야! 카우보이!',
        );
      }
      // ongoing → next turn
      t++;
    }
  }

  static RoomView _over(
    bool opponentJoined,
    Slot mySlot,
    int ammoHost,
    int ammoGuest,
    CowboyAction? lastHost,
    CowboyAction? lastGuest,
    Slot winner,
    String banner,
  ) {
    return _view(
      opponentJoined: opponentJoined,
      phase: OnlinePhase.over,
      turn: -1,
      mySlot: mySlot,
      ammoHost: ammoHost,
      ammoGuest: ammoGuest,
      lastHost: lastHost,
      lastGuest: lastGuest,
      iSubmitted: true,
      iTapped: true,
      iWon: winner == mySlot,
      banner: banner,
    );
  }

  static RoomView _view({
    required bool opponentJoined,
    required OnlinePhase phase,
    required int turn,
    required Slot mySlot,
    required int ammoHost,
    required int ammoGuest,
    required CowboyAction? lastHost,
    required CowboyAction? lastGuest,
    required bool iSubmitted,
    required bool iTapped,
    required bool? iWon,
    required String banner,
  }) {
    final mine = mySlot == Slot.host;
    return RoomView(
      opponentJoined: opponentJoined,
      phase: phase,
      turn: turn,
      myAmmo: mine ? ammoHost : ammoGuest,
      oppAmmo: mine ? ammoGuest : ammoHost,
      myLastAction: mine ? lastHost : lastGuest,
      oppLastAction: mine ? lastGuest : lastHost,
      iSubmitted: iSubmitted,
      iTappedStandoff: iTapped,
      iWon: iWon,
      banner: banner,
    );
  }
}
