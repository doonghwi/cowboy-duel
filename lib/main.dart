import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const CowboyDuelApp());

class CowboyDuelApp extends StatelessWidget {
  const CowboyDuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '카우보이 듀얼',
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: const HomeScreen(),
    );
  }
}
