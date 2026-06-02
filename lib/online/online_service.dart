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
class RoomView {
  final bool opponentJoined;
  final OnlinePhase phase;
  final int turn;
  final int myAmmo;
  final int oppAmmo;
  final CowboyAction? myLastAction;
  final CowboyAction? oppLastAction;
  final CowboyAction? myPendingAction;
  final bool iSubmitted;
  final bool iTappedStandoff;
  final bool? iWon; // non-null only when phase == over
  final String banner;

  /// Opponent has locked their move for this turn while I have not chosen yet.
  final bool opponentSubmitted;

  /// Running duel record within this room (session only).
  final int myScore;
  final int oppScore;

  const RoomView({
    required this.opponentJoined,
    required this.phase,
    required this.turn,
    required this.myAmmo,
    required this.oppAmmo,
    required this.myLastAction,
    required this.oppLastAction,
    required this.myPendingAction,
    required this.iSubmitted,
    required this.iTappedStandoff,
    required this.iWon,
    required this.banner,
    this.opponentSubmitted = false,
    this.myScore = 0,
    this.oppScore = 0,
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

  Future<void> createRoom(String code, String name) async {
    await room(code).set({
      'host': clientId,
      'guest': null,
      'turns': null,
      'rematch': null,
      'score': null,
      'names': {'host': name},
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<bool> joinRoom(String code, String name) async {
    final snap = await room(code).get();
    if (!snap.exists) return false;
    final result = await room(code).child('guest').runTransaction((current) {
      if (current == null) return Transaction.success(clientId);
      if (current == clientId) return Transaction.success(current);
      return Transaction.abort();
    });
    if (result.committed) {
      await room(code).child('names/guest').set(name);
    }
    return result.committed;
  }

  Stream<DatabaseEvent> watch(String code) => room(code).onValue;

  // Turn keys are prefixed with 't' (t0, t1, ...): Firebase RTDB turns a node
  // whose keys are sequential integers into a List, which breaks Map parsing.
  Future<void> submitMove(String code, int turn, Slot slot, CowboyAction a) {
    return room(code).child('turns/t$turn/${slot.key}').set(a.index);
  }

  Future<void> tapStandoff(String code, int turn, Slot slot) {
    return room(code)
        .child('turns/t$turn/st_${slot.key}')
        .set(ServerValue.timestamp);
  }

  Future<void> requestRematch(String code, Slot slot) {
    return room(code).child('rematch/${slot.key}').set(true);
  }

  /// Host records the finished duel's winner into the room score, then clears
  /// the board for the next duel. Called once when both players want a rematch.
  Future<void> recordWinAndReset(String code, String winnerKey) async {
    await room(code).child('score/$winnerKey').runTransaction((cur) {
      final n = cur is int ? cur : 0;
      return Transaction.success(n + 1);
    });
    await room(code).update({'turns': null, 'rematch': null});
  }

  Future<void> leave(String code, Slot slot) async {
    await room(code).child(slot.key).remove();
  }

  // ---- Pure replay -------------------------------------------------------

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static Map? _asMap(Object? v) {
    if (v is Map) return v;
    if (v is List) {
      final m = <String, Object?>{};
      for (var i = 0; i < v.length; i++) {
        if (v[i] != null) m['t$i'] = v[i];
      }
      return m;
    }
    return null;
  }

  static String _ongoingMsg(
      CowboyAction my, CowboyAction opp, TurnResult r, bool iAmHost) {
    final myFired = iAmHost ? r.p1Fired : r.p2Fired;
    final oppFired = iAmHost ? r.p2Fired : r.p1Fired;
    if (myFired && opp == CowboyAction.defend) return '상대가 막았다!';
    if (oppFired && my == CowboyAction.defend) return '내가 막았다!';
    if (my == CowboyAction.reload && opp == CowboyAction.reload) {
      return '둘 다 장전!';
    }
    if (my == CowboyAction.defend && opp == CowboyAction.defend) {
      return '둘 다 방어!';
    }
    return '서로 탐색 중!';
  }

  static RoomView computeView(Map data, Slot mySlot) {
    final host = data['host'];
    final guest = data['guest'];
    final opponentJoined = mySlot == Slot.host ? guest != null : host != null;
    final turns = _asMap(data['turns']) ?? const {};
    final score = _asMap(data['score']) ?? const {};
    final scoreHost = _asInt(score['host']) ?? 0;
    final scoreGuest = _asInt(score['guest']) ?? 0;
    final iAmHost = mySlot == Slot.host;

    int ammoHost = 0, ammoGuest = 0;
    CowboyAction? lastHost, lastGuest;
    String? lastBanner;

    int t = 0;
    while (true) {
      final turn = _asMap(turns['t$t']);
      final hRaw = turn == null ? null : _asInt(turn['host']);
      final gRaw = turn == null ? null : _asInt(turn['guest']);

      if (hRaw == null || gRaw == null) {
        final mineKey = mySlot.key;
        final myRaw = turn == null ? null : _asInt(turn[mineKey]);
        final oppRaw = turn == null ? null : _asInt(turn[mySlot.other.key]);
        final iSubmitted = myRaw != null;
        final oppSubmitted = oppRaw != null;
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
          myPending: myRaw == null ? null : CowboyAction.values[myRaw],
          iSubmitted: iSubmitted,
          iTapped: false,
          iWon: null,
          opponentSubmitted: oppSubmitted,
          scoreHost: scoreHost,
          scoreGuest: scoreGuest,
          banner: iSubmitted
              ? '상대를 기다리는 중...'
              : (oppSubmitted
                  ? '상대가 선택했어요! 당신 차례'
                  : (lastBanner ?? '장전 · 방어 · 빵야!')),
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
            lastGuest, Slot.host, '명중!', scoreHost, scoreGuest);
      }
      if (r.outcome == DuelOutcome.p2Hit) {
        return _over(opponentJoined, mySlot, ammoHost, ammoGuest, lastHost,
            lastGuest, Slot.guest, '명중!', scoreHost, scoreGuest);
      }
      if (r.outcome == DuelOutcome.standoff) {
        final stHost = turn!['st_host'];
        final stGuest = turn['st_guest'];
        if (stHost != null && stGuest != null) {
          final winner = (_asInt(stHost) ?? 0) <= (_asInt(stGuest) ?? 0)
              ? Slot.host
              : Slot.guest;
          return _over(opponentJoined, mySlot, ammoHost, ammoGuest, lastHost,
              lastGuest, winner, '카우보이!', scoreHost, scoreGuest);
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
          myPending: null,
          iSubmitted: true,
          iTapped: mineTapped,
          iWon: null,
          scoreHost: scoreHost,
          scoreGuest: scoreGuest,
          banner: '동시에 빵야! 카우보이!',
        );
      }
      lastBanner = _ongoingMsg(
          iAmHost ? aHost : aGuest, iAmHost ? aGuest : aHost, r, iAmHost);
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
    int scoreHost,
    int scoreGuest,
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
      myPending: null,
      iSubmitted: true,
      iTapped: true,
      iWon: winner == mySlot,
      banner: banner,
      scoreHost: scoreHost,
      scoreGuest: scoreGuest,
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
    required CowboyAction? myPending,
    required bool iSubmitted,
    required bool iTapped,
    required bool? iWon,
    required String banner,
    bool opponentSubmitted = false,
    int scoreHost = 0,
    int scoreGuest = 0,
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
      myPendingAction: myPending,
      iSubmitted: iSubmitted,
      iTappedStandoff: iTapped,
      iWon: iWon,
      banner: banner,
      opponentSubmitted: opponentSubmitted,
      myScore: mine ? scoreHost : scoreGuest,
      oppScore: mine ? scoreGuest : scoreHost,
    );
  }
}
