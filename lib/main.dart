import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

/// Set to true once Firebase initialised, so the UI can show/hide online play.
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    // On mobile, persist queued writes so an open that happened offline still
    // syncs to the usage counter once the device is back online.
    if (!kIsWeb) {
      try {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
      } catch (_) {}
    }
    _recordOpen();
  } catch (_) {
    // Firebase is optional — the offline vs-CPU game works without it.
    firebaseReady = false;
  }
  runApp(const CowboyDuelApp());
}

/// Anonymously bump an app-open counter so the DailyApp dashboard can show
/// real usage. Fire-and-forget; never blocks or breaks the app.
void _recordOpen() {
  try {
    final ref = FirebaseDatabase.instance.ref('stats/cowboy_duel');
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    ref.child('opens').runTransaction((cur) {
      final n = cur is int ? cur : 0;
      return Transaction.success(n + 1);
    });
    ref.child('opens_$platform').runTransaction((cur) {
      final n = cur is int ? cur : 0;
      return Transaction.success(n + 1);
    });
    ref.update({
      'name': '카우보이 듀얼',
      'lastOpen': ServerValue.timestamp,
    });
  } catch (_) {
    // ignore analytics failures
  }
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
