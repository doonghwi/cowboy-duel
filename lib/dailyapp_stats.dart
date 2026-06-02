// DailyApp 공용 사용량 트래커 (드롭인).
//
// 모든 daily 앱이 시작 시 한 번 호출하면:
//   1) 메타 대시보드(중앙 RTDB /dailyapp_stats)에 앱이 자동 등록되고
//   2) 앱 열린 횟수(opens)가 자동 +1 (플랫폼별도 집계)
// Firebase SDK 불필요 — RTDB REST + 서버 increment(.sv)만 사용하므로
// 온라인/오프라인 앱 모두 가능(오프라인 앱은 네트워크 있을 때 best-effort 집계).
//
// 사용법:
//   1) pubspec.yaml deps에  http: ^1.2.0  추가
//   2) lib/ 아래로 이 파일 복사
//   3) main() 에서 (await 불필요, fire-and-forget):
//        WidgetsFlutterBinding.ensureInitialized();
//        DailyAppStats.recordOpen(
//          appId: 'cowboy_party',
//          name: '🤠 카우보이 파티',
//          desc: '2~6인 온라인 카우보이 파티',
//          platforms: ['web','android','online'],
//          webUrl: 'https://doonghwi.github.io/cowboy-party/',
//          repoUrl: 'https://github.com/doonghwi/cowboy-party',
//        );
//
// 중앙 DB는 cowboy-duel-doonghwi RTDB(테스트모드, 공개)를 공용으로 재사용.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DailyAppStats {
  static const _base =
      'https://cowboy-duel-doonghwi-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// 앱 시작 시 1회 호출. 실패해도 앱엔 영향 없음(best-effort).
  static Future<void> recordOpen({
    required String appId,
    required String name,
    String desc = '',
    List<String> platforms = const ['web', 'android'],
    String? webUrl,
    String? repoUrl,
    String day = '',
  }) async {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name; // android/ios/...
    try {
      await http.patch(
        Uri.parse('$_base/dailyapp_stats/$appId.json'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'opens': {'.sv': {'increment': 1}},
          'opens_$platform': {'.sv': {'increment': 1}},
          'name': name,
          if (desc.isNotEmpty) 'desc': desc,
          'platforms': platforms,
          if (webUrl != null) 'webUrl': webUrl,
          if (repoUrl != null) 'repoUrl': repoUrl,
          if (day.isNotEmpty) 'day': day,
          'lastOpen': {'.sv': 'timestamp'},
        }),
      );
    } catch (_) {
      // 사용량 집계 실패는 무시 (오프라인 등)
    }
  }
}
