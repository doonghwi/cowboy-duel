import 'package:flutter/material.dart';

import '../game/cpu_ai.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';

const _cream = Color(0xFFFFF4DD);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Difficulty _difficulty = Difficulty.normal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DesertBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('— SHOWDOWN —',
                        style: westernLatin(16, color: _cream, spacing: 2)),
                    const SizedBox(height: 6),
                    Text(
                      '카우보이 듀얼',
                      textAlign: TextAlign.center,
                      style: posterTitle(52, color: _cream).copyWith(
                        shadows: const [
                          Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 3),
                              blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '장전 · 방어 · 빵야!',
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w800,
                        color: CD.gold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('🤠   🆚   🤖', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 38),

                    Text('난이도',
                        style: TextStyle(
                            color: _cream,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 4)
                            ])),
                    const SizedBox(height: 8),
                    _DifficultyPicker(
                      value: _difficulty,
                      onChanged: (d) => setState(() => _difficulty = d),
                    ),
                    const SizedBox(height: 28),

                    _BigButton(
                      label: 'CPU와 대결',
                      icon: '💥',
                      color: CD.rust,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => GameScreen(difficulty: _difficulty),
                        ));
                      },
                    ),
                    const SizedBox(height: 14),
                    _BigButton(
                      label: '게임 방법',
                      icon: '📖',
                      color: CD.leather,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const HowToPlayScreen(),
                        ));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  final Difficulty value;
  final ValueChanged<Difficulty> onChanged;
  const _DifficultyPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CD.parchment,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8C08A)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: Difficulty.values.map((d) {
          final selected = d == value;
          return GestureDetector(
            onTap: () => onChanged(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? CD.rust : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                d.ko,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : CD.muted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final VoidCallback onTap;
  const _BigButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        elevation: 6,
        shadowColor: Colors.black54,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
