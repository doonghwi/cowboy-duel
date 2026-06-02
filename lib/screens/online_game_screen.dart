import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_logic.dart';
import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';

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
  Map? _data;
  RoomView? _view;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..repeat(reverse: true);
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
    final view = OnlineService.computeView(data, widget.mySlot);

    final rematch = data['rematch'] as Map?;
    if (widget.mySlot == Slot.host &&
        rematch != null &&
        rematch['host'] == true &&
        rematch['guest'] == true) {
      widget.service.resetForRematch(widget.code);
    }

    setState(() {
      _data = data;
      _view = view;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
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
    widget.service.tapStandoff(widget.code, v.turn, widget.mySlot);
  }

  void _rematch() {
    widget.service.requestRematch(widget.code, widget.mySlot);
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    return Scaffold(
      appBar: AppBar(
        title: Text('온라인 · 방 ${widget.code}', style: posterTitle(20)),
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
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: CD.rust, shape: BoxShape.circle),
              child: const Icon(Icons.person, color: Colors.white, size: 48),
            ),
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
              _fighter(Icons.person, '상대', v.oppAmmo, v.oppLastAction,
                  CD.leather),
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
              _fighter(Icons.person, '나', v.myAmmo, v.myLastAction, CD.rust),
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
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        child: Text('선택 완료! 상대를 기다리는 중...',
            style: TextStyle(color: CD.muted, fontWeight: FontWeight.w700)),
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
                  Icon(actionIcon(a), color: Colors.white, size: 28),
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

  Widget _fighter(
      IconData icon, String name, int ammo, CowboyAction? last, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8C08A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
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
                                  child: Icon(Icons.circle,
                                      size: 12, color: CD.gold),
                                )),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (last != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: CD.actionColor(last),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(actionIcon(last), color: Colors.white, size: 18),
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
    return Positioned.fill(
      child: GestureDetector(
        onTap: _tapStandoff,
        child: Container(
          color: CD.danger,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.white, size: 72),
              const SizedBox(height: 16),
              if (v.iTappedStandoff)
                const Text('탭 완료!\n상대 기다리는 중...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900))
              else
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.12).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: const Text('카우보이!\n지금 탭!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 50,
                          fontWeight: FontWeight.w900,
                          height: 1.1)),
                ),
              const SizedBox(height: 16),
              const Text('상대보다 빨리 탭하면 승리!',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
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
              Icon(won ? Icons.emoji_events : Icons.heart_broken,
                  color: won ? CD.gold : CD.danger, size: 64),
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
