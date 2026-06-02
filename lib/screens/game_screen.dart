import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../game/cpu_ai.dart';
import '../game/game_logic.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/emo.dart';

enum _Phase { choosing, reveal, standoff, roundOver }

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  const GameScreen({super.key, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final _rng = Random();

  int _playerAmmo = 0;
  int _cpuAmmo = 0;
  int _playerScore = 0;
  int _cpuScore = 0;

  _Phase _phase = _Phase.choosing;
  CowboyAction? _playerAction;
  CowboyAction? _cpuAction;
  String _banner = '준비됐나, 카우보이?';
  bool _playerWonDuel = false;

  String? _shakeWhich; // 'player' | 'cpu' | null
  late final AnimationController _shakeCtrl;
  late final AnimationController _pulseCtrl;

  bool _standoffGo = false;
  bool _standoffResolved = false;
  Timer? _cpuTimer;
  Timer? _prepTimer;
  final _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    _prepTimer?.cancel();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _choose(CowboyAction a) {
    if (_phase != _Phase.choosing) return;
    final cpu = chooseCpuAction(
      cpuAmmo: _cpuAmmo,
      playerAmmo: _playerAmmo,
      difficulty: widget.difficulty,
      rng: _rng,
    );
    setState(() {
      _playerAction = a;
      _cpuAction = cpu;
      _phase = _Phase.reveal;
      _banner = '';
    });
    _prepTimer = Timer(const Duration(milliseconds: 850), _resolve);
  }

  void _resolve() {
    final r = resolveTurn(_playerAction!, _playerAmmo, _cpuAction!, _cpuAmmo);
    setState(() {
      _playerAmmo = r.ammo1After;
      _cpuAmmo = r.ammo2After;
    });
    switch (r.outcome) {
      case DuelOutcome.standoff:
        setState(() {
          _phase = _Phase.standoff;
          _standoffGo = false;
          _standoffResolved = false;
        });
        _startStandoff();
        break;
      case DuelOutcome.p1Hit:
        _concludeDuel(playerWon: true, banner: '명중!', shakeCpu: true);
        break;
      case DuelOutcome.p2Hit:
        _concludeDuel(playerWon: false, banner: '당했다...', shakeCpu: false);
        break;
      case DuelOutcome.ongoing:
        setState(() {
          _phase = _Phase.choosing;
          _banner = _ongoingBanner(r);
        });
        break;
    }
  }

  void _concludeDuel({
    required bool playerWon,
    required String banner,
    required bool shakeCpu,
  }) {
    setState(() {
      _banner = banner;
      _shakeWhich = shakeCpu ? 'cpu' : 'player';
    });
    _shakeCtrl.forward(from: 0);
    _prepTimer = Timer(const Duration(milliseconds: 820), () {
      if (!mounted) return;
      setState(() {
        if (playerWon) {
          _playerScore++;
        } else {
          _cpuScore++;
        }
        _playerWonDuel = playerWon;
        _shakeWhich = null;
        _phase = _Phase.roundOver;
      });
    });
  }

  String _ongoingBanner(TurnResult r) {
    final pDefend = _playerAction == CowboyAction.defend;
    final cDefend = _cpuAction == CowboyAction.defend;
    final p = _playerAction;
    final c = _cpuAction;
    if (r.p1Fired && cDefend) return '컴퓨터가 방어로 막았다!';
    if (r.p2Fired && pDefend) return '방어 성공! 막아냈다';
    if (p == CowboyAction.reload && c == CowboyAction.reload) {
      return '둘 다 장전!';
    }
    if (p == CowboyAction.defend && c == CowboyAction.defend) {
      return '둘 다 방어! 허탕';
    }
    if (p == CowboyAction.reload && c == CowboyAction.defend) {
      return '나는 장전, 컴퓨터는 방어';
    }
    if (p == CowboyAction.defend && c == CowboyAction.reload) {
      return '나는 방어, 컴퓨터는 장전';
    }
    return '계속!';
  }

  void _startStandoff() {
    _standoffGo = false;
    _standoffResolved = false;
    final prep = 500 + _rng.nextInt(900);
    _prepTimer = Timer(Duration(milliseconds: prep), () {
      if (!mounted) return;
      setState(() => _standoffGo = true);
      _sw
        ..reset()
        ..start();
      _cpuTimer =
          Timer(Duration(milliseconds: widget.difficulty.reactionMs), () {
        if (!_standoffResolved) {
          _finishStandoff(playerWon: false, msg: 'CPU가 더 빨랐다!');
        }
      });
    });
  }

  void _onStandoffTap() {
    if (_phase != _Phase.standoff || _standoffResolved) return;
    if (!_standoffGo) {
      _finishStandoff(playerWon: false, msg: '너무 빨랐다! (부정출발)');
      return;
    }
    _sw.stop();
    _finishStandoff(playerWon: true, msg: '카우보이! ${_sw.elapsedMilliseconds}ms');
  }

  void _finishStandoff({required bool playerWon, required String msg}) {
    _standoffResolved = true;
    _cpuTimer?.cancel();
    _prepTimer?.cancel();
    setState(() {
      if (playerWon) {
        _playerScore++;
        _playerWonDuel = true;
      } else {
        _cpuScore++;
        _playerWonDuel = false;
      }
      _phase = _Phase.roundOver;
      _banner = msg;
    });
  }

  void _playAgain() {
    setState(() {
      _playerAmmo = 0;
      _cpuAmmo = 0;
      _playerAction = null;
      _cpuAction = null;
      _phase = _Phase.choosing;
      _banner = '준비됐나, 카우보이?';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesertBackground(
        bright: true,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  Expanded(child: _arena()),
                ],
              ),
              if (_phase == _Phase.standoff) _standoffOverlay(),
              if (_phase == _Phase.roundOver) _roundOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: CD.leather),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text('카우보이 듀얼',
                textAlign: TextAlign.center, style: posterTitle(22)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CD.leather,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('나 $_playerScore : $_cpuScore 컴퓨터',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _arena() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _shakeable(
            'cpu',
            _fighter(
              emoji: 'robot',
              name: '컴퓨터 (${widget.difficulty.ko})',
              ammo: _cpuAmmo,
              action: _phase == _Phase.reveal ? _cpuAction : null,
              color: CD.leather,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _banner,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: CD.rust,
                  shadows: [Shadow(color: Colors.white70, blurRadius: 6)],
                ),
              ),
            ),
          ),
          _shakeable(
            'player',
            _fighter(
              emoji: 'cowboy',
              name: '나',
              ammo: _playerAmmo,
              action: _phase == _Phase.reveal ? _playerAction : null,
              color: CD.rust,
            ),
          ),
          const SizedBox(height: 16),
          _actionBar(),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _shakeable(String who, Widget child) {
    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, c) {
        final active = _shakeWhich == who && _shakeCtrl.isAnimating;
        final t = _shakeCtrl.value;
        final dx = active ? sin(t * pi * 6) * 10 * (1 - t) : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  Widget _fighter({
    required String emoji,
    required String name,
    required int ammo,
    required CowboyAction? action,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8C08A)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Emo(emoji, size: 48),
          const SizedBox(width: 14),
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
                _ammoRow(ammo),
              ],
            ),
          ),
          if (action != null) _actionChip(action),
        ],
      ),
    );
  }

  Widget _actionChip(CowboyAction action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CD.actionColor(action),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Emo(actionEmoji(action), size: 20),
          const SizedBox(width: 6),
          Text(action.ko,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _ammoRow(int ammo) {
    return Row(
      children: [
        const Icon(Icons.bolt, size: 16, color: CD.muted),
        const SizedBox(width: 4),
        if (ammo == 0)
          Text('빈 총',
              style: TextStyle(color: CD.muted, fontWeight: FontWeight.w600))
        else
          Row(
            children: List.generate(
              ammo,
              (_) => const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Emo('ammo', size: 15),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionBar() {
    final canShoot = _playerAmmo > 0;
    final enabled = _phase == _Phase.choosing;
    return Row(
      children: [
        _actionButton(CowboyAction.reload, enabled),
        const SizedBox(width: 10),
        _actionButton(CowboyAction.defend, enabled),
        const SizedBox(width: 10),
        _actionButton(CowboyAction.shoot, enabled && canShoot),
      ],
    );
  }

  Widget _actionButton(CowboyAction a, bool enabled) {
    final color = CD.actionColor(a);
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(16),
          elevation: enabled ? 4 : 0,
          shadowColor: Colors.black54,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => _choose(a) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Column(
                children: [
                  Emo(actionEmoji(a), size: 30),
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

  Widget _standoffOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _onStandoffTap,
        child: Container(
          color: _standoffGo ? CD.danger : CD.leather,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _standoffGo
                  ? const Emo('bang', size: 84)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Emo('cowboy', size: 48),
                        SizedBox(width: 12),
                        Emo('robot', size: 48),
                      ],
                    ),
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _standoffGo
                    ? Tween(begin: 0.92, end: 1.12).animate(CurvedAnimation(
                        parent: _pulseCtrl, curve: Curves.easeInOut))
                    : const AlwaysStoppedAnimation(1.0),
                child: Text(
                  _standoffGo ? '카우보이!\n지금 탭!' : '준비...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _standoffGo ? 52 : 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _standoffGo ? '먼저 외치는 사람이 승리!' : '"카우보이!" 가 뜨면 즉시 탭하세요',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundOverOverlay() {
    final won = _playerWonDuel;
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
              const SizedBox(height: 10),
              Text(
                won ? '승리!' : '패배',
                style: posterTitle(40, color: won ? CD.sage : CD.danger),
              ),
              const SizedBox(height: 8),
              Text(_banner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: CD.muted)),
              const SizedBox(height: 6),
              Text('나 $_playerScore : $_cpuScore 컴퓨터',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CD.rust,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _playAgain,
                  child: const Text('다시 하기',
                      style: TextStyle(
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('홈으로',
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
