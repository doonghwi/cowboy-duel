import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/emo.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('게임 방법', style: posterTitle(24))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _Intro(),
                  SizedBox(height: 18),
                  _RuleCard(
                    emoji: 'reload',
                    color: CD.gold,
                    title: '장전',
                    body: '총알을 한 발 장전해요. 장전을 해야만 공격(빵야)을 할 수 있어요.',
                  ),
                  _RuleCard(
                    emoji: 'shield',
                    color: CD.sage,
                    title: '방어',
                    body: '상대가 빵야 할 때 방어하면 맞지 않아요. 단, 방어 중엔 공격할 수 없어요.',
                  ),
                  _RuleCard(
                    emoji: 'bang',
                    color: CD.danger,
                    title: '빵야',
                    body: '장전된 총알로 공격해요! 상대가 방어하지 않았다면 명중 — 승리!',
                  ),
                  SizedBox(height: 18),
                  _StandoffCard(),
                  SizedBox(height: 18),
                  _Tips(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CD.leather,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '"장전 - 방어 - 빵야" 세 가지만 기억하면 돼요.\n매 턴 나와 상대가 동시에 하나를 선택합니다.',
        style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final String emoji;
  final Color color;
  final String title;
  final String body;
  const _RuleCard({
    required this.emoji,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C08A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Emo(emoji, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: color)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 14.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandoffCard extends StatelessWidget {
  const _StandoffCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CD.rust, CD.danger],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Emo('bang', size: 24),
              SizedBox(width: 8),
              Text('동시에 빵야!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '둘 다 동시에 빵야 했다면, 먼저 "카우보이!"를 외치는 사람이 이겨요.\n화면에 카우보이 버튼이 뜨면 누구보다 빠르게 탭하세요!',
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C08A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Emo('bulb', size: 20),
              const SizedBox(width: 6),
              Text('작전 팁',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: CD.leather,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ...const [
            '• 총알이 없으면 빵야 버튼은 잠겨요. 먼저 장전!',
            '• 상대가 장전하는 순간이 노릴 기회예요.',
            '• 상대가 쏠 것 같으면 방어로 받아치세요.',
            '• 장전만 반복하면 상대 빵야에 당해요.',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t, style: const TextStyle(height: 1.4)),
              )),
        ],
      ),
    );
  }
}
