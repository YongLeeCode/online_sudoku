import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 튜토리얼 완료 여부.
///
/// **저장 위치: 기기 로컬([SharedPreferences]).**
/// 현재 앱은 익명 플레이(게임 종료 시 `players` 행 삭제)라 영구 계정/프로필이
/// 아직 없다. "이 기기에서 튜토리얼을 봤는가"는 온보딩 성격의 기기 플래그이므로
/// 닉네임과 동일하게 SharedPreferences에 저장한다(서버 동기화 불필요).
/// Phase 5에서 프로필이 도입되면 이 값을 프로필로 미러링할 수 있다.
final tutorialCompletedProvider =
    StateNotifierProvider<TutorialCompletedNotifier, bool>((ref) {
      return TutorialCompletedNotifier();
    });

class TutorialCompletedNotifier extends StateNotifier<bool> {
  static const _key = 'tutorial_completed';

  TutorialCompletedNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  /// 튜토리얼을 끝까지 완료(또는 건너뛰기로 종료)했을 때 호출.
  Future<void> markCompleted() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// '다시 보기' 등에서 완료 상태를 초기화하고 싶을 때.
  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}
