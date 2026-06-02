import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'dailyapp_stats.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

/// Set to true once Firebase initialised, so the UI can show/hide online play.
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Auto-register in the DailyApp meta-dashboard + count this open (central
  // /dailyapp_stats via REST). Fire-and-forget, never blocks the app.
  DailyAppStats.recordOpen(
    appId: 'cowboy_duel',
    name: '🤠 카우보이 듀얼',
    desc: '장전·방어·빵야 + 카우보이 반응 대결',
    platforms: ['web', 'android', 'online'],
    webUrl: 'https://doonghwi.github.io/cowboy-duel/',
    repoUrl: 'https://github.com/doonghwi/cowboy-duel',
    day: 'Day 1',
  );
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    // Firebase is optional — the offline vs-CPU game works without it.
    firebaseReady = false;
  }
  runApp(const CowboyDuelApp());
}

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
