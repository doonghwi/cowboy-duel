import 'dart:async';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_logic.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/emo.dart';

class OnlineGameScreen extends StatefulWidget {
  final OnlineService service;
  final String code;
  final Slot mySlot;
  const OnlineGameScreen({
    super.key,
    required this.service,
    required this.code,
    required this.mySlot,
  });

  @override
  State<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends State<OnlineGameScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<DatabaseEvent>? _sub;
  StreamSubscription<DatabaseEvent>? _offsetSub;
  Map? _data;
  RoomView? _view;
  bool _resetting = false;
  final _rng = Random();

  // Standoff timing.
  int _serverOffset = 0; // ms to add to local clock to estimate server time
  Timer? _goTimer;
  int _goTimerTurn = -1;
  int _goWriteTurn = -1;

  late final AnimationController _pulse;

  int _serverNow() => DateTime.now().millisecondsSinceEpoch + _serverOffset;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..repeat(reverse: true);
    // Estimate server clock so both phones flash "카우보이!" at the same instant.
    _offsetSub = FirebaseDatabase.instance
        .ref('.info/serverTimeOffset')
        .onValue
        .listen((e) {
      final v = e.snapshot.value;
      if (v is num) _serverOffset = v.toInt();
    });
    _sub = widget.service.watch(widget.code).listen(_onData);
  }

  void _onData(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) {
      setState(() {
        _data = null;
        _view = null;
      });
      return;
    }
    final data = value;
    RoomView view;
    try {
      view = OnlineService.computeView(data, widget.mySlot);
    } catch (_) {
      // Never freeze the screen on a transient parse issue — keep last view.
      return;
    }

    // Host records the finished duel's winner into the room score, then resets
    // for the next duel — guarded so it runs exactly once per duel.
    final rematch = data['rematch'] is Map ? data['rematch'] as Map : null;
    if (widget.mySlot == Slot.host &&
        !_resetting &&
        rematch != null &&
        rematch['host'] == true &&
        rematch['guest'] == true) {
      _resetting = true;
      final winnerKey = view.iWon == true ? 'host' : 'guest';
      widget.service
          .recordWinAndReset(widget.code, winnerKey)
          .whenComplete(() => _resetting = false);
    }

    _maybeStartStandoff(view);

    setState(() {
      _data = data;
      _view = view;
    });
  }

  /// Host sets the synchronized GO moment once; both clients schedule a rebuild
  /// exactly at that moment so "카우보이!" flashes together.
  void _maybeStartStandoff(RoomView view) {
    if (view.phase != OnlinePhase.standoff) {
      // Reset per-standoff guards so the NEXT duel (turn numbers restart at 0
      // after a rematch) writes a fresh GO signal instead of being skipped —
      // this was the "freeze after several rounds in the same room" bug.
      _goTimerTurn = -1;
      _goWriteTurn = -1;
      return;
    }
    if (widget.mySlot == Slot.host &&
        view.standoffGoAt == null &&
        _goWriteTurn != view.turn) {
      _goWriteTurn = view.turn;
      final prep = 1100 + _rng.nextInt(1000); // 1.1~2.1s of suspense
      widget.service
          .setStandoffGo(widget.code, view.turn, _serverNow() + prep);
    }
    final goAt = view.standoffGoAt;
    if (goAt != null && _goTimerTurn != view.turn) {
      _goTimerTurn = view.turn;
      final delay = goAt - _serverNow();
      _goTimer?.cancel();
      if (delay > 0) {
        _goTimer = Timer(Duration(milliseconds: delay), () {
          if (mounted) setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _offsetSub?.cancel();
    _goTimer?.cancel();
    _pulse.dispose();
    widget.service.leave(widget.code, widget.mySlot);
    super.dispose();
  }

  void _choose(CowboyAction a) {
    final v = _view;
    if (v == null || v.phase != OnlinePhase.choosing) return;
    widget.service.submitMove(widget.code, v.turn, widget.mySlot, a);
  }

  void _tapStandoff() {
    final v = _view;
    if (v == null || v.phase != OnlinePhase.standoff || v.iTappedStandoff) {
      return;
    }
    final goAt = v.standoffGoAt;
    if (goAt == null) return; // GO not synchronized yet
    final now = _serverNow();
    // Reaction measured locally from the GO signal (network-latency-free).
    // Tapping before GO is a false start (-1) and loses.
    final rt = now < goAt ? -1 : (now - goAt);
    widget.service.submitReaction(widget.code, v.turn, widget.mySlot, rt);
  }

  void _rematch() {
    widget.service.requestRematch(widget.code, widget.mySlot);
  }

  /// Nickname for a slot, read live from the room (falls back to 나/상대).
  String _name(Slot slot) {
    final names = _data?['names'];
    final n = names is Map ? names[slot.key] : null;
    if (n is String && n.trim().isNotEmpty) return n;
    return slot == widget.mySlot ? '나' : '상대';
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    return Scaffold(
      appBar: AppBar(
        title: Text('방 ${widget.code}', style: posterTitle(20)),
        actions: [
          if (v != null && v.opponentJoined)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CD.leather,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('나 ${v.myScore} : ${v.oppScore} 상대',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ],
      ),
      body: DesertBackground(
        bright: true,
        child: SafeArea(
          child: v == null
              ? _connecting()
              : (!v.opponentJoined ? _waitingRoom() : _game(v)),
        ),
      ),
    );
  }

  Widget _connecting() {
    return const Center(child: CircularProgressIndicator(color: CD.rust));
  }

  Widget _waitingRoom() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Emo('cowboy', size: 80),
            const SizedBox(height: 14),
            Text('친구를 기다리는 중...', style: posterTitle(24)),
            const SizedBox(height: 24),
            Text('방 코드', style: TextStyle(color: CD.muted, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: CD.leather,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(widget.code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('방 코드를 복사했어요!')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('코드 복사'),
            ),
            const SizedBox(height: 8),
            Text('이 코드를 친구에게 알려주고\n"참가하기"로 들어오게 하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: CD.muted)),
          ],
        ),
      ),
    );
  }

  Widget _game(RoomView v) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _fighter('person', _name(widget.mySlot.other), v.oppAmmo,
                  v.oppLastAction, CD.leather,
                  submitted: v.opponentSubmitted),
              Expanded(
                child: Center(
                  child: Text(
                    v.banner,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: CD.rust),
                  ),
                ),
              ),
              _fighter('cowboy', _name(widget.mySlot), v.myAmmo,
                  v.myLastAction, CD.rust),
              const SizedBox(height: 16),
              _controls(v),
              const SizedBox(height: 18),
            ],
          ),
        ),
        if (v.phase == OnlinePhase.standoff) _standoffOverlay(v),
        if (v.phase == OnlinePhase.over) _overOverlay(v),
      ],
    );
  }

  Widget _controls(RoomView v) {
    final choosing = v.phase == OnlinePhase.choosing;
    final canShoot = v.myAmmo > 0;
    if (v.phase == OnlinePhase.waitingForOpponent) {
      final mine = v.myPendingAction;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mine != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CD.actionColor(mine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Emo(actionEmoji(mine), size: 18),
                    const SizedBox(width: 6),
                    Text('내 선택: ${mine.ko}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: CD.rust)),
            const SizedBox(width: 8),
            Text('상대 기다리는 중...',
                style: TextStyle(color: CD.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Row(
      children: [
        _btn(CowboyAction.reload, choosing),
        const SizedBox(width: 10),
        _btn(CowboyAction.defend, choosing),
        const SizedBox(width: 10),
        _btn(CowboyAction.shoot, choosing && canShoot),
      ],
    );
  }

  Widget _btn(CowboyAction a, bool enabled) {
    final color = CD.actionColor(a);
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          elevation: enabled ? 4 : 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => _choose(a) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Emo(actionEmoji(a), size: 28),
                  const SizedBox(height: 6),
                  Text(a.ko,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fighter(String emoji, String name, int ammo, CowboyAction? last,
      Color color,
      {bool submitted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8C08A)),
      ),
      child: Row(
        children: [
          Emo(emoji, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: CD.muted),
                    const SizedBox(width: 4),
                    if (ammo == 0)
                      Text('빈 총',
                          style: TextStyle(
                              color: CD.muted, fontWeight: FontWeight.w600))
                    else
                      Row(
                        children: List.generate(
                            ammo,
                            (_) => const Padding(
                                  padding: EdgeInsets.only(right: 3),
                                  child: Emo('ammo', size: 14),
                                )),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (submitted)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CD.sage,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('선택 완료',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            )
          else if (last != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CD.actionColor(last),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Emo(actionEmoji(last), size: 18),
                  const SizedBox(width: 6),
                  Text(last.ko,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _standoffOverlay(RoomView v) {
    final goAt = v.standoffGoAt;
    final go = goAt != null && _serverNow() >= goAt;
    final reacted = v.iTappedStandoff;
    final showGo = go && !reacted;

    Widget center;
    String subtitle;
    if (reacted) {
      center = const Text('탭 완료!\n상대 기다리는 중...',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900));
      subtitle = '반응속도 비교 중...';
    } else if (showGo) {
      center = ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.14).animate(
            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: const Text('카우보이!\n지금 탭!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1.1)),
      );
      subtitle = '먼저 누르는 사람이 승리!';
    } else {
      center = const Text('준비...',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900));
      subtitle = '"카우보이!"가 뜨면 즉시 탭! (미리 누르면 부정출발 패배)';
    }

    return Positioned.fill(
      child: GestureDetector(
        onTap: _tapStandoff,
        child: Container(
          color: showGo ? CD.danger : CD.leather,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Emo(showGo ? 'bang' : 'cowboy', size: showGo ? 84 : 64),
              const SizedBox(height: 18),
              center,
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overOverlay(RoomView v) {
    final won = v.iWon == true;
    final iAsked = (_data?['rematch'] as Map?)?[widget.mySlot.key] == true;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: CD.parchment,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: won ? CD.sage : CD.danger, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Emo(won ? 'trophy' : 'skull', size: 64),
              const SizedBox(height: 8),
              Text(won ? '승리!' : '패배',
                  style: posterTitle(38, color: won ? CD.sage : CD.danger)),
              const SizedBox(height: 6),
              Text(v.banner,
                  style: const TextStyle(fontSize: 15, color: CD.muted)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: CD.rust,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: iAsked ? null : _rematch,
                  child: Text(iAsked ? '상대 기다리는 중...' : '다시 하기',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: CD.leather,
                      side: const BorderSide(color: CD.leather),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('나가기',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
