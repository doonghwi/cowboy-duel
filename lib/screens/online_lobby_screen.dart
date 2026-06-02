import 'package:flutter/material.dart';

import '../online/online_service.dart';
import '../theme.dart';
import '../widgets/desert_background.dart';
import '../widgets/emo.dart';
import 'online_game_screen.dart';

const _cream = Color(0xFFFFF4DD);

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _service = OnlineService();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = OnlineService.generateRoomCode();
      await _service.createRoom(code);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          service: _service,
          code: code,
          mySlot: Slot.host,
        ),
      ));
    } catch (e) {
      setState(() => _error = '방 생성 실패: 인터넷/Firebase 설정을 확인하세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 4) {
      setState(() => _error = '4자리 방 코드를 입력하세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await _service.joinRoom(code);
      if (!ok) {
        setState(() => _error = '방을 찾을 수 없어요. 코드를 확인하세요.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OnlineGameScreen(
          service: _service,
          code: code,
          mySlot: Slot.guest,
        ),
      ));
    } catch (e) {
      setState(() => _error = '참가 실패: 인터넷/Firebase 설정을 확인하세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('온라인 대전', style: posterTitle(22, color: _cream)),
        iconTheme: const IconThemeData(color: _cream),
      ),
      extendBodyBehindAppBar: true,
      body: DesertBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Emo('globe', size: 76),
                    const SizedBox(height: 12),
                    Text('친구와 한판!',
                        style: posterTitle(32, color: _cream)),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CD.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    _BigButton(
                      label: _busy ? '...' : '방 만들기',
                      icon: Icons.add_circle_outline,
                      color: CD.rust,
                      onTap: _busy ? null : _create,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CD.parchment,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD8C08A)),
                      ),
                      child: Column(
                        children: [
                          Text('방 코드로 참가',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: CD.leather)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codeCtrl,
                            textAlign: TextAlign.center,
                            maxLength: 4,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: CD.ink),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'ABCD',
                              // Faint placeholder so it's clearly not filled in.
                              hintStyle: TextStyle(
                                color: CD.muted.withValues(alpha: 0.32),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 8,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _BigButton(
                            label: _busy ? '...' : '참가하기',
                            icon: Icons.login,
                            color: CD.sage,
                            onTap: _busy ? null : _join,
                          ),
                        ],
                      ),
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

class _BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
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
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
